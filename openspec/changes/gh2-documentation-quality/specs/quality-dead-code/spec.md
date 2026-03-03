# Specification: Dead Code Detection and Removal

## Purpose

Dead code detection and removal ensures the codebase remains lean and maintainable after the Maven multi-module migration. The process uses the SDD Toolkit's `sdd-analyze-dead-code` component skill directly (not the `sdd-cleanup` orchestrator, which is restricted in Full SDD workflows) to identify unreferenced classes, methods, and fields across all 5 Maven modules (~766 Java files). Candidates are classified by confidence level, filtered against exclusion rules (entry points, JPF native peers, test files), and presented for user approval before any deletion occurs. After removal, the test suite is run to verify no regressions, and the Neo4j knowledge graph is re-extracted to reflect the cleaned codebase.

### Confidence Classification

Dead code candidates are classified into three tiers based on reference analysis:

| Confidence | Criteria | Action |
|-----------|----------|--------|
| **High** | Zero external references AND not an entry point AND not a framework lifecycle method | Recommend removal |
| **Medium** | Test-only usage, single reference from closely related code, or possible dynamic dispatch target | Present for review with context |
| **Low** | 2-3 references from closely related classes, or ambiguous usage patterns | Present for review, default to keep |

### Exclusion Rules

The following categories SHALL NOT appear as dead code candidates:

- **Entry points**: Classes containing `public static void main(String[])` methods
- **JPF native peers**: Classes whose simple name matches the pattern `JPF_*` (e.g., `JPF_gov_nasa_jpf_symbc_Debug`). These are loaded by JPF's native peer mechanism via reflection and will never have static references in application code.
- **Test files**: Files in `jpf-symbc-tests/` are excluded as candidates but ARE scanned as reference sources (they may be the only callers of production code)
- **Example files**: Files in `jpf-symbc-examples/` are excluded as candidates but ARE scanned as reference sources

### Subagent Orchestration

| Step | Subagent | Skill | Purpose |
|------|----------|-------|---------|
| 2.1 | **A2a** | `/sdd-analyze-dead-code` | Dead code detection (candidates with confidence levels) |
| 2.2 | Main context | (no skill) | Present candidates to user for approval |
| 2.3 | **A2b** | Manual removal + `/sdd-test-run` | Remove approved candidates, verify tests pass |
| 2.4 | **A3** | `/sdd-extract` | Re-extract Neo4j graph after code removal |

Dead code orchestration uses component skills directly (not `sdd-cleanup` orchestrator, which is restricted in Full SDD workflows).

## Data Contracts

### Input

- **Source files**: All `.java` files across 5 Maven modules (scanned for references)
- **Neo4j knowledge graph**: Fresh graph from Phase 0 extraction (Unit, Callable, Member nodes with dependency edges)
- **Maven build**: `mvn test` must pass before cleanup begins (baseline)

### Output

- **Candidate report**: List of dead code candidates with confidence level, file path, element type (class/method/field), and reference count
- **Removal log**: List of files/elements actually removed (after user approval)
- **Verification result**: `mvn test` pass/fail status after removal

### Side Effects

- Source files modified or deleted (dead code removed)
- Neo4j graph becomes stale after deletion (requires re-extraction in step 2.2)
- Git working tree has uncommitted changes (removal + any cascading fixes)

## Invariants

- **INV-DC-01**: User approval MUST be obtained before any dead code is deleted. The main context SHALL present the candidate list (from subagent A2a) and wait for explicit confirmation. No automated deletion without human review.
- **INV-DC-02**: After dead code removal, `mvn test` MUST pass with all 20 tests succeeding. If any test fails, the removal that caused the failure SHALL be reverted before proceeding.
- **INV-DC-03**: Entry points (classes containing `public static void main(String[])`) SHALL be excluded from dead code candidates regardless of their reference count.
- **INV-DC-04**: JPF native peer classes (classes whose simple name matches `JPF_*`) SHALL be excluded from dead code candidates. These classes are loaded dynamically by JPF's native peer resolution mechanism and will have zero static references in normal code.
- **INV-DC-05**: After dead code cleanup completes (step 2.1), the Neo4j knowledge graph SHALL be re-extracted (step 2.2) to reflect the cleaned codebase. The graph MUST NOT remain in a state that references deleted files or elements.

## Requirements

### Requirement: Dead Code Detection via SDD Toolkit (DC-01)

Dead code detection SHALL use the `sdd-analyze-dead-code` component skill directly (not the `sdd-cleanup` orchestrator, which is restricted in Full SDD workflows). The skill queries the Neo4j knowledge graph for units and callables with zero or low inbound dependency edges, cross-references against the filesystem, and produces a classified candidate list.

#### Scenario: Full Detection Run

- **WHEN** subagent A2a invokes `/sdd-analyze-dead-code` on the project
- **THEN** `sdd-analyze-dead-code` scans all 5 Maven modules for unreferenced code elements
- **AND** each candidate is classified as High, Medium, or Low confidence
- **AND** the candidate list includes file path, element name, element type, confidence level, and reference count

#### Scenario: No Dead Code Found

- **WHEN** `sdd-analyze-dead-code` completes and finds zero candidates above the Low threshold
- **THEN** the cleanup process terminates with a "no dead code found" summary
- **AND** no files are modified
- **AND** the re-extraction step (A3) still runs to confirm graph freshness

### Requirement: Confidence Classification (DC-02)

Each dead code candidate SHALL be classified into exactly one confidence tier (High, Medium, or Low) based on its reference profile. The classification determines the default recommendation shown to the user.

#### Scenario: High Confidence Candidate

- **WHEN** a class or method has zero inbound references across all modules
- **AND** it does not contain a `public static void main(String[])` method
- **AND** its class name does not match the pattern `JPF_*`
- **THEN** it SHALL be classified as High confidence
- **AND** the recommendation SHALL be "remove"

#### Scenario: Medium Confidence Candidate

- **WHEN** a class or method has references only from test files (`jpf-symbc-tests/`)
- **OR** it has exactly one reference from a closely related class (same package)
- **OR** it could be a dynamic dispatch target (interface implementation, abstract method override)
- **THEN** it SHALL be classified as Medium confidence
- **AND** the recommendation SHALL be "review" with the reference context shown

#### Scenario: Low Confidence Candidate

- **WHEN** a class or method has 2-3 references from closely related classes
- **OR** its usage pattern is ambiguous (e.g., reflection candidate, serialization hook)
- **THEN** it SHALL be classified as Low confidence
- **AND** the recommendation SHALL be "keep" unless the user explicitly overrides

### Requirement: Entry Point Exclusion (DC-03)

Classes containing `public static void main(String[])` methods SHALL be excluded from dead code candidates. These are program entry points that may be invoked externally and will legitimately have zero or few inbound references in the codebase.

#### Scenario: Main Method Exclusion

- **WHEN** `sdd-analyze-dead-code` encounters a class containing `public static void main(String[] args)`
- **THEN** that class SHALL NOT appear in the candidate list
- **AND** it SHALL be counted in the exclusion summary as "entry point"

#### Scenario: Example Programs with Main Methods

- **WHEN** scanning `jpf-symbc-examples/` and encountering classes with main methods (e.g., `ExSymExe*.java`)
- **THEN** those classes are already excluded as example files (exclusion rule)
- **AND** the entry point exclusion provides a second layer of protection if the example exclusion rule is ever relaxed

### Requirement: JPF Native Peer Exclusion (DC-04)

Classes whose simple name matches the pattern `JPF_*` SHALL be excluded from dead code candidates. JPF loads native peer classes via reflection using a naming convention (`JPF_` prefix + fully qualified target class name with underscores), so these classes will never have static import references.

#### Scenario: Native Peer Exclusion

- **WHEN** `sdd-analyze-dead-code` encounters a class named `JPF_gov_nasa_jpf_symbc_Debug`
- **THEN** that class SHALL NOT appear in the candidate list
- **AND** it SHALL be counted in the exclusion summary as "JPF native peer"

#### Scenario: Non-Peer JPF Prefix Classes

- **WHEN** a class name starts with `JPF` but does not match `JPF_*` (e.g., `JPFRuntime`)
- **THEN** that class SHALL NOT be excluded by this rule
- **AND** it SHALL be evaluated normally by the confidence classification

### Requirement: Test File Handling (DC-05)

Test files in `jpf-symbc-tests/` SHALL be excluded as dead code candidates but SHALL be scanned as reference sources. A production class that is referenced only by test code receives Medium confidence (not High), because test-only usage indicates the class may still serve a testing purpose.

#### Scenario: Test Files as Reference Sources

- **WHEN** `sdd-analyze-dead-code` scans the codebase
- **THEN** all `.java` files in `jpf-symbc-tests/src/test/java/` are scanned for outbound references
- **AND** those references count toward the reference totals of production classes
- **AND** no file from `jpf-symbc-tests/` appears in the candidate list

#### Scenario: Production Class with Test-Only References

- **WHEN** a production class in `jpf-symbc-main/` has references only from `jpf-symbc-tests/`
- **THEN** it SHALL be classified as Medium confidence (not High)
- **AND** the user review context SHALL indicate "referenced only by test code"

### Requirement: User Approval Before Deletion (DC-06)

User approval MUST be obtained before any dead code is deleted. The main context SHALL present the full candidate list (from subagent A2a, grouped by confidence level), wait for the user to confirm, reject, or modify the list, and only then dispatch subagent A2b to proceed with deletion.

#### Scenario: User Approves All High-Confidence Candidates

- **WHEN** the candidate list is presented to the user
- **AND** the user approves all High-confidence candidates
- **THEN** only the approved High-confidence candidates are removed
- **AND** Medium and Low candidates are retained unless explicitly approved

#### Scenario: User Rejects All Candidates

- **WHEN** the candidate list is presented to the user
- **AND** the user rejects all candidates (decides to keep everything)
- **THEN** no files are modified
- **AND** the process continues to re-extraction (step 2.2) without changes

#### Scenario: User Selectively Approves

- **WHEN** the candidate list is presented to the user
- **AND** the user approves some candidates and rejects others
- **THEN** only the approved candidates are removed
- **AND** rejected candidates are logged as "kept by user decision"

### Requirement: Post-Removal Verification (DC-07)

After dead code removal, `/sdd-test-run` SHALL run to confirm no regressions. This includes `mvn test` (20 tests must pass) and compilation verification (`mvn compile`).

#### Scenario: Clean Removal

- **WHEN** approved dead code candidates are removed
- **AND** `mvn test` is executed
- **THEN** all 20 tests pass
- **AND** `mvn compile` succeeds across all 5 modules
- **AND** the removal is confirmed as safe

#### Scenario: Test Failure After Removal

- **WHEN** approved dead code candidates are removed
- **AND** `mvn test` fails (one or more tests fail)
- **THEN** the most recent removal batch SHALL be investigated
- **AND** the file(s) causing the failure SHALL be restored
- **AND** `mvn test` SHALL be re-run to confirm restoration fixes the failure
- **AND** the restored file(s) are reclassified as "false positive" in the removal log

### Requirement: Post-Cleanup Graph Re-Extraction (DC-08)

After dead code cleanup completes, the Neo4j knowledge graph SHALL be re-extracted to reflect the cleaned codebase. Subagent A3 runs `/sdd-extract` to replace the stale graph data.

#### Scenario: Successful Re-Extraction After Removal

- **WHEN** dead code removal is complete and verified (step 2.1)
- **THEN** subagent A3 invokes `/sdd-extract` on the project root
- **AND** the Neo4j graph is updated with the post-cleanup file set
- **AND** deleted files no longer appear as nodes in the graph

#### Scenario: Re-Extraction After No Removal

- **WHEN** the user rejects all candidates or no candidates are found
- **THEN** subagent A3 still invokes `/sdd-extract`
- **AND** the graph remains consistent with the filesystem (no stale references)
