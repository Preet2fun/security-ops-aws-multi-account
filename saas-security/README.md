# SaaS Security Platform — Defense-in-Depth Implementation

## Overview
Production-grade security architecture for a **multi-tenant ITOM/ITSM SaaS platform on AWS**. Each service gets a flat folder containing manual guide, CloudFormation, Terraform, and scripts — all in one place.

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
├── README.md              ← You are here
├── specs-todo.md          # Master checklist (35 specs)
├── architecture.md        # Platform HLD + defense-in-depth model
└── {service-name}/        # Per-service implementation folder
    ├── guide.md           # Manual console guide + HLD/LLD
    ├── main.tf            # Terraform module
    ├── variables.tf       # Terraform variables
    ├── outputs.tf         # Terraform outputs
    ├── template.yaml      # CloudFormation template
    └── scripts/
        ├── deploy.sh      # Deployment script
        └── validate.sh    # Validation script
```

## Implemented Services

| Service | Folder | Status | Spec |
|---------|--------|--------|------|
| AWS Organizations | `organizations/` | Completed | Spec 01 |

## How It Works

1. **Kiro Spec** → `.kiro/specs/{service-name}/` defines requirements, design, tasks
2. **`@security-architect` agent** → produces all artifacts in `saas-security/{service-name}/`
3. **Your security engineer** → follows `guide.md` for manual setup or deploys IaC

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
