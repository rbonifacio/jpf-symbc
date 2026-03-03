# Specification: Neo4j Knowledge Graph Extraction and Freshness

## Purpose

The Neo4j knowledge graph provides structural metadata about the jpf-symbc codebase for use by SDD Toolkit analysis skills (`sdd-analyze-dead-code`, `sdd-analyze-dependencies`, `sdd-analyze-complexity`, `sdd-impact-analyzer`, `sdd-architect`). After the Maven multi-module migration (gh1), the existing graph is stale -- it contains 773 units extracted from the old Ant source layout, with file paths that no longer match the filesystem. This specification defines the extraction lifecycle: when to clear, when to re-extract, what the graph must contain, and how staleness is detected.

### Graph Node Types

Extraction via `mcp__sdd__extract_project` produces the following node types:

| Node Type | Description | Expected Source |
|-----------|-------------|----------------|
| **Unit** | A Java source file (class, interface, enum, annotation) | Each `.java` file in `src/main/java/` or `src/main/modules/` |
| **Callable** | A method or constructor within a Unit | Methods and constructors parsed by tree-sitter |
| **Member** | A field or constant within a Unit | Fields parsed by tree-sitter |
| **Pattern** | A detected design pattern (when `detect_patterns=true`) | Structural analysis of class relationships |

### Module Coverage

After extraction, the graph SHALL contain nodes from all 5 Maven modules:

| Module | Source Root | Expected Content |
|--------|-----------|-----------------|
| `jpf-symbc-annotations` | `jpf-symbc-annotations/src/main/java/` | 4 annotation interfaces |
| `jpf-symbc-main` | `jpf-symbc-main/src/main/java/` | 342 implementation classes |
| `jpf-symbc-classes` | `jpf-symbc-classes/src/main/java/` + `src/main/modules/` | 9 model classes |
| `jpf-symbc-tests` | `jpf-symbc-tests/src/test/java/` | 197 test classes |
| `jpf-symbc-examples` | `jpf-symbc-examples/src/main/java/` | 213 example classes |

### Extraction Triggers

Re-extraction SHALL be performed at two defined points in the gh2 change lifecycle:

| Trigger | Phase | Subagent | Reason |
|---------|-------|----------|--------|
| Project start | Phase 0 (step 0.3) | **A0** | Replace stale Ant-era graph with Maven layout |
| Post dead-code removal | Phase 2 (step 2.2) | **A3** | Reflect deleted files/elements |

### Staleness Detection

The graph is considered **stale** when any of the following conditions hold:

- File paths stored in Unit nodes reference directories that no longer exist on the filesystem (e.g., `src/main/gov/...` instead of `jpf-symbc-main/src/main/java/gov/...`)
- The count of Unit nodes diverges significantly (>5%) from the actual `.java` file count on disk
- Source files have been added, deleted, or moved since the last extraction

## Data Contracts

### Input

- **Project root path**: `/pedro/desenvolvimento/workspaces/workspaces-doutorado/workspace-rv/jpf-symbc`
- **Neo4j database**: Running via Docker (`sdd-graphdb`, bolt://localhost:7687)
- **SDD MCP server**: Running and connected to Neo4j

### Output

- **Unit nodes**: One per `.java` source file, with `qualified_name`, `file_path`, `language`, and `module` properties
- **Callable nodes**: One per method/constructor, linked to parent Unit via `CONTAINS` relationship
- **Member nodes**: One per field, linked to parent Unit via `CONTAINS` relationship
- **Pattern nodes**: Detected design patterns (when `detect_patterns=true`), linked to participating Units
- **Dependency edges**: `DEPENDS_ON`, `CALLS`, `IMPLEMENTS`, `EXTENDS` relationships between nodes

### Side Effects

- Neo4j database contents are replaced (clear + re-extract is destructive to existing graph data)
- Schema constraints and indexes are reinitialized
- Extraction time scales with codebase size (~766 files; expect several minutes)

## Invariants

- **INV-KG-01**: Before any extraction, the existing graph data SHALL be cleared via `mcp__sdd__clear_project("jpf-symbc")` and the schema SHALL be reinitialized via `mcp__sdd__init_schema()`. Extracting on top of stale data without clearing first would produce duplicate nodes and inconsistent relationships.
- **INV-KG-02**: After extraction completes, the graph SHALL contain Unit nodes from all 5 Maven modules (`jpf-symbc-annotations`, `jpf-symbc-main`, `jpf-symbc-classes`, `jpf-symbc-tests`, `jpf-symbc-examples`). Missing modules indicate extraction failure or misconfigured project path.
- **INV-KG-03**: After any code deletion (dead code removal, refactoring, or file restructuring), the Neo4j graph SHALL be re-extracted before any subsequent analysis skill is invoked. Analysis on a stale graph produces incorrect results (e.g., dead code detection would miss deleted files or report phantom references).
- **INV-KG-04**: Extraction SHALL cover all `.java` files under `src/main/java/` directories (and `src/main/modules/` for `jpf-symbc-classes`, and `src/test/java/` for `jpf-symbc-tests`). Files outside these directories (e.g., `backup/`, `target/`, `openspec/`) SHALL NOT be extracted.

## Requirements

### Requirement: Pre-Extraction Cleanup (KG-01)

Before re-extraction, the existing Neo4j graph data SHALL be cleared and the schema reinitialized. This prevents duplicate nodes, orphaned relationships, and path conflicts between old and new data.

#### Scenario: Clear and Reinitialize Before Initial Extraction

- **WHEN** Phase 0 begins (step 0.1-0.2)
- **THEN** `mcp__sdd__clear_project("jpf-symbc")` is invoked to remove all existing nodes and relationships for the project
- **AND** `mcp__sdd__init_schema()` is invoked to recreate constraints and indexes
- **AND** the graph contains zero Unit, Callable, Member, and Pattern nodes for `jpf-symbc` before extraction starts

#### Scenario: Clear and Reinitialize Before Post-Cleanup Extraction

- **WHEN** Phase 2 dead code removal completes (step 2.1) and re-extraction begins (step 2.2)
- **THEN** `mcp__sdd__clear_project("jpf-symbc")` is invoked before extraction
- **AND** `mcp__sdd__init_schema()` is invoked to reinitialize the schema
- **AND** the old graph data (which references now-deleted files) is fully removed

### Requirement: Full Project Extraction (KG-02)

Extraction SHALL use `mcp__sdd__extract_project` with the project root path and SHALL produce Unit, Callable, Member, and Pattern nodes covering all 5 Maven modules.

#### Scenario: Initial Extraction (Phase 0)

- **WHEN** subagent A0 invokes `/sdd-extract` on the project root
- **THEN** `mcp__sdd__extract_project` is called with `project_path` set to the project root and `detect_patterns=true`
- **AND** the extraction processes all `.java` files in all 5 module source directories
- **AND** Unit nodes are created with `file_path` properties that match the current Maven module paths (e.g., `jpf-symbc-main/src/main/java/gov/nasa/jpf/symbc/...`)

#### Scenario: Post-Cleanup Extraction (Phase 2)

- **WHEN** subagent A3 invokes `/sdd-extract` after dead code removal
- **THEN** `mcp__sdd__extract_project` is called with the same parameters as Phase 0
- **AND** the resulting graph reflects the post-cleanup file set (deleted files are absent)
- **AND** the Unit node count is less than or equal to the Phase 0 count (files were only removed, not added)

#### Scenario: Extraction Failure Handling

- **WHEN** `mcp__sdd__extract_project` fails (e.g., Neo4j connection error, timeout)
- **THEN** the error is reported to the orchestrator
- **AND** no subsequent analysis skills (`sdd-analyze-dead-code`, `sdd-architect`, etc.) SHALL be invoked until extraction succeeds
- **AND** the orchestrator MAY retry extraction once before escalating to the user

### Requirement: Module Coverage Verification (KG-03)

After extraction, the graph SHALL be verified to contain nodes from all 5 Maven modules. A missing module indicates extraction failure or a path configuration issue.

#### Scenario: All Modules Present

- **WHEN** extraction completes successfully
- **THEN** a verification query against Neo4j confirms Unit nodes exist with file paths containing each of the 5 module prefixes:
  - `jpf-symbc-annotations/`
  - `jpf-symbc-main/`
  - `jpf-symbc-classes/`
  - `jpf-symbc-tests/`
  - `jpf-symbc-examples/`
- **AND** the total Unit node count is approximately 766 (within 5% tolerance to account for inner classes or parsing exclusions)

#### Scenario: Module Missing After Extraction

- **WHEN** extraction completes but a verification query finds zero Unit nodes for one or more modules
- **THEN** the missing module(s) are reported as an extraction error
- **AND** the extraction is considered failed
- **AND** the orchestrator SHALL investigate the project path and module structure before retrying

### Requirement: Extraction Scope (KG-04)

Extraction SHALL cover all Java source files under the defined source roots and SHALL exclude non-source directories.

#### Scenario: Source Directories Included

- **WHEN** extraction runs on the project root
- **THEN** the following source directories are processed:
  - `jpf-symbc-annotations/src/main/java/`
  - `jpf-symbc-main/src/main/java/`
  - `jpf-symbc-classes/src/main/java/`
  - `jpf-symbc-classes/src/main/modules/java.base/`
  - `jpf-symbc-classes/src/main/modules/java.desktop/`
  - `jpf-symbc-tests/src/test/java/`
  - `jpf-symbc-examples/src/main/java/`
- **AND** all `.java` files within these directories (recursively) are parsed and represented as nodes

#### Scenario: Non-Source Directories Excluded

- **WHEN** extraction runs on the project root
- **THEN** the following directories SHALL NOT contribute Unit nodes:
  - `backup/` (archived pre-migration sources)
  - `*/target/` (Maven build output)
  - `openspec/` (specification artifacts)
  - `.sdd/` (SDD toolkit configuration)
  - `docs/` (documentation)
  - `lib/` (native libraries and legacy JARs)
  - `repo/` (local Maven repository)

### Requirement: Staleness Detection (KG-05)

The graph SHALL be considered stale when source file paths in Neo4j do not match the filesystem. Staleness detection enables the orchestrator to decide whether re-extraction is needed before running analysis skills.

#### Scenario: Detect Stale Paths After Migration

- **WHEN** the graph contains Unit nodes with file paths referencing the old Ant layout (e.g., `src/main/gov/nasa/...`)
- **AND** those paths do not exist on the current filesystem
- **THEN** the graph is classified as stale
- **AND** re-extraction is required before any analysis skill can be invoked

#### Scenario: Detect Stale Count After Deletion

- **WHEN** the count of `.java` files on disk is compared to the count of Unit nodes in Neo4j
- **AND** the difference exceeds 5% of the on-disk count
- **THEN** the graph is classified as stale
- **AND** re-extraction SHOULD be performed before analysis

#### Scenario: Graph Is Fresh

- **WHEN** the graph was extracted after the most recent code change
- **AND** a sample of 10 Unit node file paths are verified to exist on the filesystem
- **AND** the Unit node count is within 5% of the on-disk `.java` file count
- **THEN** the graph is classified as fresh
- **AND** analysis skills MAY proceed without re-extraction

### Requirement: Re-Extraction After Code Deletion (KG-06)

After any code deletion (dead code removal in Phase 2), the Neo4j graph SHALL be re-extracted to prevent analysis skills from operating on phantom nodes that reference deleted files.

#### Scenario: Re-Extraction After Dead Code Removal

- **WHEN** dead code removal completes in Phase 2 (step 2.1)
- **AND** one or more files were deleted
- **THEN** subagent A3 SHALL invoke clear + init_schema + extract_project (step 2.2)
- **AND** the resulting graph SHALL NOT contain Unit nodes for any deleted files

#### Scenario: Re-Extraction When No Files Deleted

- **WHEN** dead code removal completes but no files were actually deleted (user rejected all candidates)
- **THEN** subagent A3 SHALL still invoke re-extraction
- **AND** the graph remains consistent (idempotent operation)
- **AND** subsequent analysis skills can proceed with confidence
