# AWS Security Operations — Exam Study & SaaS Platform Security

## Two Objectives, One Repository

| # | Objective | Folder | Focus |
|---|-----------|--------|-------|
| 1 | **Exam Study** | `exam-study/` | Deep-dive study notes for AWS Security Specialty (SCS-C03) |
| 2 | **SaaS Security** | `saas-security/` | Defense-in-depth implementation for multi-tenant ITOM/ITSM platform |

---

## Repository Structure

```
security-operation/
├── README.md                  ← You are here
├── .kiro/
│   ├── agents/                # 4 custom agents (see below)
│   ├── steering/              # 2 steering docs (exam + saas)
│   └── specs/                 # Kiro specs per service
├── exam-study/                # Objective 1: one file per service
│   ├── README.md
│   ├── cloudfront.md
│   ├── vpc.md
│   ├── organizations.md
│   └── domain-revision/       # Cross-service exam domain sheets
├── saas-security/             # Objective 2: one folder per service
│   ├── README.md
│   ├── specs-todo.md
│   ├── architecture.md
│   └── organizations/         # guide.md + Terraform + CFn + scripts
└── aws-updates/               # Weekly AWS security release digests
    └── README.md
```

---

## Custom Agents

| Agent | Trigger | What It Produces |
|-------|---------|-----------------|
| `@service-deep-dive` | `@service-deep-dive {service}` | All-in-one exam study file in `exam-study/` |
| `@security-architect` | `@security-architect {service}` | Kiro spec + HLD/LLD + manual guide + IaC in `saas-security/` |
| `@release-tracker` | `@release-tracker` | Weekly digest in `aws-updates/` + stale content flags |
| `@content-updater` | `@content-updater {service}` | Refreshes existing files with latest AWS documentation |

---

## Workflow

### Learning a new service (exam prep)
```
@service-deep-dive GuardDuty
→ Creates exam-study/guardduty.md (internals, config, threats, use-cases, exam tips)
```

### Implementing a service (platform security)
```
@security-architect WAF
→ Creates .kiro/specs/waf/ (requirements, design, tasks)
→ Creates saas-security/waf/ (guide.md, main.tf, template.yaml, scripts/)
```

### Keeping content fresh
```
@release-tracker
→ Creates aws-updates/2025-week-32.md (categorized releases)
→ Flags stale files with <!-- STALE: ... --> comments

@content-updater cloudfront
→ Updates exam-study/cloudfront.md with latest AWS docs
→ Removes STALE flags, adds Change Log entry
```

---

## Platform Architecture (SaaS Security Context)

```
┌─────────────────── AWS Organizations ───────────────────┐
│ Management Acct │ Audit Acct │ Logging Acct │ Workload  │
└─────────────────────────────────────────────────────────┘
                        Workload Account:
    Internet → Route53 → CloudFront → API GW → NLB → EKS → RDS
                              ↓
                  Security Services Layer
             (WAF, Shield, GuardDuty, Config, etc.)
```

---

## Getting Started

1. **For exam study**: Run `@service-deep-dive {service}` to create study material
2. **For platform security**: Run `@security-architect {service}` to design and implement
3. **For freshness**: Run `@release-tracker` weekly to stay current

See individual folder READMEs for more detail:
- [`exam-study/README.md`](./exam-study/README.md)
- [`saas-security/README.md`](./saas-security/README.md)
- [`aws-updates/README.md`](./aws-updates/README.md)

---

## Steering Documents

| File | Drives |
|------|--------|
| `.kiro/steering/exam-study-guide.md` | Exam study note template, MCP usage, domain mapping |
| `.kiro/steering/saas-security-implementation.md` | SaaS implementation methodology, defense-in-depth model |

---

*All content sourced from official AWS documentation via MCP servers.*
