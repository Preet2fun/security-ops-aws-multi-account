# Workflow — Generating a Control Plane Diagram

A step-by-step loop with CP examples. This expands `SKILL.md` §2. Authoritative rules live in
`vendor/SKILL.md`; this file is the practical path.

---

## The loop

```
0. Brand gate (first diagram only)
1. Decide: is a diagram the right output?
2. Pick semantic pattern (if behavior matters) → visual type
3. Load the vendor type spec
4. State the plan; confirm with the user
5. Copy a template, draw the SVG
6. Run the taste gate + self_check.py
7. Save to the right location
```

---

## Step 0 — Brand gate (first run in repo)

Check repo root for a `.diagram-design` marker. If absent and the style guide is still shipped
default, ask the user whether to brand (URL / paste / profile / default). See
`project-context.md` §3 and `vendor/references/onboarding.md`. Skip on later runs.

## Step 1 — Is a diagram right?

Would a paragraph or table do the job? If yes, write that. A diagram earns its place only when the
spatial/relational structure is the point.

## Step 2 — Pattern, then type

If the meaning is behavioral (queue depth, enforcement, state, risk propagation, paired traces),
open `vendor/references/semantic-patterns.md` and pick one primary pattern first. Then pick the
nearest visual type using `diagram-type-index.md`. If it's a plain layout, pick the type directly.

## Step 3 — Load the type spec

Open the matching `vendor/references/type-*.md`. It owns the layout grammar, per-type budget, and
type-specific anti-patterns. Do not draw from memory.

## Step 4 — State the plan

One short message: `type` (+ `pattern` if any), `size preset`, and any nodes the complexity budget
forces out. Let the user redirect. Only skip when the request already fully pins type/size/content.

## Step 5 — Draw

Copy the closest template from `vendor/assets/` (`template.html` default, `template-dark.html`,
`template-full.html`, `template-motion.html` for motion). Replace eyebrow / `<h1>` / SVG body;
fill `<title>` and `<desc>` with slug-prefixed IDs. Apply CP color conventions
(`project-context.md` §2). Obey the six connector rules and the 4px grid.

## Step 6 — Taste gate + self-check

Run `vendor/SKILL.md` §9 checklist and `SKILL.md` §5 CP checklist. Then:

```sh
python3 .kiro/skills/diagram-design/vendor/scripts/self_check.py <output.html>
```

Fix anything it flags before showing the result.

## Step 7 — Save

Per `project-context.md` §5. Export only on request.

---

## Worked example A — CUSTOM_AUTH OTP sequence

1. Behavioral (ordered messages between actors) → **Sequence** type, no special semantic pattern.
2. Load `vendor/references/type-sequence.md`.
3. Plan: "Sequence, `doc-inline`, 5 lifelines: Client, API Gateway, Cognito, Auth Lambda (triggers),
   SES. DynamoDB OTPStore shown as a note/store. Budget forces merging the three triggers into one
   'Auth Lambda' lifeline with labeled activations." Confirm.
4. Template `template.html`; lifelines ≤5; OTP value never shown literally (use `<OTP>`), matching
   the passwordless guardrail.
5. Taste gate + self_check.
6. Save beside the auth spec's `design.md`, or `docs/frontend-integration/...` if it's for frontend.

## Worked example B — VPC deployment (private Lambda, NAT, endpoints)

1. Spatial "where it runs" → **Deployment** type. Load `type-deployment.md`.
2. Plan: "Deployment, `doc-wide`. Two zones: public subnet (NAT GW, EC2 observability) and private
   subnet (Lambda ENIs, gateway + interface endpoints). Focal = the private subnet." Confirm.
3. Draw zones as dashed boundary rects; Lambda strictly inside private; NAT strictly inside public;
   0.0.0.0/0 → NAT edge from private, → IGW edge from public. Honors vpc-networking-standards.
4. Taste gate + self_check; save to `platform-reports/architecture/diagrams/`.

## Worked example C — Redraw a Mermaid diagram from a spec

1. Source is `.mmd` → import path. Extract:
   `python3 .kiro/skills/diagram-design/vendor/scripts/mermaid_extract.py flow.mmd`
2. Set dials: `format=html`, `size=doc-inline`, `detail=balanced`, `audience=mixed`
   (`vendor/references/output-spec.md`).
3. Redraw editorially — keep components/relationships/direction, discard Mermaid's coordinates,
   colors, fonts. Never invent or silently drop a node.
4. Report the fidelity ledger (merged/collapsed/dropped). Taste gate + self_check; save.

---

## Common mistakes to avoid

- Rendering an import 1:1 (imports Mermaid's auto-layout — a universal anti-pattern).
- Coral on more than two nodes.
- Diagonal connectors between off-axis nodes.
- Drawing boxes before arrows (z-order wrong).
- Hardcoding a single environment when the diagram is meant to be env-agnostic.
- Showing literal OTP/token/email values.
- Editing files under `vendor/` (breaks the pristine upstream mirror — adapt in this folder instead).
