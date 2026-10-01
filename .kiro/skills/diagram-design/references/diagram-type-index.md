# Diagram Type Index (40 types)

Fast lookup from intent → visual type → vendored layout spec. Load the linked
`vendor/references/type-*.md` **before** drawing. When behavior carries the meaning, first pick a
semantic pattern from `vendor/references/semantic-patterns.md`, then the type here.

Paths are relative to this skill root (`.kiro/skills/diagram-design/`).

---

## Most used for the Control Plane

| Show this | Type | Spec |
|-----------|------|------|
| Components + connections in a system | Architecture | [vendor/references/type-architecture.md](../vendor/references/type-architecture.md) |
| End-to-end stack / hero infra | High-Level | [vendor/references/type-high-level.md](../vendor/references/type-high-level.md) |
| Time-ordered messages between actors | Sequence | [vendor/references/type-sequence.md](../vendor/references/type-sequence.md) |
| Role-scoped data flow / who does what per step | Data flow | [vendor/references/type-data-flow.md](../vendor/references/type-data-flow.md) |
| Where software runs (zones, hosts, ports, replicas) | Deployment | [vendor/references/type-deployment.md](../vendor/references/type-deployment.md) |
| States + transitions + guards | State machine | [vendor/references/type-state.md](../vendor/references/type-state.md) |
| Entities + fields + relationships | ER / data model | [vendor/references/type-er.md](../vendor/references/type-er.md) |
| Physical tables: SQL types, keys, indexes, FKs | Database schema | [vendor/references/type-db-schema.md](../vendor/references/type-db-schema.md) |
| What depends on what (fan-in, cycles) | Dependency graph | [vendor/references/type-dependency.md](../vendor/references/type-dependency.md) |
| Decision logic with branches | Flowchart | [vendor/references/type-flowchart.md](../vendor/references/type-flowchart.md) |
| Cross-functional process with handoffs | Swimlane | [vendor/references/type-swimlane.md](../vendor/references/type-swimlane.md) |
| Multi-actor sequential process with data handoffs | Process | [vendor/references/type-process.md](../vendor/references/type-process.md) |

## Structure & hierarchy

| Show this | Type | Spec |
|-----------|------|------|
| Hierarchy through containment / scope | Nested | [vendor/references/type-nested.md](../vendor/references/type-nested.md) |
| Parent → children | Tree | [vendor/references/type-tree.md](../vendor/references/type-tree.md) |
| Ownership, reporting, escalation routing | Org chart | [vendor/references/type-org-chart.md](../vendor/references/type-org-chart.md) |
| Stacked abstraction levels | Layer stack | [vendor/references/type-layers.md](../vendor/references/type-layers.md) |
| Overlap between sets | Venn | [vendor/references/type-venn.md](../vendor/references/type-venn.md) |
| Ranked hierarchy / conversion drop-off | Pyramid / funnel | [vendor/references/type-pyramid.md](../vendor/references/type-pyramid.md) |
| Reinforcing cycle / flywheel | Loop | [vendor/references/type-loop.md](../vendor/references/type-loop.md) |
| Classes: operations, inheritance, composition | UML class | [vendor/references/type-uml-class.md](../vendor/references/type-uml-class.md) |

## Time & planning

| Show this | Type | Spec |
|-----------|------|------|
| Events positioned in time | Timeline | [vendor/references/type-timeline.md](../vendor/references/type-timeline.md) |
| Tasks and phases on a timeline | Gantt | [vendor/references/type-gantt.md](../vendor/references/type-gantt.md) |
| WIP by state, with WIP limits / blocked items | Kanban | [vendor/references/type-kanban.md](../vendor/references/type-kanban.md) |
| Narrative backbone sliced into releases | Story map | [vendor/references/type-story-map.md](../vendor/references/type-story-map.md) |
| What a person does across an experience, and how it feels | User journey | [vendor/references/type-journey.md](../vendor/references/type-journey.md) |

## Quantitative charts

| Show this | Type | Spec |
|-----------|------|------|
| Comparison across categories | Bar chart | [vendor/references/type-bar.md](../vendor/references/type-bar.md) |
| Start total bridged to end total by signed deltas | Waterfall | [vendor/references/type-waterfall.md](../vendor/references/type-waterfall.md) |
| Part-of-whole where relative sizes are the story | Treemap | [vendor/references/type-treemap.md](../vendor/references/type-treemap.md) |
| Continuous trends / slopegraph / ridgeline / bump | Line chart | [vendor/references/type-line.md](../vendor/references/type-line.md) |
| Correlation between two vars (+ bubble / beeswarm) | Scatter plot | [vendor/references/type-scatter.md](../vendor/references/type-scatter.md) |
| Entities scored across 3–5 criteria | Radar / spider | [vendor/references/type-radar.md](../vendor/references/type-radar.md) |
| One series across cyclic categories (angle=category) | Polar chart | [vendor/references/type-polar.md](../vendor/references/type-polar.md) |
| Two-axis positioning / prioritization | Quadrant | [vendor/references/type-quadrant.md](../vendor/references/type-quadrant.md) |
| Quantity splitting/merging across stages (band=amount) | Sankey | [vendor/references/type-sankey.md](../vendor/references/type-sankey.md) |

## Analysis & strategy

| Show this | Type | Spec |
|-----------|------|------|
| Causes of one effect, grouped by category | Fishbone | [vendor/references/type-fishbone.md](../vendor/references/type-fishbone.md) |
| Value chain vs evolution (build/buy/move) | Wardley map | [vendor/references/type-wardley.md](../vendor/references/type-wardley.md) |

## Data-platform specific

| Show this | Type | Spec |
|-----------|------|------|
| Legacy IT landscape (the "before" state) | IT current-state | [vendor/references/type-it-state.md](../vendor/references/type-it-state.md) |
| Multi-tier storage with quality levels/policies | Medallion | [vendor/references/type-medallion.md](../vendor/references/type-medallion.md) |
| Integration topology: sources → core → consumers | DP integration | [vendor/references/type-dp-integration.md](../vendor/references/type-dp-integration.md) |
| Per-role / per-component access permissions matrix | DP security matrix | [vendor/references/type-dp-security-matrix.md](../vendor/references/type-dp-security-matrix.md) |

---

## Selection rules of thumb

- If a 3-column table communicates the same thing, use the table — not a diagram.
- If two types fit, pick the dominant axis; a semantic pattern may add behavior-specific primitives,
  not a second layout grammar.
- If you're past the type's complexity budget (`vendor/SKILL.md` §7), split into overview + detail.
- Always confirm the plan (type, size, cuts) before drawing unless the request already pins them.
