# Tasks: gh2 — Documentation, Dead Code Cleanup & Quality Improvement

<!-- Subagent dispatch hints (for /opsx:apply):

CRITICAL: Main context SHALL NOT run skills directly. All skill invocations
are delegated to subagents via the Agent tool. Main context only dispatches
subagents, collects summarized results, and makes go/no-go decisions.

Phase-to-Section mapping:
  Phase 0 = Section 0 (Infrastructure Reset)
  Phase 1 = Section 1 (Architectural Analysis)
  Phase 2 = Section 2 (Dead Code Cleanup)
  Phase 3 = Section 3 (Architecture Documentation)
  Phase 4 = Sections 4-8 (Code Documentation, 5 waves)
  Phase 5 = Section 9 (Project-Level Documentation)
  Phase 6 = Section 10 (Quality Verification)
  Phase 7 = Section 11 (Code Review)
  (none) = Section 12 (Final Verification — orchestrator only)

Phase dependencies (critical path):
  Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7

Parallelism opportunities:
  - Phase 3: B1, B2, B3 are independent → 3 parallel subagents
  - Phase 4: Each wave has 3 independent subagents → 3 parallel per wave
  - All other phases: sequential

Subagent context budget:
  - Max 30 Java files per sdd-doc-code subagent (INV-COD-01)
  - Composite skills (sdd-architect) manage internal chaining — safe as single subagent
  - Component skills for dead code (sdd-analyze-dead-code) — orchestrated manually by subagent
  - Max 3 concurrent subagents per wave
  - Context window: ~200K tokens; practical safe limit: ~100K accumulated tool results

Subagent naming convention:
  A0-A3: Infrastructure + analysis + cleanup
  B1-B3: Architecture documentation
  C1-C15: Code documentation (Javadocs)
  D1-D2: Project documentation
  E1-E2: Quality verification
  F1: Code review
-->

## 0. Infrastructure Reset

<!-- Subagent dispatch: sequential
     0.1-0.2: Inline MCP tool calls (no subagent needed — quick operations)
     0.3: Subagent A0 for sdd-extract -->

- [ ] 0.1 Clear stale Neo4j data: `mcp__sdd__clear_project("jpf-symbc")`
- [ ] 0.2 Reinitialize schema: `mcp__sdd__init_schema()`
- [ ] 0.3 **Subagent A0**: Run `/sdd-extract` on project root to re-populate Neo4j with Maven multi-module structure
- [ ] 0.4 Verify extraction: query Neo4j for 5 Maven modules with Unit nodes present (INV-KG-02)

## 1. Architectural Analysis

<!-- Subagent dispatch: 1 subagent
     A1 runs sdd-architect which internally chains:
     sdd-analyze-module → sdd-analyze-dependencies → sdd-analyze-complexity → sdd-impact-analyzer
     All via Skill tool inside the subagent context. -->

- [ ] 1.1 **Subagent A1**: Run `/sdd-architect` for comprehensive architectural analysis
- [ ] 1.2 Review A1 results: note complexity hotspots, circular dependencies, and risk areas for Phase 3 context

## 2. Dead Code Cleanup

<!-- Subagent dispatch: 3 sequential subagents (component skills, NOT sdd-cleanup orchestrator)
     A2a: sdd-analyze-dead-code (detection only — read-only analysis)
     A2b: manual removal + sdd-test-run (after user approval in main context)
     A3: sdd-extract (re-extract after code removal)
     A2a → user approval (main context) → A2b → A3 -->

- [ ] 2.1 **Subagent A2a**: Run `/sdd-analyze-dead-code` to detect dead code candidates
  - Produces candidate list classified by confidence (High/Medium/Low)
  - Applies exclusion rules: entry points (INV-DC-03), JPF native peers `JPF_*` (INV-DC-04), test files, example files
- [ ] 2.2 Review A2a results in main context: present candidates to user for approval (INV-DC-01)
  - User approves or rejects each candidate
- [ ] 2.3 **Subagent A2b**: Remove approved dead code candidates, then run `/sdd-test-run` to verify
  - Delete approved files/elements
  - Verify: `mvn test` passes after removal (INV-DC-02)
  - If test fails: revert the removal that caused the failure
- [ ] 2.4 **Subagent A3**: Run `/sdd-extract` to refresh Neo4j graph after dead code removal (INV-DC-05, INV-KG-03)
- [ ] 2.5 Verify re-extraction: query Neo4j confirms updated file count

## 3. Architecture Documentation

<!-- Subagent dispatch: 3 PARALLEL subagents
     B1: sdd-doc-architecture (writes docs/architecture/)
     B2: sdd-doc-adr × 2 (writes docs/adr/)
     B3: sdd-doc-nfr (writes docs/nfr-mapping.md)
     All independent — different output directories, no shared files.
     Neo4j is read-only during this phase. -->

- [ ] 3.1 **Subagent B1** (parallel): Run `/sdd-doc-architecture` — generate Views & Beyond docs in `docs/architecture/`
- [ ] 3.2 **Subagent B2** (parallel): Run `/sdd-doc-adr "Ant to Maven multi-module migration"` then `/sdd-doc-adr "Java 8 to Java 11 upgrade"` — generate 2 ADRs in `docs/adr/`
- [ ] 3.3 **Subagent B3** (parallel): Run `/sdd-doc-nfr` — generate NFR mapping in `docs/nfr-mapping.md`
- [ ] 3.4 Verify: all output files exist (`docs/architecture/`, `docs/adr/0001-*.md`, `docs/adr/0002-*.md`, `docs/nfr-mapping.md`)
- [ ] 3.5 Verify: ADRs contain all 12 fields (INV-ARC-03)
- [ ] 3.6 Verify: architecture views reference Maven paths, not old Ant paths (INV-ARC-04)

## 4. Code Documentation — Wave 4.1: Root + Small Modules

<!-- Subagent dispatch: 3 PARALLEL subagents
     C1: symbc/ root (13 files)
     C2: jpf-symbc-annotations (4) + jpf-symbc-classes src/main/java (5) + jpf-symbc-classes src/main/modules (4) = 13 files
     C3: symbc/numeric/ root only (30 files)
     All independent — different directories. -->

- [ ] 4.1 **Subagent C1** (parallel): Run `/sdd-doc-code` on `jpf-symbc-main/src/main/java/gov/nasa/jpf/symbc/` (root only, 13 files — SymbolicListener, SymbolicInstructionFactory, etc.)
- [ ] 4.2 **Subagent C2** (parallel): Run `/sdd-doc-code` on `jpf-symbc-annotations/src/main/java/` (4 files), then `jpf-symbc-classes/src/main/java/` (5 files), then `jpf-symbc-classes/src/main/modules/` (4 files) — 13 files total
- [ ] 4.3 **Subagent C3** (parallel): Run `/sdd-doc-code` on `jpf-symbc-main/src/main/java/gov/nasa/jpf/symbc/numeric/` (root only, 30 files — PathCondition, Expression hierarchy, constraints)
- [ ] 4.4 Checkpoint: `mvn compile` passes after wave 4.1 (INV-COD-05)

## 5. Code Documentation — Wave 4.2: Numeric Solvers + Small Packages + Non-symbc

<!-- Subagent dispatch: 3 PARALLEL subagents
     C4: numeric/solvers + numeric/visitors (22 + 1 = 23 files)
     C5: heap + arrays + concolic + sequences (5 + 9 + 6 + 2 = 22 files)
     C6: tree (3) + tree/visualizer (3) + mixednumstrg (3) + abstraction (2) + edu.ucsb/vlab (16) = 27 files
     All independent — different directories. -->

- [ ] 5.1 **Subagent C4** (parallel): Run `/sdd-doc-code` on `symbc/numeric/solvers/` (22 files) then `symbc/numeric/visitors/` (1 file)
- [ ] 5.2 **Subagent C5** (parallel): Run `/sdd-doc-code` on `symbc/heap/` (5), `symbc/arrays/` (9), `symbc/concolic/` (6), `symbc/sequences/` (2) — 22 files total
- [ ] 5.3 **Subagent C6** (parallel): Run `/sdd-doc-code` on `symbc/tree/` (3), `symbc/tree/visualizer/` (3), `symbc/mixednumstrg/` (3), `symbc/abstraction/` (2), `edu/ucsb/cs/vlab/` + `vlab/cs/ucsb/edu/` (16) — 27 files total
- [ ] 5.4 Checkpoint: `mvn compile` passes after wave 4.2 (INV-COD-05)

## 6. Code Documentation — Wave 4.3: Bytecode A-N

<!-- Subagent dispatch: 3 PARALLEL subagents
     C7: bytecode/ root files A-F (~25 files, alphabetical split)
     C8: bytecode/ root files G-I (~25 files)
     C9: bytecode/ root files IF-N (~25 files)
     All independent — different file sets within same directory. -->

- [ ] 6.1 **Subagent C7** (parallel): Run `/sdd-doc-code` on `symbc/bytecode/` files A-F alphabetically (~25 files)
- [ ] 6.2 **Subagent C8** (parallel): Run `/sdd-doc-code` on `symbc/bytecode/` files G-I alphabetically (~25 files)
- [ ] 6.3 **Subagent C9** (parallel): Run `/sdd-doc-code` on `symbc/bytecode/` files IF-N alphabetically (~25 files)
- [ ] 6.4 Checkpoint: `mvn compile` passes after wave 4.3 (INV-COD-05)

## 7. Code Documentation — Wave 4.4: Bytecode O-Z + Subpackages

<!-- Subagent dispatch: 3 PARALLEL subagents
     C10: bytecode/ root files O-Z (~27 files)
     C11: bytecode/optimization/ + bytecode/optimization/util/ (17 + 2 = 19 files)
     C12: bytecode/symarrays/ (19 files)
     All independent — different directories/file sets. -->

- [ ] 7.1 **Subagent C10** (parallel): Run `/sdd-doc-code` on `symbc/bytecode/` files O-Z alphabetically (~27 files)
- [ ] 7.2 **Subagent C11** (parallel): Run `/sdd-doc-code` on `symbc/bytecode/optimization/` (17 files) then `symbc/bytecode/optimization/util/` (2 files)
- [ ] 7.3 **Subagent C12** (parallel): Run `/sdd-doc-code` on `symbc/bytecode/symarrays/` (19 files)
- [ ] 7.4 Checkpoint: `mvn compile` passes after wave 4.4 (INV-COD-05)

## 8. Code Documentation — Wave 4.5: String Package

<!-- Subagent dispatch: 3 PARALLEL subagents
     C13: string/ root (27 files)
     C14: string/graph/ (30 files)
     C15: string/translate/ + string/testing/ (26 + 4 = 30 files)
     All independent — different directories. -->

- [ ] 8.1 **Subagent C13** (parallel): Run `/sdd-doc-code` on `symbc/string/` root (27 files — StringExpression, StringConstraint, StringPathCondition, etc.)
- [ ] 8.2 **Subagent C14** (parallel): Run `/sdd-doc-code` on `symbc/string/graph/` (30 files)
- [ ] 8.3 **Subagent C15** (parallel): Run `/sdd-doc-code` on `symbc/string/translate/` (26 files) then `symbc/string/testing/` (4 files)
- [ ] 8.4 Checkpoint: `mvn compile` passes after wave 4.5 (INV-COD-05)

## 9. Project-Level Documentation

<!-- Subagent dispatch: 2 SEQUENTIAL subagents
     D1: sdd-doc-readme (README.md depends on architecture docs from Phase 3)
     D2: sdd-doc-generate-claude-md (CLAUDE.md depends on README content)
     D2 must wait for D1 to complete. -->

- [ ] 9.1 **Subagent D1**: Run `/sdd-doc-readme` — update README.md for Maven multi-module structure
- [ ] 9.2 Verify: README.md references `mvn compile`, `mvn test`, `mvn package` (INV-PRJ-01)
- [ ] 9.3 **Subagent D2**: Run `/sdd-doc-generate-claude-md` — refresh CLAUDE.md
- [ ] 9.4 Verify: CLAUDE.md build commands match pom.xml (INV-PRJ-02)

## 10. Quality Verification

<!-- Subagent dispatch: 2 SEQUENTIAL subagents
     E1: sdd-docs-sync + sdd-qa-lint (read-only analysis)
     E2: sdd-qa-lint-fix + sdd-verify + sdd-test-run (fixes + verification)
     E2 depends on E1 results. -->

- [ ] 10.1 **Subagent E1**: Run `/sdd-docs-sync` to check documentation cross-references, then `/sdd-qa-lint` for lint analysis
- [ ] 10.2 Review E1 results: note doc drift issues and lint violations
- [ ] 10.3 **Subagent E2**: Run `/sdd-qa-lint-fix` to auto-fix lint issues, then `/sdd-verify` for full verification (tests + lint + complexity), then `/sdd-test-run` to confirm 20 tests pass
- [ ] 10.4 Verify: `mvn test` shows 20 tests passing, 0 failures

## 11. Code Review

<!-- Subagent dispatch: 1 subagent
     F1: sdd-code-reviewer (final quality gate)
     Reviews all changes made across Phases 2-9. -->

- [ ] 11.1 **Subagent F1**: Run `/sdd-code-reviewer` — multi-dimension review of all changes (correctness, style, security, performance, maintainability)
- [ ] 11.2 Review F1 findings: address any critical or high-severity issues
- [ ] 11.3 If issues found: fix in targeted subagents, then re-run verification (repeat 10.3-10.4)

## 12. Final Verification

- [ ] 12.1 Confirm all tasks above are marked complete
- [ ] 12.2 Confirm `mvn test` passes (20 tests, 0 failures)
- [ ] 12.3 Confirm all deliverables exist:
  - `docs/architecture/` (3 view files)
  - `docs/adr/0001-*.md` and `docs/adr/0002-*.md`
  - `docs/nfr-mapping.md`
  - Javadocs added to ~355 Java files
  - `README.md` updated
  - `CLAUDE.md` updated
- [ ] 12.4 Run `/opsx:verify` to validate implementation against specs
