## Why

After completing the Maven multi-module + Java 11 migration ([#1](https://github.com/phtcosta/jpf-symbc/issues/1)), the project lacks architecture documentation, has sparse Javadocs across ~766 Java files, contains unassessed dead code, and the Neo4j knowledge graph is stale (reflects the old Ant structure). This change addresses these gaps by re-extracting the project structure, removing dead code, and generating comprehensive documentation. ([#2](https://github.com/phtcosta/jpf-symbc/issues/2))

## What Changes

- **Reset and re-populate the Neo4j knowledge graph** with the new Maven multi-module source layout (5 modules, ~766 Java files)
- **Detect and remove dead code** across all modules (unreferenced classes, methods, imports) with user approval before deletion
- **Generate architecture documentation** using Views & Beyond methodology (module views, C&C views, allocation views)
- **Record 2 Architectural Decision Records**: ADR-0001 (Ant → Maven multi-module migration) and ADR-0002 (Java 8 → 11 upgrade)
- **Map Non-Functional Requirements** to architectural support (performance, maintainability, etc.)
- **Add Javadoc comments** to core packages in jpf-symbc-main (~342 files, including 326 under `gov.nasa.jpf.symbc` + 16 under `edu.ucsb.cs.vlab`), jpf-symbc-annotations (4 files), and jpf-symbc-classes (9 files: 5 in `src/main/java/` + 4 in `src/main/modules/`) — ~355 files total, batched by sub-package with max 30 files per subagent invocation
- **Update README.md** to reflect Maven build system, module structure, and setup instructions
- **Update CLAUDE.md** to reflect current project state
- **Verify documentation freshness**, fix lint issues, run full verification (tests + lint + complexity), and perform code review

## Capabilities

### New Capabilities

- `documentation-architecture`: Architecture documentation artifacts — Views & Beyond views, ADRs, NFR mapping. Covers `docs/architecture/`, `docs/adr/`, `docs/nfr-mapping.md`.
- `documentation-code`: Javadoc generation standards and coverage for Java source files. Defines which packages require documentation, classification rules (undocumented/stub/substantive), and Javadoc conventions (`@param`, `@return`, `@throws`).
- `documentation-project`: Project-level documentation artifacts — README.md and CLAUDE.md generation and update rules.
- `quality-dead-code`: Dead code detection and removal process. Defines confidence levels, exclusion rules (entry points, framework lifecycle), and approval workflow.
- `quality-knowledge-graph`: Neo4j knowledge graph extraction and freshness rules. Defines when re-extraction is required, expected node/relationship counts, and staleness detection.

### Modified Capabilities

(none — no existing spec-level requirements are changing; the build, configuration, and dependencies specs remain as-is)

## Impact

**Affected components:**
- All Java source files in jpf-symbc-main (342 files: 326 under `gov.nasa.jpf.symbc` + 16 under `edu.ucsb.cs.vlab` / `vlab.cs.ucsb.edu`) — Javadoc additions
- All Java source files in jpf-symbc-annotations (4 files) — Javadoc additions
- All Java source files in jpf-symbc-classes (5 in `src/main/java/` + 4 in `src/main/modules/` = 9 files) — Javadoc additions
- Dead code candidates across all modules — removal
- `docs/` directory — new architecture documentation, ADRs, NFR mapping
- `README.md` — updated for Maven structure
- `CLAUDE.md` — refreshed to reflect current state
- Neo4j database — cleared and re-populated

**No impact on:**
- Build system (pom.xml files unchanged)
- Test suite (no test modifications; 20 tests must continue passing)
- Runtime behavior (documentation-only changes + dead code removal)
- Dependencies (no dependency changes)
- `.jpf` configuration files (unchanged)

**Cross-component dependencies:**
- Neo4j re-extraction (Phase 0) must complete before any analysis skill can query the graph
- Dead code removal (Phase 2) must complete before documentation (Phase 3-4) to avoid documenting dead code
- Architecture documentation (Phase 3) should complete before code documentation (Phase 4) to inform package-level context
- All documentation must complete before quality verification (Phase 6) and code review (Phase 7)

**Subagent orchestration:**
- 28 subagent dispatches across 7 phases
- Phase 3 (architecture docs): 3 parallel subagents
- Phase 4 (Javadocs): 5 waves of 3 parallel subagents each (15 total)
- Max 30 files per subagent to avoid context window overflow
- Main context acts as dispatcher only — does not run skills directly
