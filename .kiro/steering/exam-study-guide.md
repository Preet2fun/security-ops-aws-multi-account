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

All study notes live in `/exam-study/` as flat, all-in-one per-service **HTML files**:

```
exam-study/
├── README.md               # Study plan and progress tracker
├── {service-name}.html      # All-in-one per service (deep-dive + threats + use-cases + exam tips + embedded diagrams)
└── domain-revision/         # Cross-service revision sheets per exam domain
    └── domain-{n}-{name}.html
```

### File Format: HTML (not Markdown)
- Study notes are authored as **self-contained `.html` files** so diagrams (SVG/draw.io exports) can be embedded directly inline alongside the content.
- Each file is a single HTML document with inline CSS — no external dependencies, opens in any browser.
- Content structure (the 10 mandatory sections) stays the same; only the file format changes from `.md` to `.html`.
- Diagrams are embedded inline in the relevant section (inline SVG or base64-encoded PNG) — there is NO separate diagrams folder.

### File Purpose
- **`{service-name}.html`**: Self-contained deep-dive per service — covers internals, config, threats, use-cases, defense-in-depth positioning, exam tips, and embedded diagrams all in ONE file. Used for both learning and revision.
- **`domain-revision/`**: Cross-service consolidated revision per exam domain — shows how multiple services work together within a domain. Used for final exam prep only.

> **Note on existing `.md` files**: The current `cloudfront.md`, `vpc.md`, `organizations.md`, and `cognito.md` are the legacy format. New notes are created as `.html`. When `@content-updater` next touches a legacy `.md` file, it should convert it to `.html` with embedded diagrams.

## Study Note Template (Mandatory Sections)

When creating a study note for any AWS service, **ALL** of the following sections MUST be included in a single `exam-study/{service-name}.html` file:

### 1. Service Introduction & Significance
- What the service does and why it exists
- Its role in the AWS security ecosystem
- Key use cases for SaaS/enterprise environments

### 2. Behind-the-Scenes Technical Flow
- How the service works internally at the API and data plane level
- **Single-account scenario** — full technical flow with diagrams
- **Multi-account scenario** — delegated admin, cross-account patterns, Organizations integration
- Data flow, event propagation, and service interactions
- *Diagrams: use `@diagram-creator` / `draw-io` skill for architecture, `diagram-design` skill for sequence/data-flow — embed inline in the HTML note (see Diagram Standards below)*

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
- *Architecture diagrams: generate via `@diagram-creator` / `draw-io` skill, embedded inline in the HTML note (see Diagram Standards below)*

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
| `@diagram-creator` | `@diagram-creator {description}` | Creates professional `.drawio` AWS architecture diagrams |

## Diagram Standards (Mandatory)

Whenever a study note needs a diagram, use the dedicated diagram tooling — do NOT hand-author complex diagrams inline unless it is a trivial sketch. All diagrams are embedded **directly inside the service's `.html` study note** (inline SVG, or draw.io exported to SVG/PNG and embedded). There is no separate diagrams folder.

### Which tool to use

| Diagram Need | Use | Why |
|--------------|-----|-----|
| AWS architecture with service icons (request flow, multi-account layout, network topology) | `@diagram-creator` agent OR `draw-io` skill | Produces `.drawio` XML with official AWS icon stencils, export to SVG/PNG for embedding |
| Sequence, data-flow, state machine, ER, dependency graph, flowchart (editorial HTML/SVG) | `diagram-design` skill | 40+ visual types as self-contained HTML/SVG — embeds cleanly into the study note |
| Trivial sketch (a few boxes/arrows) | Inline SVG or simple HTML directly in the note | Fast, no tooling overhead |

### Rules
1. **Architecture + request/response flow diagrams** → generate via the `@diagram-creator` agent or the `draw-io` skill, then embed the exported SVG/PNG inline in the `.html` study note.
2. **Behavioral/flow diagrams** (auth sequences, token exchange, event choreography) → use the `diagram-design` skill for HTML/SVG output, embedded inline.
3. **Embed, don't link**: diagrams live inside the service `.html` file (inline `<svg>` or base64 `<img>`), keeping each study note self-contained. Do NOT create a separate diagrams directory or reference external image files.
4. **Icons**: Use `mxgraph.aws4.*` stencils only (aws3 is deprecated). Run `python .kiro/skills/draw-io/scripts/find_aws_icon.py <service>` when unsure of an icon identifier.
5. Follow the 12-point quality checklist in `.kiro/skills/draw-io/SKILL.md` before considering a diagram complete.

> **Note:** The `@service-deep-dive` and `@content-updater` agents should invoke `@diagram-creator` / the diagram skills for any non-trivial architecture or flow diagram, and embed the result inline in the `.html` study note rather than producing low-fidelity ASCII art.

## MCP Server & Skill Usage (Mandatory)

When creating or updating any study note, you MUST use BOTH the AWS MCP servers (for the latest documentation) AND the relevant locally-installed AWS skills (for authoritative, service-specific guidance). This guarantees every note reflects the latest-and-greatest AWS knowledge.

### MCP Servers (always)
1. **ALWAYS use AWS Knowledge MCP** (`mcp_aws_knowledge_aws___search_documentation`) to search for current service documentation
2. **ALWAYS use AWS Documentation MCP** (`mcp_aws_docs_search_documentation` / `mcp_aws_docs_read_documentation`) to fetch detailed guides
3. **ALWAYS use the AWS MCP server** (`aws` — runtime API access + sandboxed script execution + real-time docs) when verifying current service behavior, limits, or API shapes
4. **Cross-reference** multiple official sources for accuracy
5. **Cite** relevant documentation URLs in the References section

### Information-source priority (tiered)

AWS MCP is **authoritative and primary** for all AWS service facts. Web crawling supplements it; it never replaces it.

| Tier | Tool | Use for |
|------|------|---------|
| 1 (primary) | AWS Knowledge MCP + AWS Documentation MCP + `aws` MCP | All AWS service facts — internals, config, limits, APIs, best practices |
| 2 (supplement) | **crawl4ai MCP** (`crawl4ai-local`) | Full content of a specific supporting page — AWS blog, feature page, What's New, re:Post — not in the docs index |
| 3 (fallback) | generic web fetch | Only if crawl4ai fails or is unavailable |

- Never use crawl4ai in place of AWS MCP for core service knowledge.
- **Exception — `@release-tracker`:** crawl4ai is PRIMARY there, because the Security Blog and What's New feed are web pages, not indexed docs.

### Skills (always, when one exists for the service)
Before writing any section for a service, **ALWAYS activate the matching installed skill** under `.kiro/skills/`. Skills carry curated, service-specific best practices, config patterns, and gotchas that supplement the raw docs. Use the skill guidance together with MCP docs — never one without the other when a skill exists.

**Rule:** If a skill exists for the service (or a closely related aspect), activating it is MANDATORY. If no skill matches, rely on MCP docs alone and note that in the Change Log.

#### Skill map for the 34-service study scope

| Study Service / Topic | Mandatory Skill(s) in `.kiro/skills/` |
|------------------------|----------------------------------------|
| AWS IAM | `aws-iam` |
| IAM Identity Center / auth flows / Cognito | `aws-auth`, `aws-iam` |
| AWS Secrets Manager | `creating-secrets-using-best-practices` |
| AWS KMS / data-at-rest encryption | `aws-security`, `securing-s3-buckets` (S3 SSE patterns) |
| Amazon VPC (SGs, NACLs, endpoints, PrivateLink) | `creating-production-vpc-multi-az`, `configuring-vpc-endpoints-for-private-aws-service-access`, `connecting-vpcs-with-peering`, `enabling-lambda-vpc-internet-access`, `aws-networking` |
| AWS WAF | `waf` |
| AWS Shield | `shieldadvanced` |
| AWS Network Firewall / Transit Gateway / DX / VPN | `aws-networking`, `transitgateway`, `directconnect`, `sitetositevpn` |
| Amazon CloudFront | `cloudfront`, `routing-traffic-with-route53-and-cloudfront` |
| Amazon Route 53 (incl. DNS Firewall) | `route53`, `routing-traffic-with-route53-and-cloudfront` |
| AWS CloudTrail | `setting-up-cloudtrail-multi-region` |
| Amazon CloudWatch / monitoring / Application Signals | `aws-observability`, `setting-up-cloudwatch-observability`, `setting-up-cloudwatch-alarm-notifications`, `querying-aws-cloudwatch` |
| Amazon S3 security | `securing-s3-buckets`, `querying-aws-s3`, `troubleshooting-s3-files` |
| AWS CloudFormation / CDK (IaC for notes) | `aws-cloudformation`, `aws-cdk`, `aws-deployment` |
| EKS / containers | `aws-containers` |
| EC2 security (profiles, hardening, Image Builder) | `launching-ec2-instance-with-best-practices`, `setting-up-ec2-instance-profiles`, `amazon-ec2-image-builder`, `aws-compute` |
| RDS / Aurora (DB security) | `amazon-aurora-postgresql`, `amazon-aurora-mysql`, `creating-amazon-aurora-db-cluster-with-instances`, `exporting-rds-to-s3`, `aws-database` |
| API Gateway / Lambda / serverless security | `aws-serverless`, `connecting-lambda-to-api-gateway`, `creating-api-gateway-stage`, `deploying-custom-domain-rest-api`, `debugging-lambda-timeouts` |
| Step Functions / EventBridge (incident-response automation) | `aws-step-functions`, `amazon-eventbridge-event-bus`, `processing-s3-uploads-with-step-functions`, `aws-messaging-and-streaming` |
| Security Lake / log analytics / querying | `querying-aws-cloudwatch`, `querying-aws-s3`, `querying-data-lake`, `exploring-data-catalog` |
| Resilience / DR / backup (recovery layer) | `aws-resilience-lifecycle`, `resilience-hub-getting-started`, `recovery-controller-setup`, `arc-region-switch`, `aws-fault-injection-service` |
| Well-Architected Security Pillar alignment | `aws-well-architected-review` |
| General security posture / cross-service | `aws-security` |
| Storage security (EFS, S3, vectors) | `aws-storage`, `troubleshooting-efs`, `storing-and-querying-vectors` |
| Any architecture / flow diagram | `draw-io`, `diagram-design` (see Diagram Standards) |

> **Discovery:** The full installed skill set lives in `.kiro/skills/`. Kiro auto-discovers and activates skills on demand when a task matches. When in doubt about which skill applies, list `.kiro/skills/` and match by service name. Services without a dedicated skill (e.g., GuardDuty, Security Hub, Detective, Inspector, Macie, Organizations, Config, ACM, Private CA, Payment Cryptography, Audit Manager, Artifact, Control Tower, Verified Permissions, Verified Access, Directory Service, RAM, Firewall Manager, Security Incident Response) → use MCP docs as the authoritative source and note the absence of a skill.

### Combined workflow (every note)
1. Identify the service → activate the matching skill(s) from the map above
2. Search/fetch latest docs via AWS Knowledge + AWS Documentation MCP
3. Verify current behavior/limits via the `aws` MCP server when needed
4. Synthesize skill guidance + MCP docs into the note (skills for best-practice patterns, MCP for latest facts)
5. Generate diagrams via `draw-io` / `diagram-design` skills, embed inline
6. Cite doc URLs; record which skills + MCP sources were used in the Change Log

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

## Official Scope — AWS Security, Identity & Compliance Services (34)

Our security study scope is bounded to the **34 services** listed on the official AWS Security, Identity, and Compliance products page ([aws.amazon.com/products/security](https://aws.amazon.com/products/security/)), grouped into the 5 AWS categories. These are the services we create deep-dive study notes for.

> Source: AWS Security, Identity, and Compliance products catalog + the AWS Overview whitepaper ([Security services](https://docs.aws.amazon.com/whitepapers/latest/aws-overview/security-services.html)). Content was rephrased for compliance with licensing restrictions.

### Category 1: Identity & Access Management
1. AWS Identity and Access Management (IAM)
2. AWS IAM Identity Center
3. Amazon Cognito
4. Amazon Verified Permissions
5. AWS Directory Service
6. AWS Resource Access Manager (RAM)
7. AWS Organizations

### Category 2: Detection & Response
8. Amazon GuardDuty
9. Amazon Inspector
10. AWS Security Hub (CSPM)
11. Amazon Detective
12. AWS Security Incident Response
13. Amazon Security Lake
14. AWS Config
15. AWS CloudTrail
16. Amazon CloudWatch

### Category 3: Network & Application Protection
17. AWS Network Firewall
18. AWS WAF
19. AWS Shield
20. AWS Firewall Manager
21. AWS Verified Access
22. Amazon VPC (security features: SGs, NACLs, endpoints, PrivateLink)
23. Amazon Route 53 Resolver DNS Firewall

### Category 4: Data Protection
24. AWS Key Management Service (KMS)
25. AWS CloudHSM
26. AWS Certificate Manager (ACM)
27. AWS Private Certificate Authority (AWS Private CA)
28. AWS Secrets Manager
29. Amazon Macie
30. AWS Payment Cryptography
31. AWS Backup

### Category 5: Compliance & Governance
32. AWS Artifact
33. AWS Audit Manager
34. AWS Control Tower

### Scope Notes
- This 34-service list is the **authoritative study scope**. New deep-dive notes should target services from this list.
- A few services already in our priority list (e.g., Systems Manager, Bedrock, SageMaker) are studied as supporting/adjacent topics for specific exam domains but are not part of the core 34 security-products scope.
- When the AWS products page changes, run `@release-tracker` and reconcile this list.

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

**This document drives all exam study content creation. Every note must follow the template, use MCP servers for accuracy, be a single all-in-one `.html` file per service with diagrams embedded inline, and use the diagram tooling (`@diagram-creator` / `draw-io` / `diagram-design`) for all non-trivial diagrams.**
