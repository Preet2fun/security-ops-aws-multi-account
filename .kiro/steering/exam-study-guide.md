# AWS Security Specialty (SCS-C03) Exam Study Guide

## Purpose
This steering document drives **Objective 1: Exam Preparation** — creating comprehensive, deep-dive study notes for the AWS Certified Security Specialty (SCS-C03) exam using AWS Documentation and Knowledge MCP servers.

## Exam Overview
- **Exam Code:** SCS-C03 (Updated December 2025)
- **Duration:** 170 minutes | **Questions:** 65 (50 scored + 15 unscored)
- **Passing Score:** 750/1000 | **Cost:** $300 USD | **Validity:** 3 years
- **Format:** Multiple choice, multiple response, ordering, matching

## Exam Domains (7 Domains)

| Domain | Weight | Focus |
|--------|--------|-------|
| 1. Threat Detection & Incident Response | ~18% | GuardDuty, Security Hub, Detective, automated response |
| 2. Security Logging & Monitoring | ~16% | CloudTrail, VPC Flow Logs, Config, CloudWatch |
| 3. Infrastructure Security | ~18% | VPC, WAF, Shield, Network Firewall |
| 4. Identity & Access Management | ~20% | IAM, Organizations, SCPs/RCPs, Identity Center, Cognito |
| 5. Data Protection | ~18% | KMS, Secrets Manager, Macie, ACM |
| 6. Security Foundations & Governance | ~14% | Config, Systems Manager, Audit Manager, Control Tower |
| 7. Generative AI & ML Security | ~10% | Bedrock, SageMaker, GuardDuty AI/ML (NEW) |

## Study Notes Structure

All study notes live in `/exam-study/` as flat, all-in-one per-service files:

```
exam-study/
├── README.md              # Study plan and progress tracker
├── {service-name}.md      # All-in-one per service (deep-dive + threats + use-cases + exam tips)
└── domain-revision/       # Cross-service revision sheets per exam domain
    └── domain-{n}-{name}.md
```

### File Purpose
- **`{service-name}.md`**: Self-contained deep-dive per service — covers internals, config, threats, use-cases, defense-in-depth positioning, and exam tips all in ONE file. Used for both learning and revision.
- **`domain-revision/`**: Cross-service consolidated revision per exam domain — shows how multiple services work together within a domain. Used for final exam prep only.

## Study Note Template (Mandatory Sections)

When creating a study note for any AWS service, **ALL** of the following sections MUST be included in a single `exam-study/{service-name}.md` file:

### 1. Service Introduction & Significance
- What the service does and why it exists
- Its role in the AWS security ecosystem
- Key use cases for SaaS/enterprise environments

### 2. Behind-the-Scenes Technical Flow
- How the service works internally at the API and data plane level
- **Single-account scenario** — full technical flow with diagrams
- **Multi-account scenario** — delegated admin, cross-account patterns, Organizations integration
- Data flow, event propagation, and service interactions

### 3. Step-by-Step Configuration Guide
- Every configuration option with its significance
- AWS Console steps (numbered, with navigation paths)
- AWS CLI commands
- Why each setting matters from a security perspective
- Default vs recommended values
- Configuration order and dependencies

### 4. Threat Mitigation Coverage
- What cloud-native threats this service mitigates
- Application-level vs infrastructure-level protection
- Attack vectors it detects or prevents
- Per-attack: classification, real-world examples, mitigation mechanism, configuration

### 5. Real-World Use Cases
- Multi-tenant SaaS scenario
- Compliance/regulatory scenario (HIPAA, PCI, GDPR)
- DDoS/attack mitigation scenario
- Cross-account/multi-account scenario
- Each with: business context, architecture diagram, configuration, security rationale

### 6. Defense-in-Depth Positioning
- Where this service sits in the defense-in-depth model (preventive/detective/responsive)
- How it integrates with other security services
- AWS Well-Architected Security Pillar alignment
- Cost vs risk trade-off recommendations

### 7. Exam-Critical Points
- Must-know facts (numbered list)
- Common exam question patterns
- Tricky concepts and gotchas
- Comparison points with similar services
- Domain mapping

### 8. Pricing & Limits
### 9. Troubleshooting
### 10. Documentation References

## Content Freshness

- Every file includes `> Last Updated: {date}` at the top
- The `@release-tracker` agent flags files with `<!-- STALE: ... -->` comments when AWS releases affect them
- The `@content-updater` agent refreshes files against latest AWS documentation
- Every file includes a `## Change Log` section at the bottom tracking updates

## Agent Integration

| Agent | Trigger | What It Does |
|-------|---------|--------------|
| `@service-deep-dive` | `@service-deep-dive {service}` | Creates new all-in-one study file |
| `@content-updater` | `@content-updater {service}` | Refreshes existing file with latest docs |
| `@release-tracker` | `@release-tracker` | Produces weekly digest + flags stale files |

## MCP Server Usage (Mandatory)

When creating or updating any study note:
1. **ALWAYS use AWS Knowledge MCP** (`mcp_aws_knowledge_aws___search_documentation`) to search for current service documentation
2. **ALWAYS use AWS Documentation MCP** (`mcp_aws_docs_search_documentation` / `mcp_aws_docs_read_documentation`) to fetch detailed guides
3. **Cross-reference** multiple official sources for accuracy
4. **Cite** relevant documentation URLs in the References section

## Core Services to Cover (Priority Order)

### Must Master (Core Security)
1. AWS IAM (policies, roles, evaluation logic)
2. AWS KMS (key types, policies, grants, rotation)
3. Amazon GuardDuty (findings, extended detection, runtime monitoring)
4. AWS Security Hub (standards, CSPM, exposure findings)
5. AWS WAF (rules, bot control, rate limiting)
6. AWS Shield (Standard vs Advanced)
7. AWS CloudTrail (trails, Lake, data events)
8. AWS Config (rules, remediation, aggregators)

### Detection & Monitoring
9. Amazon Detective
10. Amazon Macie
11. AWS Inspector
12. Amazon CloudWatch
13. VPC Flow Logs

### Infrastructure Security
14. Amazon VPC (SGs, NACLs, endpoints, PrivateLink)
15. AWS Network Firewall
16. AWS Certificate Manager

### Identity & Governance
17. AWS Organizations (SCPs, RCPs)
18. AWS Control Tower
19. AWS IAM Identity Center
20. Amazon Cognito
21. AWS Systems Manager

### Data Protection
22. AWS Secrets Manager
23. AWS CloudHSM
24. AWS Backup

### AI/ML Security (New Domain)
25. Amazon Bedrock
26. Amazon SageMaker

## Exam Preparation Strategy

### Study Approach
- Start with IAM (highest weight domain at 20%)
- Then Infrastructure + Threat Detection (18% each)
- Data Protection (18%) and Logging (16%)
- Governance (14%) and AI/ML (10%) last

### Practice Requirements
- Consistently score 80%+ on practice exams
- Hands-on lab experience with each core service
- Scenario-based question practice
- Service integration pattern understanding

---

**This document drives all exam study content creation. Every note must follow the template, use MCP servers for accuracy, and be a single all-in-one file per service.**
