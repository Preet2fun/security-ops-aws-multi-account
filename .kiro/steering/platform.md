---
inclusion: fileMatch
fileMatchPattern: 'saas-security/**|.kiro/specs/**'
---

# Platform Context — AI-Native Observability & Security SaaS

## Purpose
This document is the **authoritative platform reference** for all SaaS security work. Any security architecture (HLD/LLD), implementation, Kiro spec, or service configuration under `saas-security/` or `.kiro/specs/` **MUST** reference and align with this document. It captures the business context, tenant model, account structure, and the actual AWS services used to build the platform.

> This complements `saas-security-implementation.md` (methodology & defense-in-depth) by providing the concrete platform facts those designs must fit.

---

## 1. Business Context

- **Product:** An **AI-native observability & security** SaaS platform (ITOM/ITSM lineage) — ingests telemetry, detects anomalies, and drives security/ops use cases with AI agents and self-hosted models.
- **Scale target:** **1,000 tenants** live, each with **multiple users**. Expect **heavy, bursty load** at full tenancy (telemetry ingestion, query, AI inference).
- **Primary workloads:** high-volume telemetry ingestion, real-time + historical analytics, AI/ML inference (agentic + self-hosted models), multi-tenant dashboards and APIs.
- **Security posture:** multi-tenant isolation, least privilege, encryption everywhere, full auditability, compliance-aligned (SOC 2 / ISO 27001 / GDPR).

---

## 2. Tenant Model

### Tenancy
- **1,000 tenants**, each with multiple users.
- **Isolation tier: Pooled** (option C). Shared services and shared compute; tenant isolation enforced in **application logic + data layer** via a `tenant_id` scoping on every request and every row/schema.
- Tenant context is derived from the authenticated identity (JWT claim `tenant_id`) and propagated through every layer (edge → API → service → data).

### Pooled isolation — enforcement rules (mandatory in every design)
- **Identity:** `tenant_id` is a signed claim in the access/ID token (injected at auth time) — never trusted from a client-supplied header.
- **API layer:** API Gateway / ALB authorizer validates the token and forwards `tenant_id` as a trusted context; backend never derives tenant from user input.
- **Compute (EKS):** shared pods; every request carries tenant context; services must scope all data access by `tenant_id`.
- **Data:** tenant scoping enforced at query time (schema or row-level) — see Data Layer. Cross-tenant access is a critical defect.
- **Noisy-neighbor controls:** per-tenant API throttling (API Gateway usage plans), per-tenant quotas, and fair-sharing on ingestion/inference.
- **Observability:** all logs/metrics/traces are tagged with `tenant_id` for per-tenant monitoring, billing, and incident scoping.

---

## 3. Identity & Federation

### Model (option A — recommended best practice)
**Single Amazon Cognito User Pool**, with **per-tenant app clients** and **per-tenant external IdP federation** for enterprise SSO.

- **~600 tenants** use **Cognito as their IdP** (native Cognito users).
- **~400 tenants** bring **enterprise SSO** — federated via **SAML 2.0** or **OIDC/OAuth2** (Okta, Google, Azure AD, Ping, etc.).
- Platform **must support both OAuth2/OIDC and SAML** federation, plus **SCIM** provisioning for enterprise tenants.

### Recommended best practices for "single User Pool + per-tenant app client + external IdP"

1. **Tenant → app client mapping**
   - One **app client per tenant** gives per-tenant OAuth settings (callback URLs, allowed IdPs, scopes, token TTLs) and clean per-tenant revocation.
   - ⚠️ **Quota decision (RESOLVED):** default is **~1,000 app clients per User Pool** and **~1,000 identity providers per User Pool** (adjustable). **Decision: single User Pool with quotas raised early** via Service Quotas / AWS Support — request increases well before approaching 1,000 tenants, with headroom for growth. No multi-pool sharding. The identity spec must include the quota-increase requests (app clients, identity providers, and related per-pool limits) as an explicit pre-req task.

2. **Tenant resolution**
   - Resolve tenant at the start of the auth flow via a **tenant hint** — subdomain (`{tenant}.app.example.com`), a path prefix, or a `tenant` query/state param to the Hosted UI/`/authorize`.
   - Map the hint → tenant's app client + allowed IdP(s). Never let a user pick an arbitrary IdP outside their tenant.

3. **External IdP federation**
   - Register each enterprise tenant's IdP as a **SAML** or **OIDC** identity provider in the User Pool; restrict the tenant's app client to **only** its own IdP(s) (+ Cognito native if allowed).
   - Map IdP attributes/claims → Cognito attributes, including `custom:tenant_id` and `custom:tenant_role`.

4. **Token customization (critical for pooled isolation)**
   - Use a **Pre Token Generation Lambda (V2)** to inject `tenant_id`, `tenant_role`, and tenant-scoped **custom scopes** into ID and access tokens.
   - Keep tokens short-lived (access/ID ~1h); enable **refresh token rotation** and **token revocation**.

5. **SCIM provisioning (RESOLVED — best-practice pattern)**
   - **Authoritative lifecycle stays in the tenant's enterprise IdP (Okta/Azure AD/etc.); Cognito is NOT the SCIM target.** Cognito User Pools are not a native SCIM 2.0 endpoint, so do not try to make Cognito the provisioning target.
   - **User creation in Cognito = Just-in-Time (JIT) federation** on first SAML/OIDC login (Cognito auto-creates the federated user from the assertion).
   - **Deprovisioning/lifecycle = handled at the IdP via SCIM** (the tenant's IdP is the system of record). When the IdP disables/removes a user, federated login stops; back this with short token TTLs + refresh-token revocation so access ends promptly.
   - For tenants that require **immediate forced sign-out on deprovisioning**, trigger `AdminUserGlobalSignOut` / disable the federated user in Cognito via an IdP event webhook or a scheduled reconciliation job. The identity spec should define this deprovisioning flow.
   - Only build a custom SCIM endpoint/bridge into a Cognito-managed directory if a specific tenant contractually requires SCIM-into-the-platform — treat as an exception, not the default.

6. **Protection & detection**
   - **Cognito Advanced Security (threat protection) in ENFORCED mode** — compromised-credential detection + adaptive auth.
   - **MFA required** (TOTP primary; SMS backup only).
   - **WAF** on the Cognito/Hosted UI domain + rate limiting on `/oauth2/token`.
   - `prevent-user-existence-errors` enabled on every app client.

7. **Custom domain** — branded `auth.{domain}` (ACM cert in us-east-1) for the Hosted UI to reduce phishing risk.

> Full technical depth for Cognito lives in `exam-study/cognito.md` (or `.html`). Design specs should reuse those patterns.

---

## 4. Account Structure

The platform uses a **4-account AWS Organizations model**. **All workloads — both Control Plane and App Plane — run in the single Workload account.** The two planes are a logical/architectural separation within that account (separate VPCs, roles, and resource boundaries), not an account boundary.

| Account | Role |
|---------|------|
| **Management** | AWS Organizations root, billing, governance, SCPs |
| **Audit** | Security auditing, compliance, forensics, Security Hub aggregation, GuardDuty delegated admin |
| **Logging** | Centralized logs (CloudTrail org trail, Config, VPC Flow Logs), SIEM |
| **Workload** | **Both Control Plane (serverless) and App Plane (EKS) run here**, plus all tenant data and AI workloads |

### Plane separation within the Workload account
- **Control Plane** and **App Plane** are isolated **within** the Workload account via separate VPCs, security groups, IAM roles, and least-privilege boundaries — not separate accounts.
- Blast-radius control relies on **IAM least privilege, network segmentation, and SCP guardrails** at the Workload-account level rather than account separation between planes.
- Cross-plane access (Control Plane provisioning App Plane resources) uses scoped IAM roles with explicit trust, not broad admin.

---

## 5. Architecture — Two Planes

Both planes run **in the single Workload account**, separated logically (VPCs, IAM roles, network segmentation).

### 5.1 Control Plane (Serverless)
Fully **serverless**; app front-end delivered via **CloudFront + WAF + API Gateway**.

```
Users → Route 53 → CloudFront (+ WAF) → API Gateway → Lambda → DynamoDB
                                              ↓
                              Cognito (identity) · EventBridge · Step Functions
```

- **Edge/API:** Route 53, CloudFront, AWS WAF, API Gateway
- **Compute:** AWS Lambda
- **State/data:** DynamoDB (tenant registry, config, onboarding state)
- **Identity:** Amazon Cognito (single User Pool, per-tenant app clients + federation)
- **Orchestration/eventing:** EventBridge, Step Functions
- **Responsibilities:** tenant onboarding/offboarding, tenant metadata & entitlements, identity/app-client provisioning, billing/usage metering, platform governance.

### 5.2 App Plane (Containerized on EKS)
Tenant-serving workloads run **containerized on Amazon EKS** (pooled, multi-tenant), with GPU node groups for self-hosted AI models. Runs in the **Workload account** (same account as Control Plane, isolated by VPC/IAM).

```
Users → Route 53 → CloudFront (+ WAF) → API Gateway → ALB/NLB → EKS (pods)
                                                            ↓
                 KMS · Secrets Manager · Parameter Store · RDS (Multi-AZ) · S3 data lake · AI (Bedrock AgentCore + self-hosted on GPU)
```

- **Edge/API:** Route 53, CloudFront, AWS WAF, API Gateway
- **Load balancing:** ALB (L7) + NLB (L4)
- **Compute:** Amazon EKS (pooled multi-tenant; **GPU node groups** for self-hosted models)
- **Secrets/config:** AWS KMS, AWS Secrets Manager, SSM Parameter Store
- **Data:** see Data Layer
- **AI/ML:** see AI/ML Stack (Bedrock AgentCore + self-hosted on EKS GPU)

---

## 6. Data Layer

| Store | Purpose | Isolation |
|-------|---------|-----------|
| **Amazon RDS (Multi-AZ)** | Transactional / relational data (tenant metadata, entities, relational app data) | Tenant scoping via schema or row-level security on `tenant_id` |
| **Data lake (S3 as storage, EKS as compute)** | High-volume telemetry / observability data at scale; analytics & AI feature data | Tenant partitioning in the S3 key/prefix layout + query-time scoping |
| **S3** | Data-lake storage layer, plus platform object storage (artifacts, exports) | Bucket/prefix partitioning + policies; SSE-KMS |

- **Data-lake compute is EKS-only (RESOLVED):** all processing/analytics/query jobs over the S3 data lake run as **containerized workloads on EKS**. **No managed query engines** (no Athena, Glue, OpenSearch, or Redshift) are part of the platform by default. Do not introduce them in designs without explicitly flagging a scope change.
- **Encryption:** all data at rest with **KMS CMKs**; TLS in transit everywhere.
- **Tenant data separation** is a **critical control** — every query path must enforce `tenant_id` (RDS: schema/row-level scoping; S3 lake: prefix partitioning + query-time scoping in EKS jobs).

---

## 7. AI/ML Stack

Two complementary AI approaches (RESOLVED):

- **Amazon Bedrock AgentCore** — used for the **agentic** portion of the AI workloads (agent orchestration, reasoning, tool/action invocation). This is the managed agent runtime for agentic use cases.
- **Self-hosted models on EKS (GPU node groups)** — for the remaining AI workloads where models run in-cluster on GPU nodes (custom/open models, inference the platform controls directly).

Security considerations to address in any AI spec:
- **Bedrock AgentCore:** IAM scoping of agent actions/tools, **Bedrock Guardrails** for input/output filtering, prompt-injection defenses, per-tenant isolation of agent sessions and memory, data-residency and logging of agent invocations, least-privilege on the agent's action/tool permissions.
- **Self-hosted on EKS GPU:** tenant isolation of inference (no cross-tenant prompt/data bleed), model/endpoint access control + per-tenant rate limits, secrets for model/registry access via Secrets Manager, GPU node group hardening, image provenance (ECR scanning + signing), KMS encryption of model artifacts and feature data.
- **Cross-cutting:** every inference path carries and enforces `tenant_id`; agent and model actions are audited; guardrails applied before any tenant-facing output.

---

## 8. Core AWS Service Inventory

| Category | Services |
|----------|----------|
| Edge / CDN / DNS | Route 53, CloudFront, AWS WAF (both planes) |
| API | API Gateway (both planes) |
| Load balancing (App Plane) | ALB, NLB |
| Compute | Lambda (Control Plane), Amazon EKS incl. GPU node groups (App Plane) — both in the Workload account |
| Identity | Amazon Cognito (single User Pool, per-tenant app clients, SAML/OIDC federation, JIT provisioning; SCIM at tenant IdP) |
| Data | DynamoDB (Control Plane), RDS Multi-AZ, S3 data lake with **EKS-only** compute (no Athena/Glue/OpenSearch/Redshift) |
| Secrets / Config | AWS KMS, AWS Secrets Manager, SSM Parameter Store |
| Eventing / Orchestration | EventBridge, Step Functions |
| AI/ML | **Amazon Bedrock AgentCore** (agentic) + self-hosted models on EKS GPU nodes |
| Security / Governance (org-wide) | GuardDuty, Security Hub, Config, CloudTrail, Inspector, Macie, Organizations, Control Tower (per multi-account foundation) |

---

## 9. Non-Functional Requirements (drive security design)

- **Scale:** 1,000 tenants, multi-user each; heavy/bursty ingestion + inference load.
- **Multi-tenancy:** pooled isolation — correctness of `tenant_id` scoping is a top-priority security property.
- **Availability:** Multi-AZ (RDS Multi-AZ); design for regional resilience in the App Plane.
- **Performance under load:** per-tenant throttling and fair-sharing to prevent noisy-neighbor; autoscaling on EKS (incl. GPU).
- **Compliance:** SOC 2, ISO 27001, GDPR alignment; full audit trail (CloudTrail org trail → Logging account).
- **Least privilege:** scoped IAM roles per service/plane; no wildcard production ARNs.

---

## 10. How to Use This Doc

When producing any SaaS security spec, HLD/LLD, implementation guide, or service configuration:

1. **Place the service correctly** — all workloads live in the **single Workload account**; state which **plane** (Control Plane serverless vs App Plane EKS) and which VPC/boundary the control lives in. Org-wide security services live in Audit/Logging/Management per the multi-account foundation.
2. **Enforce pooled tenant isolation** — show how `tenant_id` is derived (Cognito claim) and enforced at edge/API/compute/data.
3. **Respect the identity model** — single Cognito User Pool, per-tenant app client, SAML+OIDC federation, SCIM; apply the Cognito best practices in §3.
4. **Use the real services** — reference the §8 inventory; don't invent services not in the platform without flagging it.
5. **Design for 1,000-tenant scale** — call out quotas (esp. Cognito app clients/IdPs), throttling, and noisy-neighbor controls.
6. **Align with defense-in-depth** — map each control to preventive/detective/responsive/recovery (per `saas-security-implementation.md`).
7. **Flag assumptions** — anything marked *(Assumption)* here must be confirmed in the spec's requirements before build.

---

## 11. Resolved Decisions (locked)

All earlier open items are now decided:

| # | Decision |
|---|----------|
| Account model | **4 accounts**: Management, Audit, Logging, Workload. **All workloads (Control Plane + App Plane) run in the single Workload account**; planes separated logically (VPC/IAM/network), not by account. |
| Cognito scaling | **Single User Pool, quotas raised early** (app clients + identity providers) via Service Quotas/Support. No multi-pool sharding. |
| SCIM provisioning | **Authoritative lifecycle at tenant's enterprise IdP; Cognito is not the SCIM target.** JIT federation creates Cognito users on first login; deprovisioning driven by the IdP + short token TTLs/revocation (+ optional forced global sign-out). |
| Data-lake compute | **EKS-only.** No Athena / Glue / OpenSearch / Redshift. |
| Agentic AI | **Amazon Bedrock AgentCore** for agentic workloads; self-hosted models on EKS GPU nodes for the rest. |

## 12. Design & IaC Standards (locked — apply to every spec/implementation)

| # | Standard |
|---|----------|
| **IaC** | **CloudFormation ONLY** — platform is AWS-native, no Terraform. Each `saas-security/{service}/` has `template.yaml`; no `.tf` files. |
| **HLD/LLD artifact** | Each service produces a dedicated self-contained **`{service}-security-design.html`** (HLD + LLD + all diagrams embedded inline + security-config significance). The spec `design.md` stays lightweight and points to it; producing the HTML is an explicit task in `tasks.md`. |
| **1,000-tenant justification** | Every design MUST justify reliability at **1,000-tenant scale** — defense-in-depth, data isolation, data security — with a mandatory **security hole/gap analysis** covering every operational, performance, scalability, availability, and security failure mode and its mitigation. No gap left unaddressed. |
| **Latest GUI** | Step-by-step console guides must reflect the **current AWS Console navigation/flow** (verify via crawl4ai/MCP), never stale UI. |
| **Tenant isolation proof** | Pooled isolation — every design proves `tenant_id` enforcement edge→API→compute→data; cross-tenant access is a critical defect; validation includes a tenant-isolation test. |

> These standards are enforced by the `@security-architect` agent and detailed in `saas-security-implementation.md`.

---

**This document drives all SaaS security platform design. Every `saas-security/` implementation and `.kiro/specs/` design MUST reference and conform to it.**
