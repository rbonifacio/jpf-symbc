## Purpose

The configuration system preserves all property names, semantics, and the 3-layer structure (`site.properties` → `jpf.properties` → `*.jpf`). The only changes are **path values** — all references to Ant build output directories (`build/tests`, `build/examples`, `build/jpf-symbc.jar`) are updated to Maven output directories (`jpf-symbc-tests/target/test-classes`, `jpf-symbc-examples/target/classes`, `jpf-symbc-main/target/jpf-symbc-main-1.0.0-SNAPSHOT.jar`).

The 152 `.jpf` configuration files in `src/tests/` (34) and `src/examples/` (118) move to Maven resource directories (`jpf-symbc-tests/src/test/resources/` and `jpf-symbc-examples/src/main/resources/`). Two additional `.jpf` files outside these directories (`src/main/gov/nasa/jpf/symbc/concolic/TestMain.jpf` and `doc/Example.jpf`) require manual handling. All `.jpf` file `classpath` and `sourcepath` properties are updated via automated sed, followed by mandatory post-verification to catch files with non-standard path patterns.

`jpf.properties` at the project root is updated with new JAR paths for `jpf-symbc.native_classpath`, `jpf-symbc.classpath`, and `jpf-symbc.test_classpath`. **Note**: `jpf-symbc.sourcepath` does NOT exist in the current `jpf.properties` — it is NOT added during migration. All non-path properties (`jvm.insn_factory.class`, `vm.storage.class`, `peer_packages`, symbolic execution settings) remain unchanged.

## MODIFIED Invariants

- **INV-CFG-03**: `classpath` in test `.jpf` files MUST point to `${jpf-symbc}/jpf-symbc-tests/target/test-classes`
- **INV-CFG-04**: `classpath` in example `.jpf` files MUST point to `${jpf-symbc}/jpf-symbc-examples/target/classes`
- **INV-CFG-06**: `jpf-symbc.native_classpath` MUST include Maven module JARs (`jpf-symbc-main/target/*.jar`, `jpf-symbc-annotations/target/*.jar`) and solver JARs (from `repo/` or `lib/`)
- **INV-CFG-07**: `jpf-symbc.classpath` MUST include `${jpf-symbc}/jpf-symbc-classes/target/jpf-symbc-classes-1.0.0-SNAPSHOT.jar`

## ADDED Invariants

- **INV-CFG-10**: After path migration, zero `.jpf` files MUST contain references to `build/tests` or `build/examples` (verified via `grep -rl 'build/tests\|build/examples'`)
- **INV-CFG-13**: `jpf-symbc.sourcepath` does NOT exist in the current `jpf.properties` and MUST NOT be added during migration. Source paths for debugging are specified per `.jpf` file via the `sourcepath` property, not at the extension level. (Note: INV-CFG-11 was originally proposed here but removed during review — this invariant replaces it with a clear affirmative statement.)
- **INV-CFG-12**: `jpf-symbc.test_classpath` MUST reference `${jpf-symbc}/jpf-symbc-tests/target/test-classes`

## MODIFIED Requirements

### Requirement: JPF Extension Registration (FR08)

jpf-symbc MUST register itself as a JPF extension via `jpf.properties` with correct classpaths pointing to Maven artifact locations.

#### Scenario: Extension Loading

- **WHEN** JPF loads extensions from `site.properties`
- **AND** `jpf-symbc` path is listed in `extensions`
- **THEN** JPF reads `${jpf-symbc}/jpf.properties`
- **AND** `jpf-symbc.native_classpath` includes `${jpf-symbc}/jpf-symbc-main/target/jpf-symbc-main-1.0.0-SNAPSHOT.jar`
- **AND** `jpf-symbc.native_classpath` includes `${jpf-symbc}/jpf-symbc-annotations/target/jpf-symbc-annotations-1.0.0-SNAPSHOT.jar`
- **AND** `jpf-symbc.native_classpath` includes all solver JARs (from `repo/` paths)
- **AND** `jpf-symbc.classpath` includes `${jpf-symbc}/jpf-symbc-classes/target/jpf-symbc-classes-1.0.0-SNAPSHOT.jar`

### Requirement: .jpf File Path Consistency (FR07, NFR03)

All `.jpf` files MUST reference valid paths to compiled classes and source files using Maven output directory conventions.

#### Scenario: Test .jpf File

- **WHEN** a test `.jpf` file is loaded from `jpf-symbc-tests/src/test/resources/`
- **THEN** `classpath` resolves to `${jpf-symbc}/jpf-symbc-tests/target/test-classes`
- **AND** `sourcepath` resolves to `${jpf-symbc}/jpf-symbc-tests/src/test/java`
- **AND** `target` class is found on the resolved classpath

#### Scenario: Example .jpf File

- **WHEN** an example `.jpf` file is loaded from `jpf-symbc-examples/src/main/resources/`
- **THEN** `classpath` resolves to `${jpf-symbc}/jpf-symbc-examples/target/classes`
- **AND** `sourcepath` resolves to `${jpf-symbc}/jpf-symbc-examples/src/main/java`

#### Scenario: No Old Path References Remain

- **WHEN** all 154 `.jpf` files have been migrated (152 in test+example dirs + 2 in other locations)
- **THEN** `grep -rl 'build/tests\|build/examples' jpf-symbc-tests/ jpf-symbc-examples/` returns empty
- **AND** `grep -rL 'target/' jpf-symbc-tests/src/test/resources/*.jpf` returns empty (all test .jpf files reference `target/`)
- **AND** `grep -rL 'target/' jpf-symbc-examples/src/main/resources/*.jpf` returns empty (all example .jpf files reference `target/`)

#### Scenario: Non-Standard Path References

- **WHEN** a `.jpf` file contains `native_classpath` with absolute paths or non-standard references
- **THEN** these files are identified via `grep -rl 'native_classpath=.*home\|native_classpath=.*git'`
- **AND** they are reviewed and updated manually

### Requirement: Solver Selection (NFR01)

The configuration system MUST allow selecting any supported solver backend via `symbolic.dp`. This requirement is unchanged — only the underlying JAR resolution mechanism changes (from `lib/` to Maven dependencies).

#### Scenario: Solver Configuration

- **WHEN** `symbolic.dp=<solver>` is set in a `.jpf` file
- **THEN** the corresponding solver backend is used for constraint solving
- **AND** the solver's JAR(s) MUST be on `jpf-symbc.native_classpath` (now referencing `repo/` or Maven Central artifact paths)
- **AND** for JNI-based solvers, native libraries in `lib/64bit/` MUST be loadable
