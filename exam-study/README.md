# AWS Security Specialty (SCS-C03) — Exam Study Notes

## Overview
This folder contains comprehensive, deep-dive study materials for the **AWS Certified Security Specialty (SCS-C03)** exam. Each note is created using official AWS documentation (via MCP servers) and follows a structured template covering technical internals, configuration details, threat mitigation, and exam-critical points.

## Exam Details
| Field | Value |
|-------|-------|
| Exam Code | SCS-C03 |
| Duration | 170 minutes |
| Questions | 65 (50 scored + 15 unscored) |
| Passing Score | 750/1000 |
| Cost | $300 USD |
| Validity | 3 years |
| Format | Multiple choice, multiple response, ordering, matching |

## Study Progress Tracker

### Domain 1: Threat Detection & Incident Response (~18%)
- [ ] Amazon GuardDuty
- [ ] AWS Security Hub
- [ ] Amazon Detective
- [ ] AWS Inspector
- [ ] Automated Incident Response (EventBridge + Lambda + Step Functions)

### Domain 2: Security Logging & Monitoring (~16%)
- [ ] AWS CloudTrail
- [ ] VPC Flow Logs
- [ ] AWS Config
- [ ] Amazon CloudWatch (Security Monitoring)

### Domain 3: Infrastructure Security (~18%)
- [ ] Amazon VPC (Security Groups, NACLs, Endpoints, PrivateLink)
- [x] Amazon CloudFront (SSL/TLS, OAC, Signed URLs, FLE, Security Headers)
- [ ] AWS WAF
- [ ] AWS Shield
- [ ] AWS Network Firewall

### Domain 4: Identity & Access Management (~20%)
- [ ] AWS IAM (Policies, Roles, Evaluation Logic)
- [ ] AWS Organizations (SCPs, RCPs)
- [ ] AWS IAM Identity Center
- [ ] Amazon Cognito
- [ ] Cross-Account Access Patterns

### Domain 5: Data Protection (~18%)
- [ ] AWS KMS
- [ ] AWS Secrets Manager
- [ ] Amazon Macie
- [ ] AWS Certificate Manager (ACM)
- [ ] AWS CloudHSM

### Domain 6: Security Foundations & Governance (~14%)
- [ ] AWS Control Tower
- [ ] AWS Systems Manager
- [ ] AWS Audit Manager
- [ ] Compliance Frameworks (SOC 2, ISO 27001, PCI DSS)

### Domain 7: Generative AI & ML Security (~10%) — NEW
- [ ] Amazon Bedrock Security
- [ ] Amazon SageMaker Security
- [ ] GuardDuty AI/ML Detection

## Folder Structure

```
exam-study/
├── README.md                          ← You are here
├── aws-services/                      # Deep-dive notes per AWS service
│   ├── organizations-deep-dive.md
│   └── cloudfront-deep-dive.md
├── exam-domain-mapping/               # Cross-service consolidated revision per exam domain
│   └── domain-6-governance.md         #   (links multiple services together)
├── real-world-use-cases/              # Detailed production scenarios per service
│   └── cloudfront-use-cases.md
└── threat-mitigation/                 # Real-world attacks mitigated per service
    └── cloudfront-threat-mitigation.md
```

### Folder Purpose

| Folder | What Goes In It | When to Use |
|--------|-----------------|-------------|
| `aws-services/` | Self-contained deep-dive per service (internals, config, threats, exam tips) | Learning a service for the first time |
| `exam-domain-mapping/` | Cross-service revision sheet per exam domain (how services work together) | Final revision before exam |
| `real-world-use-cases/` | Production architecture scenarios with configs for a specific service | Understanding practical application |
| `threat-mitigation/` | Real-world cloud attacks (infra & app level) mitigated by each service | Understanding WHY we need the service |

## Study Note Template

Every deep-dive note includes these mandatory sections:

1. **Service Introduction & Significance** — What it does, why it matters
2. **Behind-the-Scenes Technical Flow** — Single-account and multi-account internals
3. **Step-by-Step Configuration Guide** — Every setting with its security significance
4. **Threat Mitigation Coverage** — What threats it mitigates (app-level vs infra-level)
5. **Defense-in-Depth Positioning** — Where it sits in the security model
6. **Exam-Critical Points** — Key facts, gotchas, and common question patterns

## Recommended Study Order

1. **Start with IAM** (20% weight — highest)
2. **Infrastructure Security** (18%)
3. **Threat Detection** (18%)
4. **Data Protection** (18%)
5. **Logging & Monitoring** (16%)
6. **Governance** (14%)
7. **AI/ML Security** (10%)

---

*All notes are sourced from official AWS documentation via MCP servers and cross-referenced for accuracy.*
