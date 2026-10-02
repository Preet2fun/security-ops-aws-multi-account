# SaaS Security Platform — Defense-in-Depth Implementation Guide

## Purpose
This steering document drives **Objective 2: SaaS Platform Security Implementation** — building a comprehensive, production-grade security architecture for a multi-tenant ITOM/ITSM SaaS platform on AWS using spec-driven development with both manual and automated (IaC) configuration approaches.

> **MUST READ FIRST: [`platform.md`](./platform.md)** — the authoritative platform reference (business context, tenant model, Control Plane vs App Plane account structure, identity/federation model, actual AWS service inventory, scale targets). Every spec, HLD/LLD, implementation guide, and service configuration MUST align with `platform.md`. It is conditionally included whenever you work under `saas-security/` or `.kiro/specs/`.

## Platform Architecture

### Account Structure
| Account | Role |
|---------|------|
| Management Account | AWS Organizations root, billing, governance |
| Audit Account | Security auditing, compliance monitoring, forensics |
| Logging Account | Centralized logging, monitoring, SIEM |
| Workload Account | Multi-region application workloads and data |

### Application Stack
```
Internet → Route 53 → CloudFront → API Gateway → NLB → EKS Clusters → RDS
                                       ↓
                           Security Services Layer
                      (WAF, Shield, GuardDuty, Config, etc.)
```

### Core Services
- **Frontend/API:** CloudFront, Route 53, API Gateway, NLB
- **Compute:** Amazon EKS (multi-region clusters)
- **Data:** Amazon RDS (Multi-AZ)
- **Multi-Tenant:** Kubernetes namespaces + RBAC, tenant-specific DB schemas, per-tenant API throttling

## Implementation Methodology

### Spec-Driven Development (Kiro)
Every security implementation follows this process:
1. **Spec Creation** — Requirements → Design → Tasks via Kiro specs (`.kiro/specs/{service-name}/`)
2. **Implementation** — All artifacts in `saas-security/{service-name}/`

### Key Rules
- Kiro provides documentation and code only — user deploys independently
- Every implementation produces BOTH manual and automated approaches
- All configurations follow AWS Well-Architected Security Pillar
- MCP servers used for documentation accuracy

### Specs Location
- Kiro specs: `.kiro/specs/{service-name}/` (requirements.md, design.md, tasks.md)
- Implementation: `saas-security/{service-name}/` (`{service}-security-design.html`, guide.md, template.yaml, scripts/)

## Locked Design & IaC Decisions

These apply to EVERY SaaS security spec and implementation:

1. **IaC = CloudFormation ONLY.** The platform is AWS-native — no Terraform. Each service folder has a `template.yaml`; never `main.tf`/`variables.tf`/`outputs.tf`.
2. **HLD/LLD lives in a dedicated self-contained `.html` file** per service — `{service-name}-security-design.html` — with all architecture + flow diagrams embedded inline and every security configuration explained with its significance. The spec's `design.md` stays lightweight and points to this HTML. Producing the HTML is an explicit task in `tasks.md`.
3. **Every design must justify reliability at 1,000-tenant scale** — defense-in-depth, data isolation, data security — with no failure gaps. A mandatory section enumerates every operational/performance/scalability/availability/security hole and its mitigation.
4. **Step-by-step console guides use the LATEST AWS GUI flow** (verified via crawl4ai/MCP), never stale UI steps.

## Repository Structure

```
saas-security/
├── README.md                          # Implementation overview and progress
├── specs-todo.md                      # Master checklist (35 specs)
├── architecture.md                    # Platform HLD + defense-in-depth model
└── {service-name}/                    # Per-service implementation (flat, CloudFormation-only)
    ├── {service-name}-security-design.html  # PRIMARY design artifact: HLD + LLD + diagrams + 1,000-tenant justification
    ├── guide.md                       # Manual console guide (latest GUI) + validation + rollback
    ├── template.yaml                  # CloudFormation template (ONLY IaC)
    └── scripts/
        ├── deploy.sh                  # Deployment automation
        └── validate.sh                # Validation + tenant-isolation test
```

## `{service}-security-design.html` Structure (Primary Design Artifact)

A self-contained HTML doc (inline CSS, embedded diagrams) — the authoritative HLD/LLD:

### Part 1: High-Level Design (HLD)
- Why this service is needed; where it sits (Control Plane vs App Plane, single Workload account)
- Architecture diagram (embedded inline) + integration points
- Defense-in-depth layer classification

### Part 2: Low-Level Design (LLD)
- Detailed config specs with significance; IAM/resource policies (full JSON); network requirements
- All flow diagrams embedded inline (request/response, auth/token, data flow w/ encryption, cross-service, failure/fallback)
- KMS/encryption design

### Part 3: 1,000-Tenant Reliability Justification (mandatory)
- Pooled tenant isolation: how `tenant_id` is enforced edge→API→compute→data (prove no cross-tenant path)
- Data isolation & security (per-tenant separation, KMS CMK scoping, residency)
- Scalability (quotas/limits at 1,000 tenants + headroom), performance under bursty load
- Availability/resilience, blast-radius containment, noisy-neighbor controls
- **Security hole/gap analysis** — every failure/misconfig/attack path + its mitigation (no gap unaddressed)
- Operational: tenant-tagged monitoring/logging/alerting

### Part 4: Security Configuration Catalog
- Every security setting, recommended value, and WHY (default vs recommended) + compliance mapping (SOC 2 / ISO 27001 / GDPR)

> Diagrams via `draw-io` (AWS-icon architecture) and `diagram-design` (sequence/data-flow) skills, embedded inline.

## `guide.md` Structure (Manual Console Guide)

### Part 1: Manual Configuration Guide
- Numbered AWS Console steps using the **latest GUI navigation/flow**
- Each step: navigation path, settings, security significance; validation checkpoint per section

### Part 2: Validation Procedures
- Verification steps, test cases (incl. a **tenant-isolation test**), expected behavior, compliance validation

### Part 3: Rollback Procedures
- Safe teardown steps

> `guide.md` opens with a link to `{service-name}-security-design.html` as the authoritative HLD/LLD.

## Defense-in-Depth Model

### Layer 1: Preventive Controls
- AWS Organizations SCPs and RCPs
- IAM policies and permissions boundaries
- Network security (VPC, SGs, NACLs, Network Firewall)
- WAF rules and Shield protection
- Encryption at rest and in transit (KMS, ACM)

### Layer 2: Detective Controls
- GuardDuty threat detection (runtime monitoring, malware protection)
- Security Hub centralized findings and compliance
- CloudTrail API auditing
- Config configuration compliance monitoring
- VPC Flow Logs network analysis
- Inspector vulnerability scanning
- Macie data classification

### Layer 3: Responsive Controls
- Automated remediation (EventBridge → Lambda/Step Functions)
- Incident response playbooks
- Forensics and investigation (Detective)
- Security operations automation

### Layer 4: Recovery Controls
- Cross-region backups with encryption
- Point-in-time recovery for RDS
- Disaster recovery procedures
- Business continuity planning

## Implementation Phases (from specs-todo.md)

| Phase | Focus | Specs |
|-------|-------|-------|
| Phase 1 | Foundation & Identity | 01-03 |
| Phase 2 | Network Security | 04-07 |
| Phase 3 | Data Protection | 08-11 |
| Phase 4 | Threat Detection | 12-15 |
| Phase 5 | Logging & Monitoring | 16-19 |
| Phase 6 | Container Security | 20-22 |
| Phase 7 | API & App Security | 23-24 |
| Phase 8 | Incident Response | 25-27 |
| Phase 9 | Compliance & Governance | 28-30 |
| Phase 10 | Advanced & AI/ML | 31-33 |
| Phase 11 | Business Continuity | 34-35 |

## Agent Integration

| Agent | Trigger | What It Does |
|-------|---------|--------------|
| `@security-architect` | `@security-architect {service}` | Creates Kiro spec + all implementation artifacts |
| `@content-updater` | `@content-updater {service}` | Refreshes existing implementation with latest docs |
| `@release-tracker` | `@release-tracker` | Flags stale implementation guides |

### Workflow
1. Pick a service from `specs-todo.md`
2. Run `@security-architect {service}` — it creates the spec AND implementation
3. Review the Kiro spec (requirements → lightweight design → tasks) and the `{service}-security-design.html` (HLD/LLD)
4. Hand the `.html` design + `guide.md` to your security engineer (design to understand, guide to configure)
5. Deploy the **CloudFormation** `template.yaml` for automation (CFN is the only IaC — no Terraform)
6. Periodically run `@release-tracker` to check for AWS updates

## MCP Server & Tool Usage

- **AWS Knowledge MCP** — search documentation for best practices (primary)
- **AWS Documentation MCP** — fetch detailed configuration guides (primary)
- **`aws` MCP server** — verify live behavior, limits, API shapes
- **crawl4ai MCP (`crawl4ai-local`)** — pull the latest AWS Console GUI flows + blog/feature pages (supplement); generic web fetch as fallback
- Activate matching **skills** from `.kiro/skills/` (mandatory when one exists)
- Cross-reference all configurations with official AWS documentation

## Quality Standards

- Follow AWS Well-Architected Security Pillar
- Multi-account compatible (all solutions work across account boundaries)
- Cost-conscious (balance security controls with operational costs)
- Compliance-aligned (SOC 2, ISO 27001, GDPR)
- Both manual and automated paths fully documented
- Production-ready (not POC configurations)

---

**This document drives all SaaS security implementation work. Every spec must produce a flat per-service folder with guide, IaC, and scripts.**
