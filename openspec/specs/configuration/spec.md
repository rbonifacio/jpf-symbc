# Specification: Configuration

## Purpose

JPF-SymBC uses a layered property-file configuration system inherited from JPF. Configuration controls which methods are executed symbolically, which solver is used, which listeners are attached, and how the JPF runtime locates classes and native code. The configuration system preserves all property names, semantics, and the 3-layer structure (`site.properties` -> `jpf.properties` -> `*.jpf`). Path values reference Maven output directories (`jpf-symbc-tests/target/test-classes`, `jpf-symbc-examples/target/classes`, `jpf-symbc-main/target/classes`).

The 152 `.jpf` configuration files in `src/tests/` (34) and `src/examples/` (118) are located in Maven resource directories (`jpf-symbc-tests/src/test/resources/` and `jpf-symbc-examples/src/main/resources/`). Two additional `.jpf` files outside these directories (`src/main/gov/nasa/jpf/symbc/concolic/TestMain.jpf` and `doc/Example.jpf`) require manual handling. All `.jpf` file `classpath` and `sourcepath` properties reference Maven output directories.

`jpf.properties` at the project root uses Maven paths for `jpf-symbc.native_classpath`, `jpf-symbc.classpath`, and `jpf-symbc.test_classpath`. **Note**: `jpf-symbc.sourcepath` does NOT exist in `jpf.properties` -- it is NOT added during migration. All non-path properties (`jvm.insn_factory.class`, `vm.storage.class`, `peer_packages`, symbolic execution settings) remain unchanged.

### Configuration Layers

```
~/.jpf/site.properties          <- Machine-level: project paths, extensions list
    |
jpf.properties (project root)   <- Extension-level: classpaths, default settings
    |
*.jpf (per-target)               <- Run-level: target class, symbolic methods, solver
```

### site.properties (Machine-Level)

Located at `~/.jpf/site.properties`. Defines project locations and extension registration:

```properties
jpf-core = /path/to/jpf-core
jpf-symbc = /path/to/jpf-symbc
extensions=${jpf-core},${jpf-symbc}
```

This file is NOT part of the repository -- it is created manually per installation.

### jpf.properties (Extension-Level)

Located at the project root. Defines how jpf-symbc integrates with JPF:

```properties
jpf-symbc = ${config_path}

# Native classpath -- JARs/classes loaded in the host JVM (solvers, main code)
jpf-symbc.native_classpath=\
  ${jpf-symbc}/jpf-symbc-main/target/classes;\
  ${jpf-symbc}/jpf-symbc-annotations/target/classes;\
  ${jpf-symbc}/repo/com/microsoft/z3/4.8.14/z3-4.8.14.jar;\
  ... (all solver JARs from repo/ or Maven Central)

# JPF classpath -- classes executed inside JPF
jpf-symbc.classpath=\
  ${jpf-symbc}/jpf-symbc-classes/target/classes

# Test classpath
jpf-symbc.test_classpath=\
  ${jpf-symbc}/jpf-symbc-tests/target/test-classes

# Peer package registration
jpf-symbc.peer_packages = gov.nasa.jpf.symbc

# Default symbolic execution settings
jvm.insn_factory.class=gov.nasa.jpf.symbc.SymbolicInstructionFactory
vm.storage.class=nil
```

Key path patterns used:
- `${jpf-symbc}/jpf-symbc-*/target/classes` -- compiled module classes
- `${jpf-symbc}/repo/.../*.jar` -- solver JARs from project-local Maven repository
- `${jpf-symbc}/jpf-symbc-tests/target/test-classes` -- compiled test classes

**Note**: There is no `jpf-symbc.sourcepath` property in `jpf.properties`. Source paths for debugging are specified per `.jpf` file via the `sourcepath` property.

### .jpf Files (Run-Level)

Each `.jpf` file configures a single JPF execution. Located in:
- `jpf-symbc-tests/src/test/resources/**/*.jpf` (34 files)
- `jpf-symbc-examples/src/main/resources/**/*.jpf` (118 files)

Standard structure:

```properties
# Class resolution
classpath=${jpf-symbc}/jpf-symbc-tests/target/test-classes   # or jpf-symbc-examples/target/classes
sourcepath=${jpf-symbc}/jpf-symbc-tests/src/test/java        # or jpf-symbc-examples/src/main/java

# Target
target=gov.nasa.jpf.symbc.ExampleClass

# Symbolic execution configuration
symbolic.method = gov.nasa.jpf.symbc.ExampleClass.method(sym#sym)
symbolic.dp = z3                            # decision procedure / solver
symbolic.minint = -100
symbolic.maxint = 100
symbolic.undefined = -1000

# Listeners
listener = gov.nasa.jpf.symbc.SymbolicListener

# JPF runtime
vm.storage.class = nil                      # disable state matching
```

### Configuration Properties Reference

**Symbolic execution:**

| Property | Description | Example Values |
|----------|-------------|---------------|
| `symbolic.method` | Methods to execute symbolically. Arguments annotated with `sym` (symbolic) or `con` (concrete). `#` separates parameters. | `pkg.Class.method(sym#sym)` |
| `symbolic.dp` | Decision procedure (solver) | `z3`, `choco`, `coral`, `cvc3`, `no_solver` |
| `symbolic.lazy` | Enable lazy initialization for objects | `true`, `false` |
| `symbolic.lazy.subtypes` | Include subtypes in lazy initialization | `true`, `false` |
| `symbolic.minint` | Minimum value for symbolic integers | `-100` |
| `symbolic.maxint` | Maximum value for symbolic integers | `100` |
| `symbolic.undefined` | Value for undefined symbolic results | `-1000` |
| `symbolic.debug` | Enable debug output | `true`, `false` |
| `symbolic.green` | Use Green solver framework | `true`, `false` |
| `symbolic.string_dp` | String decision procedure | `z3str2`, `ABC` |
| `symbolic.string_dp_timeout_ms` | String solver timeout | `3000` |

**JPF runtime:**

| Property | Description | Required Value |
|----------|-------------|---------------|
| `jvm.insn_factory.class` | Bytecode instruction factory | `gov.nasa.jpf.symbc.SymbolicInstructionFactory` |
| `vm.storage.class` | State storage (must be nil for symbolic execution) | `nil` |
| `listener` | Event listener class | `gov.nasa.jpf.symbc.SymbolicListener` (or alternatives) |

**Listener variants:**
- `gov.nasa.jpf.symbc.SymbolicListener` -- primary, method summaries
- `gov.nasa.jpf.symbc.SymbolicListener2` -- alternative
- `gov.nasa.jpf.symbc.HeuristicListener` -- heuristic-based
- `gov.nasa.jpf.symbc.GreenListener` -- Green solver integration
- `gov.nasa.jpf.symbc.heap.HeapSymbolicListener` -- heap/lazy initialization

**Path properties in .jpf files:**

| Property | Pattern | Used In |
|----------|---------|---------|
| `classpath` | `${jpf-symbc}/jpf-symbc-tests/target/test-classes` or `${jpf-symbc}/jpf-symbc-examples/target/classes` | All .jpf files |
| `sourcepath` | `${jpf-symbc}/jpf-symbc-tests/src/test/java` or `${jpf-symbc}/jpf-symbc-examples/src/main/java` | All .jpf files |
| `native_classpath` | Various -- some reference `${jpf-symbc}/jpf-symbc-main/target/classes`, some use absolute paths | Some .jpf files |

## Data Contracts

### Input

- `~/.jpf/site.properties` -- machine-level project paths
- `jpf.properties` -- extension-level classpath and defaults
- `*.jpf` -- per-target execution configuration

### Output

- JPF runtime configuration controlling symbolic execution behavior

### Side Effects

- None (configuration is read-only, consumed by JPF at startup)

## Invariants

- **INV-CFG-01**: `jvm.insn_factory.class` MUST be set to `gov.nasa.jpf.symbc.SymbolicInstructionFactory` for symbolic execution to function
- **INV-CFG-02**: `vm.storage.class` MUST be set to `nil` to disable state matching during symbolic execution
- **INV-CFG-03**: `classpath` in test `.jpf` files MUST point to `${jpf-symbc}/jpf-symbc-tests/target/test-classes`
- **INV-CFG-04**: `classpath` in example `.jpf` files MUST point to `${jpf-symbc}/jpf-symbc-examples/target/classes`
- **INV-CFG-05**: `symbolic.method` MUST use the format `fully.qualified.Class.method(sym#sym#con)` with `#` as parameter separator
- **INV-CFG-06**: `jpf-symbc.native_classpath` MUST include Maven module output directories (`jpf-symbc-main/target/classes`, `jpf-symbc-annotations/target/classes`) and solver JARs (from `repo/` or `lib/`)
- **INV-CFG-07**: `jpf-symbc.classpath` MUST include `${jpf-symbc}/jpf-symbc-classes/target/classes`
- **INV-CFG-08**: `jpf-symbc.peer_packages` MUST include `gov.nasa.jpf.symbc` for native peer discovery
- **INV-CFG-09**: `.jpf` file path properties MUST use `${jpf-symbc}` variable for portability (not absolute paths)
- **INV-CFG-10**: After path migration, zero `.jpf` files MUST contain references to `build/tests` or `build/examples` (verified via `grep -rl 'build/tests\|build/examples'`)
- **INV-CFG-12**: `jpf-symbc.test_classpath` MUST reference `${jpf-symbc}/jpf-symbc-tests/target/test-classes`
- **INV-CFG-13**: `jpf-symbc.sourcepath` does NOT exist in the current `jpf.properties` and MUST NOT be added during migration. Source paths for debugging are specified per `.jpf` file via the `sourcepath` property, not at the extension level.

## Requirements

### Requirement: JPF Extension Registration (FR08)

jpf-symbc MUST register itself as a JPF extension via `jpf.properties` with correct classpaths pointing to Maven artifact locations.

#### Scenario: Extension Loading

- **WHEN** JPF loads extensions from `site.properties`
- **AND** `jpf-symbc` path is listed in `extensions`
- **THEN** JPF reads `${jpf-symbc}/jpf.properties`
- **AND** `jpf-symbc.native_classpath` includes `${jpf-symbc}/jpf-symbc-main/target/classes`
- **AND** `jpf-symbc.native_classpath` includes `${jpf-symbc}/jpf-symbc-annotations/target/classes`
- **AND** `jpf-symbc.native_classpath` includes all solver JARs (from `repo/` paths)
- **AND** `jpf-symbc.classpath` includes `${jpf-symbc}/jpf-symbc-classes/target/classes`

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

The configuration system MUST allow selecting any supported solver backend via `symbolic.dp`. This requirement is unchanged -- only the underlying JAR resolution mechanism changes (from `lib/` to Maven dependencies).

#### Scenario: Solver Configuration

- **WHEN** `symbolic.dp=<solver>` is set in a `.jpf` file
- **THEN** the corresponding solver backend is used for constraint solving
- **AND** the solver's JAR(s) MUST be on `jpf-symbc.native_classpath` (now referencing `repo/` or Maven Central artifact paths)
- **AND** for JNI-based solvers, native libraries in `lib/64bit/` MUST be loadable
