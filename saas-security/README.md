# SaaS Security Platform — Defense-in-Depth Implementation

## Overview
Production-grade security architecture for a **multi-tenant AI-native observability & security SaaS platform on AWS** (1,000 tenants). Each service gets a flat folder containing a dedicated HLD/LLD security-design HTML, a manual console guide, a CloudFormation template, and scripts.

> **Design standards (locked):** CloudFormation is the ONLY IaC (no Terraform). Every service has a `{service}-security-design.html` (HLD + LLD + diagrams + security-config significance) that justifies reliability at **1,000-tenant scale** (defense-in-depth, data isolation, data security — no gaps). Console guides use the latest AWS GUI flow. See `.kiro/steering/platform.md` and `.kiro/steering/saas-security-implementation.md`.

## Platform Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AWS Organizations                      │
├─────────────────┬──────────────┬────────────────────────┤
│ Management Acct │  Audit Acct  │     Logging Acct       │
│ (Governance)    │ (Security)   │  (Centralized Logs)    │
├─────────────────┴──────────────┴────────────────────────┤
│                   Workload Account                        │
│  Internet → Route53 → CloudFront → API GW → NLB → EKS  │
│                                                     ↓    │
│                                               RDS (Multi-AZ) │
│             Security Services Layer                       │
│     (WAF, Shield, GuardDuty, Config, CloudTrail, etc.)  │
└─────────────────────────────────────────────────────────┘
```

## Folder Structure

```
saas-security/
├── README.md                          ← You are here
├── specs-todo.md                      # Master checklist (35 specs)
├── architecture.md                    # Platform HLD + defense-in-depth model
└── {service-name}/                    # Per-service implementation folder (CloudFormation-only)
    ├── {service-name}-security-design.html  # PRIMARY: HLD + LLD + diagrams + 1,000-tenant justification
    ├── guide.md                       # Manual console guide (latest GUI) + validation + rollback
    ├── template.yaml                  # CloudFormation template (ONLY IaC — no Terraform)
    └── scripts/
        ├── deploy.sh                  # Deployment script
        └── validate.sh                # Validation + tenant-isolation test
```

## Implemented Services

| Service | Folder | Status | Spec |
|---------|--------|--------|------|
| AWS Organizations | `organizations/` | Completed | Spec 01 |

## How It Works

1. **Kiro Spec** → `.kiro/specs/{service-name}/` defines requirements, lightweight design (pointer to the HTML), and tasks
2. **`@security-architect` agent** → produces all artifacts in `saas-security/{service-name}/`: the `{service}-security-design.html` (HLD/LLD), `guide.md`, `template.yaml`, scripts
3. **Your security engineer** → reads the `.html` design to understand the architecture, follows `guide.md` for manual setup, or deploys `template.yaml`

> **Note (Organizations folder):** the existing `organizations/` folder predates these standards — it has `guide.md` + `template.yaml` + scripts but not yet a `{service}-security-design.html`. New services follow the full standard; Organizations can be upgraded on its next revision.

## Defense-in-Depth Layers

| Layer | Type | Services |
|-------|------|----------|
| 1 | Preventive | SCPs, RCPs, IAM, VPC, SGs, NACLs, WAF, Shield, KMS, ACM |
| 2 | Detective | GuardDuty, Security Hub, CloudTrail, Config, Flow Logs, Inspector, Macie |
| 3 | Responsive | EventBridge, Lambda, Step Functions, Playbooks, Detective |
| 4 | Recovery | Backups, Cross-region replication, DR procedures |

## Agents

- `@security-architect {service}` — Creates Kiro spec + full implementation folder
- `@content-updater {service}` — Updates existing implementation with latest AWS changes

---

*All implementations follow AWS Well-Architected Security Pillar best practices.*
