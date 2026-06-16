# SaaS Security Platform — Defense-in-Depth Implementation

## Overview
This folder contains the complete security implementation for a **multi-tenant ITOM/ITSM SaaS platform on AWS**. Every security control is implemented using spec-driven development (Kiro specs) with both manual AWS Console guides and Infrastructure as Code (CloudFormation + Terraform).

## Platform Architecture

### Account Structure
```
┌─────────────────────────────────────────────────────────┐
│                    AWS Organizations                      │
├─────────────────┬──────────────┬────────────────────────┤
│ Management Acct │  Audit Acct  │     Logging Acct       │
│ (Governance)    │ (Security)   │  (Centralized Logs)    │
├─────────────────┴──────────────┴────────────────────────┤
│                   Workload Account                        │
│  ┌─────────────────────────────────────────────────┐    │
│  │ Internet → Route53 → CloudFront → API GW → NLB │    │
│  │                                       ↓         │    │
│  │                              EKS Clusters       │    │
│  │                                       ↓         │    │
│  │                                 RDS (Multi-AZ)  │    │
│  └─────────────────────────────────────────────────┘    │
│                Security Services Layer                    │
│     (WAF, Shield, GuardDuty, Config, CloudTrail, etc.)  │
└─────────────────────────────────────────────────────────┘
```

### Multi-Tenant Isolation
- **Compute:** Kubernetes namespaces + RBAC per tenant
- **Data:** Tenant-specific database schemas
- **API:** Per-tenant throttling via API Gateway usage plans
- **Monitoring:** Tenant-aware logging and alerting

## Implementation Approach

Each security spec produces:
1. **Kiro Spec** (`.kiro/specs/{spec-name}/`) — Requirements → Design → Tasks
2. **Manual Guide** (`implementation/manual-configuration/`) — AWS Console step-by-step
3. **CloudFormation** (`implementation/automation/cloudformation/`) — Templates with parameters
4. **Terraform** (`implementation/automation/terraform/`) — Modules per layer
5. **Scripts** (`implementation/automation/scripts/`) — Deploy, validate, cleanup

## Defense-in-Depth Layers

| Layer | Type | Services |
|-------|------|----------|
| 1 | Preventive | SCPs, RCPs, IAM, VPC, SGs, NACLs, WAF, Shield, KMS, ACM |
| 2 | Detective | GuardDuty, Security Hub, CloudTrail, Config, Flow Logs, Inspector, Macie |
| 3 | Responsive | EventBridge, Lambda, Step Functions, Playbooks, Detective |
| 4 | Recovery | Backups, Cross-region replication, DR procedures |

## Folder Structure

```
saas-security/
├── README.md                          ← You are here
├── specs-todo.md                      # Master checklist (35 specs)
├── architecture/                      # Architecture docs and diagrams
├── implementation/
│   ├── manual-configuration/          # AWS Console guides (numbered)
│   └── automation/
│       ├── cloudformation/            # CFn templates by layer
│       ├── terraform/                 # TF modules by layer
│       └── scripts/                   # Deploy/validate/cleanup
├── security-operations/
│   ├── playbooks/                     # Incident response, threat hunting
│   ├── automation/                    # Lambda, Step Functions, EventBridge
│   └── monitoring/                    # Dashboards, alerts, metrics
├── policies/                          # IAM, SCP, RCP, resource policies
└── compliance/                        # SOC2, ISO27001, GDPR controls
```

## Progress

See [specs-todo.md](./specs-todo.md) for the full implementation checklist with phases, priorities, and dependencies.

---

*All implementations follow AWS Well-Architected Security Pillar best practices and are sourced from official documentation via MCP servers.*
