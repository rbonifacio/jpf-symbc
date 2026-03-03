# Specification: Architecture Documentation

## Purpose

This capability defines the generation and maintenance of architecture documentation for jpf-symbc after the Maven multi-module + Java 11 migration. Three artifact categories are produced: Views & Beyond architecture views (module, component-and-connector, allocation), Architectural Decision Records (ADRs) for the two major migration decisions, and a Non-Functional Requirements mapping that traces NFRs to their architectural support.

All architecture documentation artifacts SHALL reside under `docs/` in the project root. The documentation is generated from the Neo4j knowledge graph (which MUST be freshly populated before generation) and from the actual source structure of the 5 Maven modules.

### Documentation Artifacts

```
docs/
  architecture/
    module-view.md          <- Module decomposition (5 Maven modules, package hierarchy)
    component-connector-view.md  <- Runtime C&C (JPF VM, SymbolicInstructionFactory, solvers)
    allocation-view.md      <- Source-to-module mapping, build outputs, deployment
  adr/
    0001-ant-to-maven-migration.md   <- ADR-0001: Ant to Maven multi-module
    0002-java-8-to-11-upgrade.md     <- ADR-0002: Java 8 to Java 11
  nfr-mapping.md            <- NFR traceability matrix
```

### Subagent Execution Model

Architecture documentation generation uses 3 parallel subagents in a single wave:

| Subagent | Skill | Output |
|----------|-------|--------|
| B1 | `/sdd-doc-architecture` | `docs/architecture/*.md` (3 views) |
| B2 | `/sdd-doc-adr` (invoked twice, sequentially) | `docs/adr/0001-*.md`, `docs/adr/0002-*.md` |
| B3 | `/sdd-doc-nfr` | `docs/nfr-mapping.md` |

All 3 subagents are independent and MAY execute in parallel (max 3 concurrent). The Neo4j knowledge graph MUST be freshly populated before any subagent begins.

## Data Contracts

### Input

- **Neo4j knowledge graph**: Freshly populated with ~766 Java files across 5 Maven modules (from `/sdd-extract`)
- **Source code**: All Java files in `jpf-symbc-main/`, `jpf-symbc-annotations/`, `jpf-symbc-classes/`, `jpf-symbc-tests/`, `jpf-symbc-examples/`
- **Build configuration**: `pom.xml` files (parent + 5 modules)
- **Existing documentation**: `CLAUDE.md`, `README.md`, `openspec/specs/` (build, dependencies, configuration)
- **Migration artifacts**: `openspec/changes/gh1-migration-maven-java11/` (proposal, specs, design, tasks)

### Output

- **Architecture views**: 3 Markdown files in `docs/architecture/`
- **ADRs**: 2 Markdown files in `docs/adr/`
- **NFR mapping**: 1 Markdown file at `docs/nfr-mapping.md`

### Side Effects

- Creates `docs/architecture/` and `docs/adr/` directories if they do not exist
- No source code modifications

## Invariants

- **INV-ARC-01**: Architecture documentation SHALL NOT contain promotional, marketing, or aspirational language. All statements MUST be factual and verifiable against the codebase. Phrases such as "world-class", "cutting-edge", "best-in-class", "robust and scalable" are prohibited unless supported by specific evidence.

- **INV-ARC-02**: Architecture views SHALL be evidence-based only. Every element in a view (module, component, connector, allocation unit) MUST correspond to an actual artifact in the codebase (a Maven module, a Java package, a class, a configuration file, or a build output). Views SHALL NOT include planned, aspirational, or hypothetical elements.

- **INV-ARC-03**: ADRs SHALL use the 12-field template with the following sections: Title, Status, Date, Context, Decision Drivers, Considered Options, Decision Outcome, Rationale, Consequences (positive/negative/neutral), Compliance, Related Decisions, Notes. No field MAY be omitted; fields with no content SHALL state "None" or "N/A".

- **INV-ARC-04**: Architecture views SHALL reference actual source file paths using the Maven multi-module directory structure (e.g., `jpf-symbc-main/src/main/java/gov/nasa/jpf/symbc/`). Views SHALL NOT reference the old Ant source layout (`src/main/`, `src/peers/`, `src/classes/`, etc.).

## Requirements

### Requirement: Generate Architecture Views (ARC-01)

Architecture views SHALL be generated in `docs/architecture/` using the Views & Beyond (V&B) methodology. Three views SHALL be produced: module decomposition, component-and-connector (C&C), and allocation.

Each view SHALL contain the following V&B sections:
1. **Primary Presentation** -- the main diagram or structured description of the view
2. **Element Catalog** -- description of each element shown in the primary presentation
3. **Context** -- how this view relates to the broader system (JPF core, host JVM, solvers)
4. **Variability** -- configuration points, optional elements, extension mechanisms
5. **Rationale** -- why the architecture is structured this way

#### Scenario: Module View Generation

- **WHEN** subagent B1 executes `/sdd-doc-architecture` against the freshly populated Neo4j graph
- **THEN** `docs/architecture/module-view.md` is created
- **AND** it contains a Primary Presentation showing all 5 Maven modules and their dependency relationships
- **AND** the Element Catalog describes each module's purpose, file count, and key packages
- **AND** the dependency arrows match the actual `<dependency>` declarations in `pom.xml` files
- **AND** the view references Maven module paths (e.g., `jpf-symbc-main/src/main/java/`)

#### Scenario: Component-and-Connector View Generation

- **WHEN** subagent B1 executes `/sdd-doc-architecture`
- **THEN** `docs/architecture/component-connector-view.md` is created
- **AND** it shows runtime components: JPF VM, SymbolicInstructionFactory, SymbolicListener, PCChoiceGenerator, solver backends
- **AND** connectors represent method calls, event notifications, and constraint submission
- **AND** the solver backend is shown as a variability point (pluggable via `symbolic.dp` configuration)

#### Scenario: Allocation View Generation

- **WHEN** subagent B1 executes `/sdd-doc-architecture`
- **THEN** `docs/architecture/allocation-view.md` is created
- **AND** it maps source modules to build outputs (`target/classes/`, JAR files)
- **AND** it maps native libraries in `lib/` and `lib/64bit/` to their solver components
- **AND** it maps solver JARs in `repo/` to their Maven coordinates

#### Scenario: View Section Completeness

- **WHEN** any architecture view file is inspected
- **THEN** it contains all 5 V&B sections: Primary Presentation, Element Catalog, Context, Variability, Rationale
- **AND** no section is empty or contains only placeholder text
- **AND** all referenced source paths exist in the current Maven multi-module structure

### Requirement: Record Architectural Decision Records (ARC-02)

Two ADRs SHALL be recorded documenting the major decisions made during the gh1 migration. ADR-0001 covers the Ant-to-Maven multi-module migration. ADR-0002 covers the Java 8-to-11 upgrade.

ADRs SHALL use the 12-field template defined in INV-ARC-03. The Status field for both ADRs SHALL be "Accepted" since both decisions have been implemented.

#### Scenario: ADR-0001 Ant to Maven Migration

- **WHEN** subagent B2 executes `/sdd-doc-adr "Ant to Maven multi-module migration"`
- **THEN** `docs/adr/0001-ant-to-maven-migration.md` is created
- **AND** the Context section describes the original Ant build with 6 source roots and 3 JAR outputs
- **AND** Considered Options include at minimum: (a) keep Ant, (b) migrate to Gradle, (c) migrate to Maven single-module, (d) migrate to Maven multi-module
- **AND** Decision Outcome states Maven multi-module with 5 modules
- **AND** Consequences include the `--patch-module` requirement for `jpf-symbc-classes` on Java 11
- **AND** Consequences include the INV-BLD-03 breaking change (annotations separated from classes JAR)
- **AND** Related Decisions references ADR-0002

#### Scenario: ADR-0002 Java 8 to 11 Upgrade

- **WHEN** subagent B2 executes `/sdd-doc-adr "Java 8 to Java 11 upgrade"`
- **THEN** `docs/adr/0002-java-8-to-11-upgrade.md` is created
- **AND** the Context section describes the Java 8 baseline and the module system impact on `java.*` model classes
- **AND** Decision Drivers include jpf-core official requiring Java 11 and end-of-life status of Java 8
- **AND** Consequences include the need for `--patch-module`, `--add-opens`, and `--add-exports` flags
- **AND** Consequences reference the opt4j 2.4 ASM incompatibility with Java 11 (Coral solver limitation)
- **AND** Related Decisions references ADR-0001

#### Scenario: ADR Template Compliance

- **WHEN** any ADR file is inspected
- **THEN** it contains all 12 fields: Title, Status, Date, Context, Decision Drivers, Considered Options, Decision Outcome, Rationale, Consequences, Compliance, Related Decisions, Notes
- **AND** Status is "Accepted"
- **AND** Date reflects the migration completion date
- **AND** no field is missing or omitted

### Requirement: Generate NFR Mapping (ARC-03)

A Non-Functional Requirements mapping SHALL be generated at `docs/nfr-mapping.md` that traces each NFR from the migration PRD (`docs/PRD.md`) to its architectural support in the codebase.

The mapping SHALL cover at minimum: build reproducibility, test stability, backward compatibility (classpath resolution), and solver extensibility.

#### Scenario: NFR Mapping Generation

- **WHEN** subagent B3 executes `/sdd-doc-nfr`
- **THEN** `docs/nfr-mapping.md` is created
- **AND** each NFR from `docs/PRD.md` (NFR01 through NFR07) is listed with its architectural support
- **AND** each NFR entry includes: NFR identifier, description, how the architecture addresses it, and evidence (specific files, configurations, or test results)
- **AND** evidence references actual file paths in the Maven multi-module structure

#### Scenario: NFR Traceability Completeness

- **WHEN** `docs/nfr-mapping.md` is compared against `docs/PRD.md`
- **THEN** every NFR defined in the PRD has a corresponding entry in the mapping
- **AND** no NFR is marked as "not addressed" without an explicit justification

### Requirement: Parallel Subagent Execution (ARC-04)

Architecture documentation generation SHALL use 3 parallel subagents (B1, B2, B3) to maximize throughput. The subagents are independent and operate on different output directories.

#### Scenario: Parallel Dispatch

- **WHEN** Phase 3 of the implementation plan is executed
- **THEN** subagents B1 (architecture views), B2 (ADRs), and B3 (NFR mapping) are dispatched in parallel
- **AND** no subagent writes to another subagent's output directory
- **AND** all 3 subagents complete before Phase 4 begins
- **AND** the Neo4j knowledge graph is read-only during this phase (no concurrent extraction)

#### Scenario: Subagent Failure Isolation

- **WHEN** one subagent (e.g., B2) fails during execution
- **THEN** the other subagents (B1, B3) are not affected
- **AND** the failed subagent's task MAY be retried independently
- **AND** the main context reports which subagent(s) failed and which succeeded
