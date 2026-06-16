# SaaS Security Platform — Defense-in-Depth Implementation Guide

## Purpose
This steering document drives **Objective 2: SaaS Platform Security Implementation** — building a comprehensive, production-grade security architecture for a multi-tenant ITOM/ITSM SaaS platform on AWS using spec-driven development with both manual and automated (IaC) configuration approaches.

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
1. **Spec Creation** — Requirements → Design → Tasks via Kiro specs
2. **Manual Configuration** — Step-by-step AWS Console guide with validation
3. **Infrastructure as Code** — CloudFormation templates + Terraform modules
4. **Deployment Scripts** — Automated deployment and validation scripts

### Key Rules
- Kiro provides documentation and code only — user deploys independently
- Every implementation produces BOTH manual and automated approaches
- All configurations follow AWS Well-Architected Security Pillar
- MCP servers used for documentation accuracy

### Specs Location
All implementation specs live in `.kiro/specs/` and implementation artifacts in `/saas-security/`

## Repository Structure for SaaS Security

```
saas-security/
├── README.md                              # Implementation overview and progress
├── specs-todo.md                          # Master checklist of all security specs
├── architecture/
│   ├── security-architecture.md           # Overall security architecture
│   ├── multi-account-strategy.md          # Account structure design
│   ├── network-design.md                  # Network topology
│   ├── defense-in-depth-model.md          # Layered security model
│   └── threat-model.md                    # Platform threat model
├── implementation/
│   ├── manual-configuration/              # AWS Console step-by-step guides
│   │   ├── 01-organizations-setup.md
│   │   ├── 02-iam-strategy.md
│   │   └── ... (numbered by spec order)
│   └── automation/
│       ├── cloudformation/
│       │   ├── templates/
│       │   │   ├── foundation/            # Organizations, Control Tower, IAM
│       │   │   ├── security/              # GuardDuty, Security Hub, CloudTrail
│       │   │   ├── network/               # VPC, WAF, Network Firewall
│       │   │   └── data-protection/       # KMS, Secrets Manager, S3
│       │   ├── parameters/
│       │   └── nested-stacks/
│       ├── terraform/
│       │   ├── modules/
│       │   │   ├── foundation/
│       │   │   ├── security/
│       │   │   ├── network/
│       │   │   └── data-protection/
│       │   └── environments/
│       │       ├── dev/
│       │       ├── staging/
│       │       └── prod/
│       └── scripts/
│           ├── deployment/
│           ├── validation/
│           └── cleanup/
├── security-operations/
│   ├── playbooks/
│   │   ├── incident-response/
│   │   ├── threat-hunting/
│   │   └── vulnerability-management/
│   ├── automation/
│   │   ├── lambda-functions/
│   │   ├── step-functions/
│   │   ├── eventbridge-rules/
│   │   └── remediation-scripts/
│   └── monitoring/
│       ├── cloudwatch-dashboards/
│       ├── alerting-rules/
│       └── custom-metrics/
├── policies/
│   ├── iam-policies/
│   ├── scp-policies/
│   ├── rcp-policies/
│   └── resource-policies/
└── compliance/
    ├── frameworks/
    │   ├── soc2-controls.md
    │   ├── iso27001-controls.md
    │   └── gdpr-compliance.md
    └── assessments/
```

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

---

**This document drives all SaaS security implementation work. Every spec must produce manual guides, IaC automation, and integrate with the defense-in-depth model.**
