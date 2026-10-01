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
- Implementation: `saas-security/{service-name}/` (guide.md, main.tf, template.yaml, scripts/)

## Repository Structure

```
saas-security/
├── README.md              # Implementation overview and progress
├── specs-todo.md          # Master checklist (35 specs)
├── architecture.md        # Platform HLD + defense-in-depth model
└── {service-name}/        # Per-service implementation (flat)
    ├── guide.md           # HLD + LLD + manual console guide + validation
    ├── main.tf            # Terraform module
    ├── variables.tf       # Terraform variables
    ├── outputs.tf         # Terraform outputs
    ├── template.yaml      # CloudFormation template
    └── scripts/
        ├── deploy.sh      # Deployment automation
        └── validate.sh    # Validation and testing
```

## Guide.md Structure (Per Service)

Every `guide.md` file must contain:

### Part 1: High-Level Design (HLD)
- Why this service is needed for the platform
- Architecture diagram showing integration points
- Defense-in-depth layer classification
- Multi-account deployment model

### Part 2: Low-Level Design (LLD)
- Detailed configuration specifications
- IAM policies and resource policies (full JSON)
- Network requirements
- Data flow with encryption points
- Multi-tenant considerations

### Part 3: Manual Configuration Guide
- Numbered step-by-step AWS Console instructions
- Navigation paths, settings, and validation checkpoints
- Why each setting matters from a security perspective

### Part 4: Validation Procedures
- Verification steps
- Test cases
- Compliance validation (SOC 2, ISO 27001)

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
3. Review the Kiro spec (requirements → design → tasks)
4. Hand `guide.md` to your security engineer for manual configuration
5. Deploy IaC (Terraform or CloudFormation) for automation
6. Periodically run `@release-tracker` to check for AWS updates

## MCP Server Usage

- **AWS Knowledge MCP** — search documentation for best practices
- **AWS Documentation MCP** — fetch detailed configuration guides
- **Terraform MCP** — registry lookups for modules and providers
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
