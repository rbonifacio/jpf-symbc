# Specification: Code Documentation (Javadoc)

## Purpose

This capability defines the generation of Javadoc comments for Java source files across the jpf-symbc project. The scope covers all public classes and methods in core packages of `jpf-symbc-main` (~342 files), `jpf-symbc-annotations` (4 files), and `jpf-symbc-classes` (9 files) -- approximately 355 files total. Javadocs provide API-level documentation that enables developers to understand class purpose, method contracts, parameters, return values, and exceptions without reading implementation details.

Javadoc generation is performed by 15 subagent invocations (C1-C15) organized into 5 waves of 3 parallel subagents each. Each subagent processes a maximum of 30 files to avoid context window overflow. Existing substantive documentation is preserved; only undocumented or stub-documented symbols receive new Javadoc comments.

### Symbol Classification

Before generating Javadoc for a file, each public symbol (class, method, field) is classified:

| Classification | Criteria | Action |
|---------------|----------|--------|
| **Undocumented** | No Javadoc comment present | Generate Javadoc |
| **Stub** | Has `/** */` or single-line `/** ... */` with no meaningful content (e.g., auto-generated, copy-paste of method name) | Replace with substantive Javadoc |
| **Substantive** | Has multi-line Javadoc with meaningful description | Preserve as-is (do NOT overwrite) |
| **Private** | `private` visibility with trivial implementation | Skip (MAY document if non-trivial) |
| **Trivial** | Getter/setter with no logic, toString(), hashCode() with standard implementation | Skip |

### Subagent Execution Model

5 waves, 3 parallel subagents per wave, max 30 files per subagent:

| Wave | Subagent | Target | Files |
|------|----------|--------|-------|
| 4.1 | C1 | `symbc/` root (13 files) | 13 |
| 4.1 | C2 | `jpf-symbc-annotations/` (4) + `jpf-symbc-classes/src/main/java/` (5) + `jpf-symbc-classes/src/main/modules/` (4) | 13 |
| 4.1 | C3 | `symbc/numeric/` root (30 files) | 30 |
| 4.2 | C4 | `symbc/numeric/solvers/` (22) + `symbc/numeric/visitors/` (1) | 23 |
| 4.2 | C5 | `symbc/heap/` (5) + `symbc/arrays/` (9) + `symbc/concolic/` (6) + `symbc/sequences/` (2) | 22 |
| 4.2 | C6 | `symbc/tree/` (3) + `symbc/tree/visualizer/` (3) + `symbc/mixednumstrg/` (3) + `symbc/abstraction/` (2) + `edu/ucsb/cs/vlab/` (16) | 27 |
| 4.3 | C7 | `symbc/bytecode/` files A-F | ~25 |
| 4.3 | C8 | `symbc/bytecode/` files G-I | ~25 |
| 4.3 | C9 | `symbc/bytecode/` files IF-N | ~25 |
| 4.4 | C10 | `symbc/bytecode/` files O-Z | ~27 |
| 4.4 | C11 | `symbc/bytecode/optimization/` (17) + `symbc/bytecode/optimization/util/` (2) | 19 |
| 4.4 | C12 | `symbc/bytecode/symarrays/` | 19 |
| 4.5 | C13 | `symbc/string/` root | 27 |
| 4.5 | C14 | `symbc/string/graph/` | 30 |
| 4.5 | C15 | `symbc/string/translate/` (26) + `symbc/string/testing/` (4) | 30 |

## Data Contracts

### Input

- **Java source files**: ~355 files across `jpf-symbc-main/`, `jpf-symbc-annotations/`, `jpf-symbc-classes/`
- **Neo4j knowledge graph**: For understanding class relationships and dependencies (read-only during this phase)

### Output

- **Modified Java source files**: Same files with added or improved `/** */` Javadoc comments
- **No new files created**: Javadocs are added in-place to existing `.java` files

### Side Effects

- Java source files are modified (Javadoc comments added/improved)
- No changes to build files, configuration, or non-Java files
- Compilation MUST still succeed after each wave (`mvn compile`)

## Invariants

- **INV-COD-01**: Each subagent invocation SHALL process a maximum of 30 Java source files. Batches exceeding 30 files MUST be split across multiple subagent invocations. This constraint prevents context window overflow (~3000 tokens per file for read + classify + edit = ~90K tokens at 30 files, within the ~100K safe limit of the ~200K subagent context window).

- **INV-COD-02**: Existing substantive Javadoc comments SHALL be preserved and MUST NOT be overwritten, shortened, or modified. A Javadoc comment is "substantive" if it contains a multi-line description with meaningful content beyond the method/class name. When in doubt, the comment SHALL be classified as substantive and left unchanged.

- **INV-COD-03**: Generated Javadoc comments SHALL follow standard Java conventions: `/** */` block comment format with `@param` tags for all parameters, `@return` tag for non-void methods, and `@throws` (or `@exception`) tags for declared checked exceptions. Class-level Javadoc SHALL include a one-sentence summary followed by a detailed description when the class has non-trivial behavior.

- **INV-COD-04**: Javadoc generation SHALL NOT modify any functional code. Changes are restricted to comment blocks (`/** */`). No method signatures, import statements, class declarations, field declarations, or method bodies SHALL be altered. If a subagent encounters a file requiring functional changes, it SHALL skip the file and report it.

- **INV-COD-05**: `mvn compile` MUST pass after each wave of subagent invocations completes. If compilation fails after a wave, the wave's changes MUST be reviewed and corrected before proceeding to the next wave. This ensures that Javadoc additions do not introduce syntax errors (e.g., unclosed comments, malformed tags).

## Requirements

### Requirement: Javadoc Coverage for Core Packages (COD-01)

Javadoc comments SHALL be generated for all public classes and public/protected methods in the core packages of `jpf-symbc-main`, plus all public classes in `jpf-symbc-annotations` and `jpf-symbc-classes`. The target is approximately 355 Java source files.

Core packages in `jpf-symbc-main` (all under `gov.nasa.jpf.symbc`):

| Package | Files | Description |
|---------|-------|-------------|
| `symbc/` (root) | 13 | Listeners, instruction factory, configuration |
| `symbc/bytecode/` | 102 | Symbolic bytecode instructions (root) |
| `symbc/bytecode/optimization/` | 17 | Optimized bytecode variants |
| `symbc/bytecode/optimization/util/` | 2 | Optimization utilities |
| `symbc/bytecode/symarrays/` | 19 | Symbolic array bytecodes |
| `symbc/numeric/` | 30 | Constraints, expressions, path conditions (root) |
| `symbc/numeric/solvers/` | 22 | Solver backend integrations |
| `symbc/numeric/visitors/` | 1 | Expression visitors |
| `symbc/string/` | 27 | String symbolic execution (root) |
| `symbc/string/graph/` | 30 | String constraint graph |
| `symbc/string/translate/` | 26 | Solver translators (Z3-str2, ABC) |
| `symbc/string/testing/` | 4 | String testing utilities |
| `symbc/heap/` | 5 | Symbolic heap / lazy initialization |
| `symbc/arrays/` | 9 | Symbolic array modeling |
| `symbc/concolic/` | 6 | Hybrid concrete-symbolic execution |
| `symbc/sequences/` | 2 | Sequence-based testing |
| `symbc/tree/` | 3 | Tree structures |
| `symbc/tree/visualizer/` | 3 | DOT visualization listeners |
| `symbc/mixednumstrg/` | 3 | Mixed numeric-string constraints |
| `symbc/abstraction/` | 2 | Abstraction support |
| `edu/ucsb/cs/vlab/` (+ subpackages) | 15 | Z3 string solver integration (UCSB vlab) |
| `vlab/cs/ucsb/edu/` | 1 | Z3 driver proxy |

#### Scenario: Undocumented Class Receives Javadoc

- **WHEN** a subagent processes a Java source file containing a public class with no Javadoc comment
- **THEN** a `/** */` class-level Javadoc block is added immediately before the class declaration
- **AND** the Javadoc contains a one-sentence summary describing the class purpose
- **AND** if the class has non-trivial behavior, a detailed description paragraph follows the summary
- **AND** the functional code of the class is unchanged

#### Scenario: Undocumented Method Receives Javadoc

- **WHEN** a subagent processes a public or protected method with no Javadoc comment
- **THEN** a `/** */` method-level Javadoc block is added immediately before the method declaration
- **AND** the Javadoc contains `@param` tags for every parameter
- **AND** the Javadoc contains a `@return` tag if the method is non-void
- **AND** the Javadoc contains `@throws` tags for each declared checked exception
- **AND** parameter descriptions are meaningful (not just the parameter name repeated)

#### Scenario: Stub Documentation Is Improved

- **WHEN** a subagent processes a class or method with stub Javadoc (e.g., `/** TODO */`, `/** Auto-generated */`, or `/** methodName */`)
- **THEN** the stub Javadoc is replaced with a substantive Javadoc comment
- **AND** the replacement follows the same conventions as for undocumented symbols (COD-01)

#### Scenario: Substantive Documentation Is Preserved

- **WHEN** a subagent processes a class or method that already has substantive Javadoc
- **THEN** the existing Javadoc comment is left unchanged
- **AND** no tags are added, removed, or modified within the existing comment

#### Scenario: Private and Trivial Members Are Skipped

- **WHEN** a subagent processes a private method with trivial implementation (getter, setter, delegation)
- **THEN** no Javadoc is generated for that method
- **AND** the subagent reports the skip in its output summary

### Requirement: Batched Subagent Execution (COD-02)

Javadoc generation SHALL be executed in 5 waves of 3 parallel subagents each. Each subagent processes a disjoint set of files (no overlap between subagents within a wave or across waves). The main context acts as orchestrator and does not process files directly.

#### Scenario: Wave Execution

- **WHEN** a wave of 3 subagents (e.g., C1, C2, C3 in wave 4.1) is dispatched
- **THEN** all 3 subagents execute in parallel on disjoint file sets
- **AND** each subagent processes at most 30 files (per INV-COD-01)
- **AND** the main context waits for all 3 subagents to complete before starting the next wave
- **AND** `mvn compile` is verified after the wave completes (per INV-COD-05)

#### Scenario: Subagent Reports Results

- **WHEN** a subagent completes its file batch
- **THEN** it reports: files processed (count), files modified (count), files skipped (count with reasons), and any issues encountered
- **AND** the main context aggregates these reports across all subagents in the wave

#### Scenario: Compilation Check Between Waves

- **WHEN** wave N completes and all 3 subagents have reported success
- **THEN** `mvn compile` is executed on the full project
- **AND** if compilation succeeds, wave N+1 is dispatched
- **AND** if compilation fails, the failing changes are identified and corrected before proceeding

### Requirement: Bytecode Package Splitting (COD-03)

The `symbc/bytecode/` root package contains 102 Java files, which exceeds the 30-file-per-subagent limit. These files SHALL be split alphabetically across 4 subagent invocations (C7, C8, C9, C10) spanning waves 4.3 and 4.4.

#### Scenario: Alphabetical Split of Bytecode Root

- **WHEN** the bytecode root package (102 files) is prepared for documentation
- **THEN** files are split into 4 alphabetical groups of approximately 25 files each
- **AND** each group is assigned to a separate subagent (C7: A-F, C8: G-I, C9: IF-N, C10: O-Z)
- **AND** no file appears in more than one group
- **AND** every file in the bytecode root appears in exactly one group

#### Scenario: Bytecode Subpackages as Separate Batches

- **WHEN** `symbc/bytecode/optimization/` (17 files), `symbc/bytecode/optimization/util/` (2 files), and `symbc/bytecode/symarrays/` (19 files) are documented
- **THEN** `optimization/` and `optimization/util/` are combined into one subagent batch (C11, 19 files)
- **AND** `symarrays/` is a separate subagent batch (C12, 19 files)
- **AND** neither batch exceeds 30 files

### Requirement: Annotation and Model Class Documentation (COD-04)

The `jpf-symbc-annotations` module (4 files) and `jpf-symbc-classes` module (5 files in `src/main/java/` + 4 files in `src/main/modules/` = 9 files) SHALL receive Javadoc documentation. These are combined into a single subagent batch (C2, 13 files) since both are small modules.

#### Scenario: Annotation Class Documentation

- **WHEN** subagent C2 processes the 4 files in `jpf-symbc-annotations/src/main/java/`
- **THEN** each annotation class receives a class-level Javadoc describing its retention policy, target, and intended usage
- **AND** annotation elements (methods in the annotation interface) receive `@return` tags describing their default values and purpose

#### Scenario: Model Class Documentation

- **WHEN** subagent C2 processes the 5 files in `jpf-symbc-classes/src/main/java/` (Debug, TestPC, DNN, TestUtils, Verifier) and the 4 files in `jpf-symbc-classes/src/main/modules/` (Math, Scanner, BufferedImage, Kernel)
- **THEN** each model class receives a class-level Javadoc explaining that it is a JPF model class (executed inside the JPF VM, not on the host JVM)
- **AND** the Javadoc explains which standard library class it models (e.g., `java.lang.Math`, `java.util.Scanner`)
- **AND** for classes in `src/main/modules/java.base/` and `src/main/modules/java.desktop/`, the Javadoc notes the `--patch-module` compilation requirement

### Requirement: No Functional Code Changes (COD-05)

Javadoc generation SHALL NOT alter any functional code. This requirement ensures that the documentation phase cannot introduce runtime regressions.

#### Scenario: Code Integrity Verification

- **WHEN** all 5 waves of Javadoc generation are complete
- **THEN** `mvn compile` passes without errors
- **AND** `mvn test` passes with the same 20 tests passing as before documentation began
- **AND** a `git diff --stat` shows only `.java` files modified
- **AND** a `git diff` shows changes only within `/** */` comment blocks (no changes to code lines)

#### Scenario: File Requiring Code Changes Is Skipped

- **WHEN** a subagent encounters a file where generating proper Javadoc would require modifying functional code (e.g., adding a `throws` clause to match documentation)
- **THEN** the subagent skips the file
- **AND** reports it as "skipped: requires functional code change" in its output
- **AND** the file is logged for manual review
