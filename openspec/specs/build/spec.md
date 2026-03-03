# Specification: Build System

## Purpose

The jpf-symbc build system compiles 765 Java source files from 6 source roots into 3 JAR artifacts using Apache Ant. The build enforces Java 8 source/target level and manages compilation ordering to satisfy inter-root dependencies. The `build.xml` is the single build definition — there are no Gradle, Maven, or IDE-specific build configurations in active use.

### Source Roots and Compilation Order

```
src/annotations  (4 files)    ← compiled first, no dependencies
       ↓
src/main         (335 files)  ← depends on: annotations, jpf-core
src/peers        (7 files)    ← depends on: jpf-core
src/classes      (9 files)    ← depends on: annotations, jpf-core (NOT src/main)
       ↓
src/tests        (197 files)  ← depends on: annotations, main, jpf-core, JUnit 4
src/examples     (213 files)  ← depends on: annotations, main
```

The compilation order is enforced via Ant target dependencies:
- `-compile-annotations` runs first (no deps)
- `-compile-main` depends on `-compile-annotations`
- `-compile-peers` depends on `-compile-main`
- `-compile-classes` depends on `-compile-annotations`, `-compile-main`
- `-compile-tests` depends on `-compile-annotations`, `-compile-main`
- `-compile-examples` depends on `-compile-annotations`, `-compile-main`

### Build Outputs

Each source root compiles into a separate output directory under `build/`:

| Source Root | Output Directory |
|-------------|-----------------|
| src/annotations | build/annotations |
| src/main | build/main |
| src/peers | build/peers |
| src/classes | build/classes |
| src/tests | build/tests |
| src/examples | build/examples |

Three JAR files are produced from these outputs:

| JAR | Contents | Source |
|-----|----------|--------|
| `build/jpf-symbc.jar` | Main JVM code | build/main + build/peers |
| `build/jpf-symbc-classes.jar` | Model classes + annotations | build/classes + build/annotations |
| `build/jpf-symbc-annotations.jar` | Annotations only | build/annotations |

## Data Contracts

### Input

- **Source files**: Java 8 source code in 6 source roots under `src/`
- **jpf-core**: Peer directory (`../jpf-core`) or path from `~/.jpf/site.properties`
- **Library JARs**: 28 JARs in `lib/` directory
- **JUnit**: `${JUNIT_HOME}/junit.jar` environment variable (test compilation only)

### Output

- **Compiled classes**: 6 directories under `build/`
- **JAR artifacts**: 3 JARs in `build/`

### Side Effects

- `build/` directory is created/populated on compile
- `clean` target removes `build/` entirely

## Invariants

- **INV-BLD-01**: All source MUST compile with Java 8 source/target level (`src_level = 8`)
- **INV-BLD-02**: `build/jpf-symbc.jar` MUST contain classes from both `src/main` and `src/peers`
- **INV-BLD-03**: `build/jpf-symbc-classes.jar` MUST contain classes from both `src/classes` and `src/annotations`
- **INV-BLD-04**: `build/jpf-symbc-annotations.jar` MUST contain classes from `src/annotations` only
- **INV-BLD-05**: `src/classes` MUST NOT depend on `src/main` (verified: 0 imports)
- **INV-BLD-06**: `src/annotations` MUST have zero external dependencies
- **INV-BLD-07**: Compilation MUST enable debug symbols (`debug = on`)
- **INV-BLD-08**: Compilation MUST report deprecation warnings (`deprecation = on`)

## Requirements

### Requirement: Compile All Sources (FR01)

The build system MUST compile all 6 source roots in dependency order and produce compiled class files.

#### Scenario: Full Compilation

WHEN `ant compile` is executed
THEN all 6 source roots compile without errors
AND compiled classes are placed in their respective `build/` subdirectories

#### Scenario: Default Build

WHEN `ant build` is executed (or `ant` with no target)
THEN sources are compiled
AND 3 JAR files are produced in `build/`

### Requirement: Test Execution (FR09, FR10)

The build system MUST run JUnit 4 tests with specific configuration and exclusions.

#### Scenario: Test Run

WHEN `ant test` is executed
AND `JUNIT_HOME` environment variable is set
THEN tests are executed with `fork=yes` and `forkmode=perTest`
AND each test JVM has `-Xmx1024m` max memory
AND the following test patterns are excluded:
- `**/TestBitwise*`
- `**/TestCoverage.java`
- `**/TestDIV.java`
- `**/TestExJPF.java`
- `**/TestLazy*`
- `**/TestPathCondition.java`
- `**/TestStringBuilder.java`
- `**/strings/**`
- `**/TestSymbolicListener.java`
- `**/TestSymbolicOutput.java`
- `**/TestSymbolicJPF.java`
- `**/Test$*` (inner test classes)

#### Scenario: ExSymExe Programs Not Executed

WHEN `ant test` is executed
THEN 129 `ExSymExe*.java` files are NOT executed as tests
AND they ARE compiled as part of the test source root

### Requirement: Clean Build (FR01)

#### Scenario: Clean

WHEN `ant clean` is executed
THEN the `build/` directory is removed entirely
AND no compiled classes or JARs remain
