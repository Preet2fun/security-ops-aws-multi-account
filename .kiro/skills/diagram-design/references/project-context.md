# Project Context — Diagramming the Control Plane

This file adapts the vendored `diagram-design` engine to the Control Plane serverless platform.
It answers three questions: what to draw with, how to color AWS components, and which brand tokens
to use. For layout grammar and rules, always defer to the vendored `type-*.md` and `vendor/SKILL.md`.

---

## 1. Stack → visual type mapping

| CP concern | Visual type | Vendor spec |
|------------|-------------|-------------|
| Deployed infrastructure overview | Architecture | `vendor/references/type-architecture.md` |
| End-to-end data stack / hero infra | High-Level | `vendor/references/type-high-level.md` |
| Passwordless OTP auth, token exchange, provisioning saga | Sequence | `vendor/references/type-sequence.md` |
| Request path or EventBridge fan-out | Data flow | `vendor/references/type-data-flow.md` |
| VPC topology, subnets, endpoints, multi-account | Deployment | `vendor/references/type-deployment.md` |
| Tenant lifecycle / OTP record states | State machine | `vendor/references/type-state.md` |
| DynamoDB entity model | ER / data model | `vendor/references/type-er.md` |
| DynamoDB physical tables (keys, GSIs, types) | Database schema | `vendor/references/type-db-schema.md` |
| Cross-stack deployment order | Dependency graph | `vendor/references/type-dependency.md` |
| Decision logic (authorizer allow/deny, validation) | Flowchart | `vendor/references/type-flowchart.md` |
| Cross-service process with handoffs | Swimlane / Process | `vendor/references/type-swimlane.md`, `type-process.md` |

If a three-column table says the same thing, use the table instead.

---

## 2. AWS component color conventions

The design system is skinnable and semantic (roles, not raw colors). Map CP components onto the
vendored node-type treatments (see `vendor/SKILL.md` §5 "Node type → treatment"):

| CP component | Node treatment | Rationale |
|--------------|----------------|-----------|
| API Gateway (REST) | Backend/API — white fill, `ink` stroke | Entry point, on the primary path |
| Lambda handler (the focal one) | Focal — `accent-tint` fill, `accent` stroke | 1–2 per diagram max |
| Other Lambda handlers | Backend/API — white fill, `ink` stroke | |
| DynamoDB table | Store/State — `ink @ 0.05` fill, `muted` stroke | Persistent state |
| Cognito user pool | External/Cloud — `ink @ 0.03` fill | Managed service |
| SES | External/Cloud — `ink @ 0.03` fill | Managed service |
| EventBridge bus | Store/State or Backend depending on role | |
| Async edge (SES send, EventBridge publish) | Dashed `4,3`, `link`-blue or `muted` | Async/optional semantics |
| HTTP/API call arrow | `link`-blue (`#2e5aa8` default) | External/API calls |
| VPC / security-group / trust boundary | Dashed boundary rect, `accent @ 0.50` dashed `4,4` | Security zone |

**Accent (coral) is editorial** — reserve it for the 1–2 most important nodes (the focal integration
point or key data store), never as a "this is important too" flag.

Use official AWS service names in labels: Amazon DynamoDB, AWS Lambda, Amazon Cognito, Amazon SES,
Amazon API Gateway, Amazon EventBridge, Amazon CloudFront, Amazon S3.

---

## 3. Brand / style guide

On the first diagram in this repo, the Step-0 gate (see `SKILL.md` §2) decides the brand. Options:

- **Default skin** — the shipped editorial palette (white-smoke paper, jet-ink, atomic-tangerine
  accent). Fine for internal architecture reviews and spec diagrams.
- **Brand it** — pull tokens from the product marketing site, paste hex tokens, or load a saved
  profile. Follow `vendor/references/onboarding.md` and `vendor/references/profiles.md`.

To brand permanently for the repo, either customize
`vendor/references/style-guide.md` in place is **discouraged** (it's vendored and would drift from
upstream); instead save a named profile under `~/.diagram-design/profiles/` and drop a
`.diagram-design` marker at the repo root pointing to it. That keeps the vendor mirror pristine.

If the team later settles on official brand tokens, record them here so every contributor's
diagrams match:

```
# CP brand tokens (fill in when decided)
paper:   <hex>
ink:     <hex>
accent:  <hex>
link:    <hex>
muted:   <hex>
title font:  <family>
body font:   <family>
mono font:   <family>
```

---

## 4. Domain guardrails when drawing CP diagrams

These come from the repo's steering docs — respect them so diagrams don't teach the wrong thing:

- **Passwordless only.** Auth is Cognito CUSTOM_AUTH with OTP via Lambda triggers. Never draw
  password fields, `USER_PASSWORD_AUTH`, or `USER_SRP_AUTH`. Auth sequence actors are the three
  triggers (DefineAuthChallenge, CreateAuthChallenge, VerifyAuthChallengeResponse) + SES + DynamoDB
  `OTPStore`.
- **Lambda in private subnets.** Any VPC/deployment diagram puts Lambda ENIs in a **private** subnet
  (NAT route), and the NAT Gateway in a **public** subnet (IGW route). Gateway endpoints (DynamoDB, S3)
  and interface endpoints (Cognito, STS, SSM, Logs, EventBridge, SES) belong in the private tier.
- **Multi-account topology.** dev = single account. staging/prod = 4-account AWS Organization
  (management / security-audit / log-archive / workload); CP stacks live in the **workload** account.
  Draw accounts as nested/zone containers when the diagram is about the account model.
- **Observability split.** Logs → CloudWatch (Powertools). Traces → Jaeger via ADOT. Business KPI
  metrics → Prometheus + CloudWatch via ADOT. If drawing the telemetry pipeline, keep these three
  lanes distinct.
- **No secrets rendered.** OTP codes, tokens, and full email addresses never appear as literal values.

---

## 5. Where diagrams live

| Diagram purpose | Save location |
|-----------------|---------------|
| Ad-hoc / review / general | `platform-reports/architecture/diagrams/` |
| Belongs to a spec | next to that spec's `design.md` in `.kiro/specs/<spec>/` |
| Frontend integration artifact | `docs/frontend-integration/<JOURNEY>_<slug>/` |

Export to PNG/SVG only when asked (`vendor/references/export.md`).
