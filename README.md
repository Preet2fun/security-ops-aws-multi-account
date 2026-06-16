# AWS Security Operations — Exam Study & SaaS Platform Security

## Two Objectives, One Repository

This repository serves two distinct purposes:

| # | Objective | Folder | Focus |
|---|-----------|--------|-------|
| 1 | **Exam Study** | [`/exam-study/`](./exam-study/) | Deep-dive theoretical notes for AWS Security Specialty (SCS-C03) |
| 2 | **SaaS Security** | [`/saas-security/`](./saas-security/) | Practical defense-in-depth implementation for multi-tenant ITOM/ITSM platform |

---

## Objective 1: AWS Security Specialty (SCS-C03) Exam Study

Comprehensive study notes for all 7 exam domains, created from official AWS documentation (via MCP servers). Each service note covers:

- Service introduction and significance
- Behind-the-scenes technical flow (single-account & multi-account)
- Step-by-step configuration with significance of each setting
- Threat mitigation coverage (app-level vs infra-level)
- Defense-in-depth positioning and Well-Architected alignment
- Exam-critical points and common question patterns

**→ See [`exam-study/README.md`](./exam-study/README.md) for study plan and progress tracker**

---

## Objective 2: SaaS Security Platform Implementation

Production-grade security architecture for a multi-tenant SaaS platform (ITOM & ITSM) on AWS. Uses spec-driven development (Kiro) to produce:

- Manual AWS Console configuration guides
- CloudFormation templates
- Terraform modules
- Deployment and validation scripts

Covers 35 security specs across 11 phases (foundation → identity → network → data → detection → logging → containers → API → incident response → compliance → DR).

**→ See [`saas-security/README.md`](./saas-security/README.md) for architecture and progress**
**→ See [`saas-security/specs-todo.md`](./saas-security/specs-todo.md) for implementation checklist**

---

## Repository Structure

```
.
├── README.md                          ← You are here
├── exam-study/                        # OBJECTIVE 1: Exam preparation
│   ├── README.md                      # Study plan and progress tracker
│   ├── aws-services/                  # Deep-dive per AWS security service
│   ├── exam-domain-mapping/           # Content mapped to 7 exam domains
│   ├── scenario-based-examples/       # Real-world exam scenarios
│   ├── service-comparison-matrices/   # Side-by-side comparisons
│   └── exam-tips/                     # Strategies and patterns
├── saas-security/                     # OBJECTIVE 2: Platform security
│   ├── README.md                      # Architecture overview
│   ├── specs-todo.md                  # Master checklist (35 specs)
│   ├── architecture/                  # Security architecture docs
│   ├── implementation/
│   │   ├── manual-configuration/      # AWS Console step-by-step guides
│   │   └── automation/
│   │       ├── cloudformation/        # CFn templates by layer
│   │       ├── terraform/             # TF modules by layer
│   │       └── scripts/               # Deploy/validate/cleanup
│   ├── security-operations/           # Playbooks, automation, monitoring
│   ├── policies/                      # IAM, SCP, RCP, resource policies
│   └── compliance/                    # SOC2, ISO27001, GDPR frameworks
└── .kiro/
    ├── specs/                         # Kiro spec-driven development
    └── steering/                      # 2 steering docs (exam + saas)
```

## Steering Documents

| File | Drives |
|------|--------|
| `.kiro/steering/exam-study-guide.md` | Exam study note creation — template, MCP usage, domain mapping |
| `.kiro/steering/saas-security-implementation.md` | SaaS security implementation — spec methodology, defense-in-depth model |

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

## Getting Started

1. **For exam study:** Start with [`exam-study/README.md`](./exam-study/README.md) — pick a service, request a deep-dive note
2. **For SaaS security:** Start with [`saas-security/specs-todo.md`](./saas-security/specs-todo.md) — pick a spec, create via Kiro

---

*All content sourced from official AWS documentation via AWS Knowledge and Documentation MCP servers.*
