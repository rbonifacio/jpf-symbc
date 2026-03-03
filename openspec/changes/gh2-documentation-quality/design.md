# Design: gh2 — Documentation, Dead Code Cleanup & Quality Improvement

## Context

After the gh1 migration (Ant → Maven multi-module + Java 8 → 11), the project has a working build and test suite but lacks documentation artifacts and has an untested dead code baseline. The Neo4j knowledge graph is stale (773 units from the old Ant source layout). This design describes how to re-extract the graph, remove dead code, generate documentation, and verify quality — all orchestrated via subagents to keep the main context clean.

**Constraints:**
- SDD Toolkit in Full mode (Neo4j + MCP server required)
- Skills execute inside subagents (Skill tool available in subagent context)
- Subagents cannot spawn other subagents (Task tool absent from subagent context)
- Max 3 parallel subagents per wave (empirically safe)
- Max 30 files per sdd-doc-code subagent (context window budget)
- `mvn test` (20 tests) must pass at all checkpoints

**References:**
- Proposal: `openspec/changes/gh2-documentation-quality/proposal.md`
- Pre-plan: `openspec/changes/gh2-documentation-quality/pre-plan.md`
- PRD: `docs/PRD.md` (NFR01-NFR07)
- Specs: 5 delta specs in `openspec/changes/gh2-documentation-quality/specs/`

## Architecture

### Orchestration Model

```
Main Context (orchestrator — no skills, no file edits)
│
├── Phase 0: A0 [sdd-extract]
├── Phase 1: A1 [sdd-architect → analyze-module → analyze-deps → analyze-complexity → impact-analyzer]
├── Phase 2: A2a [sdd-analyze-dead-code] → user approval (main) → A2b [removal + sdd-test-run]
│             A3 [sdd-extract]
├── Phase 3: B1 ∥ B2 ∥ B3  [doc-architecture ∥ doc-adr ×2 ∥ doc-nfr]
├── Phase 4: 5 waves × 3 parallel  [sdd-doc-code × 15, covering 355 files across symbc + edu.ucsb packages]
├── Phase 5: D1 → D2  [doc-readme → doc-generate-claude-md]
├── Phase 6: E1 → E2  [docs-sync + qa-lint → qa-lint-fix + verify + test-run]
└── Phase 7: F1 [sdd-code-reviewer]
```

### Key Components

| Component | Role | Location |
|-----------|------|----------|
| Neo4j knowledge graph | Structural data store for analysis and doc-architecture | Docker container `sdd-graphdb` |
| MCP server `sdd` | Bridge between skills and Neo4j (extract, query, aggregate) | `mcp-server/` in agentes-claude |
| sdd-extract | Tree-sitter parser → Neo4j populator | `.claude/skills/sdd-extract/` |
| sdd-architect | Composite analysis (4 internal skills) | `.claude/skills/sdd-architect/` |
| sdd-analyze-dead-code | Dead code detection (confidence-classified candidates) | `.claude/skills/sdd-analyze-dead-code/` |
| sdd-doc-* (6 skills) | Documentation generators | `.claude/skills/sdd-doc-*/` |
| sdd-verify | 3-stage pipeline (tests + lint + complexity) | `.claude/skills/sdd-verify/` |
| sdd-code-reviewer | 5-dimension review (correctness, style, security, perf, maintainability) | `.claude/skills/sdd-code-reviewer/` |

## Mapping: Spec → Implementation → Test

| Spec | Requirement | Implementation | Verification |
|------|------------|----------------|-------------|
| quality-knowledge-graph | KG-01: Pre-extraction cleanup | `mcp__sdd__clear_project` + `mcp__sdd__init_schema` | Cypher: `MATCH (n) RETURN count(n)` = 0 after clear |
| quality-knowledge-graph | KG-02: Full project extraction | `mcp__sdd__extract_project` | Cypher: `MATCH (p:Project) RETURN count(p)` > 0 |
| quality-knowledge-graph | KG-03: Module coverage verification | sdd-extract output report | Cypher: 5 distinct modules with Unit nodes |
| quality-knowledge-graph | KG-04: Extraction scope | sdd-extract project path config | Unit nodes only from `src/main/java/`, `src/main/modules/`, `src/test/java/` |
| quality-knowledge-graph | KG-05: Staleness detection | Cypher path verification | Sample 10 Unit file_path values exist on filesystem |
| quality-knowledge-graph | KG-06: Re-extraction after deletion | Subagent A3 `/sdd-extract` after Phase 2 | Deleted files absent from graph; node count ≤ Phase 0 count |
| quality-dead-code | DC-01: Detection via sdd-analyze-dead-code | `/sdd-analyze-dead-code` (subagent A2a) | Candidate list with confidence levels |
| quality-dead-code | DC-02: Confidence classification | sdd-analyze-dead-code internal logic | Each candidate has exactly one tier (High/Medium/Low) |
| quality-dead-code | DC-03: Entry point exclusion | sdd-analyze-dead-code exclusion rules | No `main(String[])` classes in candidate list |
| quality-dead-code | DC-04: JPF native peer exclusion | sdd-analyze-dead-code exclusion rules | No `JPF_*` classes in candidate list |
| quality-dead-code | DC-05: Test file handling | sdd-analyze-dead-code reference scanning | Test-only references → Medium confidence (not High) |
| quality-dead-code | DC-06: User approval before deletion | Main context presents candidates to user | User explicitly confirms/rejects before any deletion |
| quality-dead-code | DC-07: Post-removal verification | Subagent A2b runs `/sdd-test-run` | `mvn test` passes (20 tests) |
| quality-dead-code | DC-08: Post-cleanup re-extraction | Subagent A3 `/sdd-extract` | Graph reflects post-cleanup file set |
| documentation-architecture | ARC-01: Views & Beyond | `/sdd-doc-architecture` (subagent B1) | Files exist in `docs/architecture/`, contain 5 V&B sections |
| documentation-architecture | ARC-02: ADRs | `/sdd-doc-adr` × 2 (subagent B2) | Files exist in `docs/adr/`, 12-field template |
| documentation-architecture | ARC-03: NFR mapping | `/sdd-doc-nfr` (subagent B3) | `docs/nfr-mapping.md` exists, covers NFR01-NFR07 |
| documentation-architecture | ARC-04: Parallel execution | 3 parallel subagents (B1, B2, B3) | All 3 complete before Phase 4; no cross-writes |
| documentation-code | COD-01: Javadoc coverage | `/sdd-doc-code` × 15 batches (C1-C15) | `mvn compile` passes; Javadoc present on public classes |
| documentation-code | COD-02: Batched execution | 5 waves × 3 parallel subagents | Each subagent processes ≤ 30 files |
| documentation-code | COD-03: Bytecode splitting | 4 alphabetical groups (C7-C10) | 102 files split into ~25 each; no file in multiple groups |
| documentation-code | COD-04: Annotation/model docs | Subagent C2 covers annotations + classes | Both `src/main/java/` and `src/main/modules/` processed |
| documentation-code | COD-05: No functional changes | sdd-doc-code Javadoc-only edits | `git diff` shows only `/** */` comment changes |
| documentation-project | PRJ-01: README update | `/sdd-doc-readme` (subagent D1) | `README.md` references Maven commands |
| documentation-project | PRJ-02: CLAUDE.md update | `/sdd-doc-generate-claude-md` (subagent D2) | `CLAUDE.md` references current module layout |
| documentation-project | PRJ-03: Sequential execution | D1 → D2 (D2 after D1 completes) | D2 dispatched only after D1 returns |

## Goals / Non-Goals

**Goals:**
- Re-establish a fresh, accurate Neo4j knowledge graph for the Maven multi-module structure
- Identify and remove dead code before documenting (avoid documenting unused code)
- Produce architecture documentation (Views & Beyond, ADRs, NFR mapping)
- Add Javadocs to ~355 Java files in core packages
- Update README.md and CLAUDE.md to reflect current project state
- Verify quality (lint, tests, doc freshness) and review all changes

**Non-goals:**
- Javadocs for test files (197) and examples (213) — future change
- Security analysis — separate concern
- Refactoring or feature implementation
- Release preparation or version tagging
- Modifying build configuration (pom.xml)

## Decisions

### D1: Manual orchestration over sdd-documenter

**Decision:** Orchestrate documentation skills manually via subagents instead of using the `sdd-documenter` orchestrator skill.

**Rationale:** sdd-documenter runs all doc skills sequentially in a single context. This change requires: (a) Neo4j re-extraction before documentation, (b) dead code cleanup before documentation, (c) batched sdd-doc-code with parallelism, (d) quality verification after documentation. sdd-documenter does not support any of these requirements.

**Alternative rejected:** Use sdd-documenter for Phase 3-5, handle Phase 0-2 and 6-7 separately. Rejected because sdd-doc-code (the largest phase by volume) needs 15 parallel subagents, which sdd-documenter cannot orchestrate.

### D2: Subagent-per-skill over inline execution

**Decision:** Every skill invocation runs in a dedicated subagent. The main context dispatches and collects results only.

**Rationale:** With ~31 skill invocations, running them inline would accumulate ~50K-100K tokens of tool call results in the main context, risking context overflow. Subagent results are summarized by the Agent tool (~500 tokens each), keeping the main context under 20K tokens of accumulated results.

**Alternative rejected:** Run simple skills (doc-adr, doc-nfr) inline. Rejected for consistency — a uniform pattern (always subagent) is simpler to implement and reason about.

### D3: Max 30 files per sdd-doc-code subagent

**Decision:** Each sdd-doc-code subagent processes at most 30 Java files.

**Rationale:** Each file requires: read (~200-500 lines), classify symbols (5 categories), generate Javadoc (100-300 tokens output), edit file (tool call + result). Conservative estimate: 2000-3000 tokens per file. At 30 files: 60K-90K tokens. The subagent context window is ~200K tokens with a practical safe limit of ~100K for accumulated tool results, leaving ample margin for skill instructions and tool infrastructure.

**Risk:** Bytecode root has 102 files — split alphabetically into 4 groups of ~25. If individual bytecode files are unusually large, groups can be split further.

### D4: Alphabetical splitting for bytecode root

**Decision:** Split `symbc/bytecode/` root (102 files) into 4 groups by first letter of filename: A-F, G-I, IF-N, O-Z.

**Rationale:** Bytecode classes follow naming conventions matching JVM instructions (e.g., `IADD.java`, `ISUB.java`, `IF_ICMPGE.java`). Alphabetical splitting produces roughly equal groups and is deterministic (same split every time).

**Alternative rejected:** Split by JVM instruction category (arithmetic, comparison, load/store, etc.). Rejected because it requires domain knowledge to classify and would produce uneven groups.

### D5: Dead code cleanup before documentation

**Decision:** Run dead code analysis and removal (Phase 2) before documentation generation (Phase 3-4).

**Rationale:** Documenting dead code wastes effort. By removing unused classes/methods first, sdd-doc-code only processes code that is actually used. The cleanup also produces a cleaner Neo4j graph for architecture documentation.

**Trade-off:** Adds 1 session to the timeline (cleanup + re-extract). Acceptable because it prevents documenting code that will be deleted.

### D6: Component skills for dead code over sdd-cleanup orchestrator

**Decision:** Use `/sdd-analyze-dead-code` directly + manual orchestration instead of the `/sdd-cleanup` orchestrator.

**Rationale:** The `sdd-cleanup` skill explicitly states "WHEN NOT: inside Full/FF SDD workflows where OpenSpec artifacts already provide analysis and planning. Use component skills directly in tasks.md instead." Since gh2 uses the Full SDD track, we must use component skills. The manual orchestration is: A2a (detection) → user approval in main context → A2b (removal + test verification) → A3 (re-extraction).

**Alternative rejected:** Use `sdd-cleanup` as a convenience orchestrator. Rejected because it violates the skill's own usage guidance for Full SDD workflows.

## Data Flow

```
Phase 0: Project files → tree-sitter → Neo4j (Units, Callables, Members, Patterns)
Phase 1: Neo4j → sdd-architect → architectural analysis report (console)
Phase 2: Neo4j → sdd-analyze-dead-code → candidates → user approval (main) → file deletion + sdd-test-run
         Modified files → tree-sitter → Neo4j (re-extract)
Phase 3: Neo4j → sdd-doc-architecture → docs/architecture/*.md
         Project history → sdd-doc-adr → docs/adr/*.md
         PRD + Neo4j → sdd-doc-nfr → docs/nfr-mapping.md
Phase 4: Java files → sdd-doc-code → modified Java files (Javadoc added)
Phase 5: pom.xml + structure → sdd-doc-readme → README.md
         config + structure → sdd-doc-generate-claude-md → CLAUDE.md
Phase 6: All docs → sdd-docs-sync → drift report
         All files → sdd-qa-lint → lint report → sdd-qa-lint-fix → fixed files
         All files → sdd-verify → test + lint + complexity report
Phase 7: Changed files → sdd-code-reviewer → review report
```

## Error Handling

| Error | Source | Strategy | Recovery |
|-------|--------|----------|----------|
| Neo4j extraction fails | MCP server or tree-sitter | Check Docker container status, MCP server logs | Restart container; if persistent, fall back to Minimal mode |
| sdd-doc-code generates empty/malformed Javadoc | LLM hallucination | Compilation check (`mvn compile`) after each wave | Re-run failed batch with refined prompt |
| Dead code candidate is actually used | False positive in analysis | User reviews ALL candidates before deletion | Reject false positives during approval; sdd-verify catches missed dependencies |
| Subagent context overflow | Too many files or large files | Max 30 files/subagent invariant (INV-COD-01) | Split batch further if a subagent fails |
| `mvn test` fails after doc changes | Javadoc syntax error or deleted code | sdd-verify at Phase 6 | Fix Javadoc syntax; if dead code removal caused regression, revert specific removal |
| Parallel subagents write to same file | File conflict | Each subagent targets non-overlapping directories | No recovery needed — prevented by design (INV-COD-01 + directory assignment) |

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| 355 files × Javadoc generation = significant LLM cost | Batching limits blast radius; priority packages first; can stop after core packages |
| Dead code cleanup may be aggressive (false positives) | User approval checkpoint; JPF native peers (`JPF_*`) excluded by INV-DC-04 |
| Generated Javadocs may be inaccurate (wrong @param names, misleading descriptions) | `mvn compile` catches structural errors; code-reviewer checks quality in Phase 7 |
| Neo4j graph stale again after Phase 4 (Javadoc edits don't change structure) | Acceptable — Javadoc-only changes don't affect graph validity (no new/removed classes) |
| Multiple sessions required (est. 7) | Each wave is a natural checkpoint; progress tracked in tasks.md |

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Compilation | Javadoc syntax validity | `mvn compile` after each doc-code wave |
| Unit tests | No regressions from dead code removal | `mvn test` (20 tests) at Phase 2 and Phase 6 |
| Structure | Neo4j graph completeness | Cypher queries: 5 modules present, node count > 0 |
| Documentation | Cross-reference integrity | sdd-docs-sync at Phase 6 |
| Lint | Code style compliance | sdd-qa-lint + sdd-qa-lint-fix at Phase 6 |
| Review | Multi-dimension quality | sdd-code-reviewer at Phase 7 |

## Open Questions

None — all design decisions resolved in pre-plan and proposal.
