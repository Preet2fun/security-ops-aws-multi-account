# AWS Security Specialty (SCS-C03) — Exam Study Notes

## Overview
Comprehensive, all-in-one study files for the **AWS Certified Security Specialty (SCS-C03)** exam. Each service file is self-contained — covering internals, configuration, threats, use cases, and exam tips in a single document.

## Exam Details
| Field | Value |
|-------|-------|
| Exam Code | SCS-C03 |
| Duration | 170 minutes |
| Questions | 65 (50 scored + 15 unscored) |
| Passing Score | 750/1000 |
| Format | Multiple choice, multiple response, ordering, matching |

## Study Progress

### Domain 3: Infrastructure Security (~18%)
- [x] Amazon CloudFront — `cloudfront.md`
- [x] Amazon VPC — `vpc.md`
- [ ] AWS WAF
- [ ] AWS Shield
- [ ] AWS Network Firewall

### Domain 4: Identity & Access Management (~20%)
- [x] AWS Organizations — `organizations.md`
- [ ] AWS IAM
- [ ] AWS IAM Identity Center
- [x] Amazon Cognito — `cognito.md`

### Domain 1: Threat Detection & Incident Response (~18%)
- [ ] Amazon GuardDuty
- [ ] AWS Security Hub
- [ ] Amazon Detective
- [ ] AWS Inspector

### Domain 5: Data Protection (~18%)
- [ ] AWS KMS
- [ ] AWS Secrets Manager
- [ ] Amazon Macie
- [ ] AWS Certificate Manager

### Domain 2: Security Logging & Monitoring (~16%)
- [ ] AWS CloudTrail
- [ ] VPC Flow Logs
- [ ] AWS Config
- [ ] Amazon CloudWatch

### Domain 6: Security Foundations & Governance (~14%)
- [ ] AWS Control Tower
- [ ] AWS Systems Manager
- [ ] AWS Audit Manager

### Domain 7: Generative AI & ML Security (~10%)
- [ ] Amazon Bedrock
- [ ] Amazon SageMaker

## Folder Structure

```
exam-study/
├── README.md              ← You are here
├── cloudfront.md          # All-in-one: deep-dive + threats + use-cases
├── cognito.md             # All-in-one: deep-dive + threats + use-cases + multi-tenant
├── vpc.md                 # All-in-one: deep-dive + threats + use-cases
├── organizations.md       # All-in-one: deep-dive
└── domain-revision/       # Cross-service exam domain revision sheets
    └── domain-6-governance.md
```

## File Structure (per service)

Each service file contains ALL of these sections in one document:

1. **Service Introduction & Significance**
2. **Behind-the-Scenes Technical Flow** (mermaid + ASCII diagrams)
3. **Step-by-Step Configuration Guide** (AWS Console + CLI)
4. **Threat Mitigation** (real-world attacks → service defenses)
5. **Real-World Use Cases** (production architecture scenarios)
6. **Defense-in-Depth Positioning**
7. **Exam-Critical Points** (gotchas, comparison tables, question patterns)
8. **Detailed Attack Mitigation Reference** (expanded per-attack analysis)
9. **Production Use Cases & Architecture Patterns** (enterprise scenarios)

## How to Use

- **Learning a service**: Read the service file top-to-bottom
- **Quick revision**: Jump to "Exam-Critical Points" section
- **Understanding threats**: Jump to "Detailed Attack Mitigation Reference"
- **Domain revision**: Use `domain-revision/` files for cross-service review

## Agents

- `@service-deep-dive {service}` — Creates a new all-in-one study file for any AWS service
- `@content-updater {service}` — Refreshes existing file with latest AWS documentation

---

*All content sourced from official AWS documentation via MCP servers.*
