# SaaS Security Platform — Architecture Document

> Last Updated: August 2025

## Platform Overview

Multi-tenant ITOM/ITSM SaaS platform on AWS with defense-in-depth security architecture.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    AWS Organizations                      │
├─────────────────┬──────────────┬────────────────────────┤
│ Management Acct │  Audit Acct  │     Logging Acct       │
│ (Governance)    │ (Security)   │  (Centralized Logs)    │
├─────────────────┴──────────────┴────────────────────────┤
│                   Workload Account                        │
│                                                          │
│  Internet → Route53 → CloudFront → API GW → NLB → EKS  │
│                                                     ↓    │
│                                               RDS (Multi-AZ) │
│                                                          │
│             Security Services Layer                       │
│     (WAF, Shield, GuardDuty, Config, CloudTrail, etc.)  │
└─────────────────────────────────────────────────────────┘
```

## Defense-in-Depth Layers

| Layer | Type | Controls |
|-------|------|----------|
| 1 | Preventive | SCPs, RCPs, IAM, VPC, SGs, NACLs, WAF, Shield, KMS |
| 2 | Detective | GuardDuty, Security Hub, CloudTrail, Config, Flow Logs, Inspector, Macie |
| 3 | Responsive | EventBridge → Lambda/Step Functions, Playbooks, Detective |
| 4 | Recovery | Backups, Cross-region replication, DR procedures |

## Per-Service Architecture

Each service implementation in this folder includes its own architecture section in `guide.md` showing how it integrates with the platform above.

## Implementation Status

See [specs-todo.md](./specs-todo.md) for the full implementation checklist.

---

*This document is maintained by the `@security-architect` agent and updated as new services are implemented.*
