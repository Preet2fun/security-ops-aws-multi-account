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

All study notes live in `/exam-study/` and follow this structure:

```
exam-study/
├── README.md                          # Study plan and progress tracker
├── aws-services/                      # Deep-dive per service (self-contained)
│   ├── organizations-deep-dive.md
│   ├── cloudfront-deep-dive.md
│   └── ... (one per service)
├── exam-domain-mapping/               # Cross-service revision sheets per exam domain
│   ├── domain-1-threat-detection.md
│   ├── domain-2-logging-monitoring.md
│   ├── domain-3-infrastructure-security.md
│   ├── domain-4-iam.md
│   ├── domain-5-data-protection.md
│   ├── domain-6-governance.md
│   └── domain-7-ai-ml-security.md
├── real-world-use-cases/              # Detailed production scenarios per service
│   ├── cloudfront-use-cases.md
│   └── ... (one per service)
└── threat-mitigation/                 # Real-world attacks mitigated by each service
    ├── cloudfront-threat-mitigation.md
    └── ... (one per service)
```

### Folder Purpose
- **aws-services/**: Self-contained deep-dive per service — covers internals, config, threats, defense-in-depth positioning, and exam tips all in one file. Used for first-time learning.
- **exam-domain-mapping/**: Cross-service consolidated revision per exam domain — shows how multiple services work together within a domain. Used for final exam prep.
- **real-world-use-cases/**: Detailed production architecture scenarios with full configurations for a specific service. Used for understanding practical application and real-world patterns.
- **threat-mitigation/**: Maps real-world cloud attacks (infra-level and app-level) to how a specific AWS service prevents/mitigates them. Used for understanding the "why" behind security controls.

## Study Note Template (Mandatory Sections)

When creating a deep-dive note for any AWS service, **ALL** of the following sections MUST be included:

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
- Why each setting matters from a security perspective
- Default vs recommended values
- Configuration order and dependencies

### 4. Threat Mitigation Coverage
- What cloud-native threats this service mitigates
- Application-level vs infrastructure-level protection
- Attack vectors it detects or prevents
- Threat scenarios (with examples)

### 5. Defense-in-Depth Positioning
- Where this service sits in the defense-in-depth model (preventive/detective/responsive)
- How it integrates with other security services
- AWS Well-Architected Security Pillar alignment
- Cost vs risk trade-off recommendations

### 6. Exam-Critical Points
- Explicitly marked sections important for the exam
- Common exam question patterns for this service
- Tricky concepts and gotchas
- Comparison points with similar services

### 7. Additional Sections (as needed)
- Pricing model and cost optimization
- Limits and quotas
- Common troubleshooting scenarios
- Integration patterns

## MCP Server Usage (Mandatory)

When creating any study note:
1. **ALWAYS use AWS Knowledge MCP** (`mcp_aws_knowledge_aws___search_documentation`) to search for current service documentation
2. **ALWAYS use AWS Documentation MCP** (`mcp_aws_docs_search_documentation` / `mcp_aws_docs_read_documentation`) to fetch detailed guides
3. **Cross-reference** multiple official sources for accuracy
4. **Cite** relevant documentation URLs in notes

## Real-World Use Cases Template (Mandatory for real-world-use-cases/ folder)

When creating a real-world use cases file for a service, include:

### Per Use Case:
1. **Business Context** — Why does this scenario exist? What business problem?
2. **Architecture Diagram** — ASCII diagram showing the full flow with security components
3. **Configuration Details** — Actual settings, policies, and code snippets
4. **Security Rationale** — Why each decision was made from a security perspective

### Use Case Types to Cover:
- Multi-tenant SaaS scenario
- Compliance/regulatory scenario (HIPAA, PCI, GDPR)
- DDoS/attack mitigation scenario
- Cross-account/multi-account scenario
- Zero-trust / mTLS scenario
- Disaster recovery / failover scenario
- Troubleshooting / incident scenario

## Threat Mitigation Template (Mandatory for threat-mitigation/ folder)

When creating a threat-mitigation file for a service, include:

### Per Attack:
1. **Classification** — Infrastructure-Level or Application-Level attack
2. **What It Is** — Brief technical description of the attack
3. **Real-World Examples** — Actual breaches or incidents (with dates where possible)
4. **How the Service Mitigates** — Table mapping features to mitigation mechanism
5. **Configuration** — Actual config/code to enable the mitigation
6. **Key Exam Point** — What to remember for the exam

### Attack Types to Cover:
- DDoS (volumetric and application layer)
- Injection attacks (SQLi, XSS, command injection)
- Man-in-the-middle / protocol attacks
- Unauthorized access / data theft
- Bot abuse / credential stuffing
- Origin exposure / bypass attacks
- Encryption/protocol downgrade attacks
- Any service-specific threats

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

**This document drives all exam study content creation. Every note must follow the template and use MCP servers for accuracy.**
