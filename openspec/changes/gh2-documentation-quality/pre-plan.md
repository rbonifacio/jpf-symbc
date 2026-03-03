# Pre-Plan: gh2 — Documentation, Dead Code Cleanup & Quality Improvement

## Context

After completing gh1 (Ant → Maven multi-module + Java 8 → 11 migration), the codebase has a new structure with 5 Maven modules, but the knowledge graph (Neo4j) is stale (reflects the old Ant layout), there is no architecture documentation, Javadocs are sparse, and dead code has never been systematically identified. This change addresses these gaps.

**Current state (post-gh1):**
- Build: Maven multi-module (5 modules)
- Java: 11
- Neo4j graph: STALE — 773 units from old Ant structure, paths no longer valid
- Architecture docs: None (only CLAUDE.md and README.md)
- Javadocs: Sparse — most classes lack or have minimal Javadoc comments
- Dead code: Never assessed

**File counts:**

| Module | Java Files | Notes |
|--------|-----------|-------|
| jpf-symbc-annotations | 4 | Tiny, quick to document |
| jpf-symbc-main | 342 | Core implementation — largest module |
| jpf-symbc-classes | 9 | Model classes for JPF runtime |
| jpf-symbc-tests | 197 | Test files (doc optional) |
| jpf-symbc-examples | 213 | Example programs (doc optional) |
| **Total** | **766** | |

**Core packages in jpf-symbc-main (priority targets):**

| Package | Files | Sub-packages |
|---------|-------|-------------|
| `symbc/` (root) | 13 | SymbolicListener, SymbolicInstructionFactory, etc. |
| `symbc/bytecode/` | 140 | 102 root + 17 optimization + 2 util + 19 symarrays |
| `symbc/numeric/` | 53 | 30 root + 22 solvers + 1 visitors |
| `symbc/string/` | 87 | 27 root + 30 graph + 26 translate + 4 testing |
| `symbc/heap/` | 5 | Lazy initialization |
| `symbc/arrays/` | 9 | Symbolic arrays |
| `symbc/concolic/` | 6 | Hybrid execution |
| `symbc/sequences/` | 2 | Sequence testing |
| `symbc/tree/` + `symbc/tree/visualizer/` | 3 + 3 = 6 | Tree structures + DOT visualization |
| Other (mixednumstrg, abstraction) | 3 + 2 = 5 | Minor packages |
| `edu/ucsb/cs/vlab/` + `vlab/cs/ucsb/edu/` | 16 | Z3 string solver integration (non-symbc packages) |

---

## Objectives

1. **Re-populate Neo4j** with the new Maven multi-module structure
2. **Remove dead code** identified by analysis (clean before documenting)
3. **Generate architecture documentation** (Views & Beyond, ADRs, NFR mapping)
4. **Add Javadocs + inline comments** to core packages (priority-based)
5. **Update project-level docs** (README, CLAUDE.md)
6. **Verify quality** (lint, tests, doc freshness)

---

## Scope

**In scope:**
- Neo4j graph reset and re-extraction
- Architectural analysis (full, using Neo4j)
- Dead code detection and removal (with user approval)
- Architecture documentation (Views & Beyond methodology)
- 2 ADRs: Ant→Maven migration, Java 8→11 upgrade
- NFR mapping to architecture
- Javadocs for core packages in jpf-symbc-main (342 files)
- Javadocs for jpf-symbc-annotations (4 files) and jpf-symbc-classes (9 files)
- README and CLAUDE.md updates
- Documentation freshness verification
- Lint check and auto-fix
- Full verification (tests + lint + complexity)
- Code review of all changes

**Out of scope:**
- Javadocs for test files (jpf-symbc-tests, 197 files) — document tests if time permits
- Javadocs for example programs (jpf-symbc-examples, 213 files) — document if time permits
- Security analysis (separate concern)
- Feature implementation (no new features)
- Refactoring (no structural changes beyond dead code removal)
- Release preparation

---

## Prerequisites

- gh1 complete and merged (Maven multi-module + Java 11 working)
- Docker running (Neo4j container)
- SDD Toolkit MCP server running
- `mvn test` passing (20 tests)

---

## OpenSpec Track

**Full SDD** — multi-module scope, requires design decisions for documentation strategy, dead code approval, batching strategy.

**Change name:** `gh2-documentation-quality`

---

## Subagent Orchestration Strategy

### Design Principle: Clean Main Context

The main conversation context **SHALL NOT** run skills directly. Instead, it acts as an **orchestrator** that:
1. Dispatches subagents (via Agent tool) for each task group
2. Collects summarized results
3. Makes decisions based on results
4. Dispatches the next wave

This keeps the main context window clean and avoids accumulating tool call results from 37+ skill invocations.

### Subagent Constraints (from hello-claude-code validation)

```
Main context → Agent(subagent)              ✓ works
Main context → Agent(subagent) × 3 parallel ✓ works (up to 3-4 concurrent)
Subagent → Skill(sdd-architect)             ✓ works (Skill tool available in subagents)
Subagent → Skill(A) → Skill(B)             ✓ works (skills chain via Skill tool, up to 5 levels)
Subagent → Agent(nested-subagent)           ✗ FAILS (Task tool absent from subagents)
```

### Context Window Budget Per Subagent

- Each subagent gets its own ~200K token context window; practical safe limit: ~100K tokens of accumulated tool results
- For `sdd-doc-code`: each Java file (read + classify + edit) ≈ 1500-3000 tokens
- **Max files per subagent: ~25-30** (to stay within safe limit)
- For composite skills (sdd-architect): the skill manages its own internal chain — safe as single subagent

### Parallelism Rules

- **Max 3 parallel subagents** per wave (empirically safe, avoids rate limiting)
- Independent tasks in the same phase → parallelize
- Dependent tasks → sequential dispatch
- After each wave: main context reviews results before dispatching next wave

### Subagent Prompt Template

Each subagent receives a focused prompt:
```
You are working on jpf-symbc (Java Symbolic PathFinder).
Project root: /pedro/desenvolvimento/workspaces/.../jpf-symbc

TASK: Run `/sdd-doc-code` on [specific path].
Generate Javadoc comments for all Java classes in that directory.
Do NOT process subdirectories (those are handled by separate subagents).

After completion, report:
- Files processed (count)
- Files modified (count)
- Files skipped (count, with reasons)
- Any issues encountered
```

---

## Skill Selection & Execution Order

### Phase 0: Infrastructure Reset

**Execution: INLINE** (MCP tools are quick, no skill invocation needed)

| Step | Tool/Skill | Purpose |
|------|-----------|---------|
| 0.1 | `mcp__sdd__clear_project("jpf-symbc")` | Clear stale Neo4j data |
| 0.2 | `mcp__sdd__init_schema()` | Reinitialize schema |

**Then dispatch subagent:**

| Step | Subagent | Skill | Files | Purpose |
|------|----------|-------|-------|---------|
| 0.3 | **Subagent A0** | `/sdd-extract` | all | Re-extract project with new Maven paths |

**Output:** Fresh Neo4j graph with ~766 Java files across 5 Maven modules.

### Phase 1: Architectural Analysis

**Execution: 1 SUBAGENT** (sdd-architect is a composite that internally chains 4 analysis skills)

| Step | Subagent | Skill | Purpose |
|------|----------|-------|---------|
| 1.1 | **Subagent A1** | `/sdd-architect` | Full architectural analysis |

Internally invokes (via Skill tool, inside the subagent):
- `sdd-analyze-module` → `sdd-analyze-dependencies` → `sdd-analyze-complexity` → `sdd-impact-analyzer`

**Output:** Architectural report (module layers, dependency graph, complexity hotspots, patterns, risk areas).

### Phase 2: Dead Code Cleanup

**Execution: 3-STEP with user interaction (component skills, NOT sdd-cleanup orchestrator)**

The `sdd-cleanup` orchestrator is restricted in Full SDD workflows. Instead, we use component skills directly: `/sdd-analyze-dead-code` for detection, then manual orchestration of approval/removal/verification.

| Step | Subagent | Skill | Purpose |
|------|----------|-------|---------|
| 2.1 | **Subagent A2a** | `/sdd-analyze-dead-code` | Detect dead code candidates (read-only) |
| 2.2 | Main context | (none) | Present candidates to user for approval |
| 2.3 | **Subagent A2b** | Manual removal + `/sdd-test-run` | Remove approved candidates, verify tests pass |

**Then re-extract:**

| Step | Subagent | Skill | Purpose |
|------|----------|-------|---------|
| 2.4 | **Subagent A3** | `/sdd-extract` | Refresh graph after code removal |

### Phase 3: Architecture Documentation

**Execution: 3 SUBAGENTS IN PARALLEL** (doc-architecture, ADRs, and NFR are independent once the graph is fresh)

**Wave 3.1 — parallel:**

| Step | Subagent | Skill | Purpose |
|------|----------|-------|---------|
| 3.1 | **Subagent B1** | `/sdd-doc-architecture` | Generate Views & Beyond docs |
| 3.2 | **Subagent B2** | `/sdd-doc-adr "Ant to Maven migration"` + `/sdd-doc-adr "Java 8 to 11 upgrade"` | Both ADRs (sequential within subagent) |
| 3.3 | **Subagent B3** | `/sdd-doc-nfr` | NFR mapping |

**Output:**
- `docs/architecture/` — module, C&C, allocation views
- `docs/adr/0001-ant-to-maven-migration.md`
- `docs/adr/0002-java-8-to-11-upgrade.md`
- `docs/nfr-mapping.md`

### Phase 4: Code Documentation (Javadocs)

**Execution: 5 WAVES of 2-3 PARALLEL SUBAGENTS each**

Max 30 files per subagent. Each subagent runs `/sdd-doc-code [path]` on a single directory (non-recursive).

**Wave 4.1 — Root + small modules (3 parallel subagents):**

| Subagent | Target | Files |
|----------|--------|-------|
| **C1** | `jpf-symbc-main/.../symbc/` (root only) | 13 |
| **C2** | `jpf-symbc-annotations/` (4) + `jpf-symbc-classes/src/main/java/` (5) + `jpf-symbc-classes/src/main/modules/` (4) | 13 |
| **C3** | `symbc/numeric/` (root only, not solvers/) | 30 |

**Wave 4.2 — Numeric + small packages (3 parallel subagents):**

| Subagent | Target | Files |
|----------|--------|-------|
| **C4** | `symbc/numeric/solvers/` + `symbc/numeric/visitors/` | 22 + 1 = 23 |
| **C5** | `symbc/heap/` + `symbc/arrays/` + `symbc/concolic/` + `symbc/sequences/` | 5 + 9 + 6 + 2 = 22 |
| **C6** | `symbc/tree/` (3) + `symbc/tree/visualizer/` (3) + `symbc/mixednumstrg/` (3) + `symbc/abstraction/` (2) + `edu/ucsb/cs/vlab/` + `vlab/cs/ucsb/edu/` (16) | 27 |

**Wave 4.3 — Bytecode (3 parallel subagents, splitting the 102-file root):**

The bytecode root has 102 files. Split alphabetically into 4 groups.

| Subagent | Target | Files |
|----------|--------|-------|
| **C7** | `symbc/bytecode/` files A-F (alphabetical split) | ~25 |
| **C8** | `symbc/bytecode/` files G-I | ~25 |
| **C9** | `symbc/bytecode/` files IF-N | ~25 |

**Wave 4.4 — Bytecode continued (3 parallel subagents):**

| Subagent | Target | Files |
|----------|--------|-------|
| **C10** | `symbc/bytecode/` files O-Z (remaining root) | ~27 |
| **C11** | `symbc/bytecode/optimization/` + `symbc/bytecode/optimization/util/` | 17 + 2 = 19 |
| **C12** | `symbc/bytecode/symarrays/` | 19 |

**Wave 4.5 — String (3 parallel subagents):**

| Subagent | Target | Files |
|----------|--------|-------|
| **C13** | `symbc/string/` (root only) | 27 |
| **C14** | `symbc/string/graph/` | 30 |
| **C15** | `symbc/string/translate/` + `symbc/string/testing/` | 26 + 4 = 30 |

**Phase 4 totals:**
- 5 waves × 3 subagents = **15 subagent invocations**
- ~355 files total
- Max 30 files per subagent
- All subagents within a wave are **independent** (different packages, no shared files)

### Phase 5: Project-Level Documentation

**Execution: 2 SEQUENTIAL SUBAGENTS** (CLAUDE.md depends on README content)

| Step | Subagent | Skill | Purpose |
|------|----------|-------|---------|
| 5.1 | **Subagent D1** | `/sdd-doc-readme` | Update README.md |
| 5.2 | **Subagent D2** | `/sdd-doc-generate-claude-md` | Refresh CLAUDE.md |

### Phase 6: Quality & Verification

**Execution: 2 SEQUENTIAL SUBAGENTS** (lint-fix depends on lint results, verify depends on fixes)

| Step | Subagent | Skill | Purpose |
|------|----------|-------|---------|
| 6.1 | **Subagent E1** | `/sdd-docs-sync` + `/sdd-qa-lint` | Check doc freshness + lint issues |
| 6.2 | **Subagent E2** | `/sdd-qa-lint-fix` + `/sdd-verify` + `/sdd-test-run` | Fix lint + full verification |

### Phase 7: Code Review

**Execution: 1 SUBAGENT**

| Step | Subagent | Skill | Purpose |
|------|----------|-------|---------|
| 7.1 | **Subagent F1** | `/sdd-code-reviewer` | Multi-dimension review of all changes |

---

## Subagent Summary

| Phase | Subagents | Parallel? | Total Agents |
|-------|-----------|-----------|-------------|
| 0 | A0 | no | 1 |
| 1 | A1 | no | 1 |
| 2 | A2a, A2b, A3 | sequential | 3 |
| 3 | B1, B2, B3 | **yes (3 parallel)** | 3 |
| 4 | C1-C15 (5 waves × 3) | **yes (3 parallel per wave)** | 15 |
| 5 | D1, D2 | sequential | 2 |
| 6 | E1, E2 | sequential | 2 |
| 7 | F1 | no | 1 |
| **Total** | | | **28 subagent invocations** |

**Main context role:** Dispatch subagents, collect results, make go/no-go decisions between phases.

---

## tasks.md Annotation Convention

Each task in the OpenSpec `tasks.md` will be annotated with its subagent strategy using HTML comments:

```markdown
### Task Group 4.3: Bytecode Root Documentation (Wave 4.3)

<!-- Subagent dispatch: 3 parallel subagents
     C7: bytecode/ files A-F (~25 files)
     C8: bytecode/ files G-I (~25 files)
     C9: bytecode/ files IF-N (~25 files)
     All independent — no shared files.
     Max files per subagent: 30. -->

- [ ] **4.3.1** — Subagent C7: Run `/sdd-doc-code` on `symbc/bytecode/` files A-F
- [ ] **4.3.2** — Subagent C8: Run `/sdd-doc-code` on `symbc/bytecode/` files G-I
- [ ] **4.3.3** — Subagent C9: Run `/sdd-doc-code` on `symbc/bytecode/` files IF-N
- [ ] Checkpoint: verify `mvn compile` still passes after wave 4.3
```

Each task that runs in a subagent will be prefixed with **"Subagent XX:"** to make the delegation explicit.

---

## Dependency Graph

```
Phase 0         Phase 1       Phase 2         Phase 3              Phase 4                Phase 5       Phase 6       Phase 7
┌─────────┐  ┌───────────┐  ┌───────────┐  ┌───────────────────┐  ┌──────────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ A0:     │  │ A1:       │  │ A2a+A2b:  │  │ B1: doc-arch      │  │ Wave 4.1:        │  │ D1:      │  │ E1:      │  │ F1:      │
│ extract │─▶│ architect │─▶│ dead code │─▶│ B2: doc-adr ×2    │─▶│  C1,C2,C3 ∥     │─▶│ readme   │─▶│ sync+    │─▶│ code-    │
│         │  │           │  │           │  │ B3: doc-nfr       │  │ Wave 4.2:        │  │          │  │ lint     │  │ reviewer │
│         │  │           │  │ A3:       │  │ (3 parallel)      │  │  C4,C5,C6 ∥     │  │ D2:      │  │          │  │          │
│         │  │           │  │ re-extract│  │                   │  │ Wave 4.3:        │  │ claude-md│  │ E2:      │  │          │
│         │  │           │  │           │  │                   │  │  C7,C8,C9 ∥     │  │          │  │ lint-fix+│  │          │
│         │  │           │  │           │  │                   │  │ Wave 4.4:        │  │          │  │ verify   │  │          │
│         │  │           │  │           │  │                   │  │  C10,C11,C12 ∥  │  │          │  │          │  │          │
│         │  │           │  │           │  │                   │  │ Wave 4.5:        │  │          │  │          │  │          │
│         │  │           │  │           │  │                   │  │  C13,C14,C15 ∥  │  │          │  │          │  │          │
└─────────┘  └───────────┘  └───────────┘  └───────────────────┘  └──────────────────┘  └──────────┘  └──────────┘  └──────────┘
   1 agent     1 agent       3 agents       3 agents (parallel)    15 agents (5 waves)   2 agents      2 agents      1 agent
                                                                     3 parallel/wave
```

**Critical path:** A0 → A1 → A2a → (user approval) → A2b → A3 → B1-B3 → C1-C15 → D1 → D2 → E1 → E2 → F1

---

## Skill Inventory (All Skills Used)

| # | Skill | Tier | Invocations | Subagent Pattern |
|---|-------|------|------------|-----------------|
| 1 | `sdd-extract` | T3 | 2 | 1 subagent each (A0, A3) |
| 2 | `sdd-architect` | T1 composite | 1 | 1 subagent (A1) — internally chains 4 skills |
| 3 | `sdd-analyze-dead-code` | T2 analysis | 1 | 1 subagent (A2a) — detection only; approval + removal orchestrated manually |
| 4 | `sdd-doc-architecture` | T3 | 1 | 1 subagent (B1) |
| 5 | `sdd-doc-adr` | T3 | 2 | 1 subagent (B2) — runs both ADRs sequentially |
| 6 | `sdd-doc-nfr` | T3 | 1 | 1 subagent (B3) |
| 7 | `sdd-doc-code` | T3 | 15 | 15 subagents (C1-C15) — 5 waves of 3 parallel |
| 8 | `sdd-doc-readme` | T3 | 1 | 1 subagent (D1) |
| 9 | `sdd-doc-generate-claude-md` | T3 | 1 | 1 subagent (D2) |
| 10 | `sdd-docs-sync` | T3 | 1 | shared subagent (E1) |
| 11 | `sdd-qa-lint` | T3 | 1 | shared subagent (E1) |
| 12 | `sdd-qa-lint-fix` | T3 | 1 | shared subagent (E2) |
| 13 | `sdd-verify` | T1 composite | 1 | shared subagent (E2) |
| 14 | `sdd-test-run` | T3 | 1 | shared subagent (E2) |
| 15 | `sdd-code-reviewer` | T1 composite | 1 | 1 subagent (F1) |

**Total: 15 distinct skills, ~31 invocations, 28 subagent dispatches**

Skills invoked INTERNALLY by composites (inside subagent context, via Skill tool):
- `sdd-analyze-module` — by sdd-architect (A1)
- `sdd-analyze-dependencies` — by sdd-architect (A1), sdd-code-reviewer (F1)
- `sdd-analyze-complexity` — by sdd-architect (A1), sdd-code-reviewer (F1)
- `sdd-impact-analyzer` — by sdd-architect (A1)
- `sdd-test-run` — by A2b (post-removal verification)
- `sdd-analyze-file` — by sdd-code-reviewer (F1)
- `sdd-detection` — by sdd-verify (E2), sdd-doc-code (C1-C15), sdd-qa-lint (E1)
- `sdd-config-reader` — by sdd-verify (E2)

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Subagent context overflow on large batches | Medium | Medium | Max 30 files/subagent; bytecode root split into 4 groups |
| sdd-doc-code generates low-quality Javadocs | Medium | Medium | Review each wave; iterate on prompt refinement |
| Dead code cleanup removes needed code | Low | High | User approval before deletion; sdd-test-run catches regressions |
| Neo4j re-extraction fails on new paths | Low | High | Verify extract output; fallback to Minimal mode |
| Parallel subagents create file conflicts | Low | Medium | Each subagent targets different directories — no overlap |
| Lint fixes introduce formatting issues | Low | Low | sdd-verify catches regressions after fix |
| sdd-architect overflows context (4 chained skills) | Low | Medium | Single module project; architect handles this scale |
| Main context accumulates too much result text | Low | Low | Subagent results are summarized by Agent tool |

---

## Deliverables

| Deliverable | Location | Phase | Subagent |
|-------------|----------|-------|----------|
| Fresh Neo4j graph | Neo4j database | 0 | A0 |
| Architectural analysis report | (console output → informs docs) | 1 | A1 |
| Dead code removal | Modified source files | 2 | A2 |
| Architecture views | `docs/architecture/` | 3 | B1 |
| ADR-0001: Ant→Maven | `docs/adr/0001-*.md` | 3 | B2 |
| ADR-0002: Java 8→11 | `docs/adr/0002-*.md` | 3 | B2 |
| NFR mapping | `docs/nfr-mapping.md` | 3 | B3 |
| Javadocs (core packages) | Modified `.java` files (~355 files) | 4 | C1-C15 |
| Updated README | `README.md` | 5 | D1 |
| Updated CLAUDE.md | `CLAUDE.md` | 5 | D2 |
| Doc freshness + lint report | (console output) | 6 | E1 |
| Verification report | (console output) | 6 | E2 |
| Code review report | (console output) | 7 | F1 |

---

## Session Estimate

| Phase | Sessions | Subagents/session | Notes |
|-------|---------|-------------------|-------|
| 0+1 | 1 | A0 → A1 | Extract + architect |
| 2 | 1 | A2 → A3 | Cleanup (user approval) + re-extract |
| 3 | 1 | B1, B2, B3 (parallel) | Architecture docs |
| 4 waves 1-2 | 1 | C1-C6 (2 waves × 3 parallel) | Root + numeric + small packages |
| 4 waves 3-4 | 1 | C7-C12 (2 waves × 3 parallel) | Bytecode |
| 4 wave 5 | 1 | C13-C15 (1 wave × 3 parallel) | String |
| 5+6+7 | 1 | D1 → D2 → E1 → E2 → F1 | Project docs + verify + review |

**Total estimate: 7 sessions** (reduced from 9-11 via parallelism)

---

## Next Steps

1. Create GitHub Issue #2
2. Create OpenSpec change: `/opsx:new` → `gh2-documentation-quality`
3. Generate artifacts: proposal, specs, design, tasks (with subagent annotations)
4. Begin implementation: `/opsx:apply`
