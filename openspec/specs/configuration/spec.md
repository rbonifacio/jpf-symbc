# Specification: Configuration

## Purpose

JPF-SymBC uses a layered property-file configuration system inherited from JPF. Configuration controls which methods are executed symbolically, which solver is used, which listeners are attached, and how the JPF runtime locates classes and native code. There are 154 `.jpf` configuration files in the project (34 in tests, 118 in examples, 1 in `src/main/gov/nasa/jpf/symbc/concolic/`, 1 in `doc/`), plus two infrastructure-level configuration files (`jpf.properties` and `~/.jpf/site.properties`).

### Configuration Layers

```
~/.jpf/site.properties          ← Machine-level: project paths, extensions list
    ↓
jpf.properties (project root)   ← Extension-level: classpaths, default settings
    ↓
*.jpf (per-target)               ← Run-level: target class, symbolic methods, solver
```

### site.properties (Machine-Level)

Located at `~/.jpf/site.properties`. Defines project locations and extension registration:

```properties
jpf-core = /path/to/jpf-core
jpf-symbc = /path/to/jpf-symbc
extensions=${jpf-core},${jpf-symbc}
```

This file is NOT part of the repository — it is created manually per installation.

### jpf.properties (Extension-Level)

Located at the project root. Defines how jpf-symbc integrates with JPF:

```properties
jpf-symbc = ${config_path}

# Native classpath — JARs loaded in the host JVM (solvers, main code)
jpf-symbc.native_classpath=\
  ${jpf-symbc}/build/jpf-symbc.jar;\
  ${jpf-symbc}/build/jpf-symbc-annotations.jar;\
  ${jpf-symbc}/lib/com.microsoft.z3.jar;\
  ... (all 28 solver JARs)

# JPF classpath — classes executed inside JPF
jpf-symbc.classpath=\
  ${jpf-symbc}/build/jpf-symbc-classes.jar

# Test classpath
jpf-symbc.test_classpath=\
  build/tests

# Peer package registration
jpf-symbc.peer_packages = gov.nasa.jpf.symbc

# Default symbolic execution settings
jvm.insn_factory.class=gov.nasa.jpf.symbc.SymbolicInstructionFactory
vm.storage.class=nil
```

Key path patterns used:
- `${jpf-symbc}/build/*.jar` — compiled JAR artifacts
- `${jpf-symbc}/lib/*.jar` — third-party dependencies
- `build/tests` — compiled test classes (relative path, no `${jpf-symbc}` prefix)

**Note**: There is no `jpf-symbc.sourcepath` property in `jpf.properties`. Source paths for debugging are specified per `.jpf` file via the `sourcepath` property.

### .jpf Files (Run-Level)

Each `.jpf` file configures a single JPF execution. Located in:
- `src/tests/**/*.jpf` (34 files)
- `src/examples/**/*.jpf` (118 files)

Standard structure:

```properties
# Class resolution
classpath=${jpf-symbc}/build/tests          # or build/examples
sourcepath=${jpf-symbc}/src/tests           # or src/examples

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
- `gov.nasa.jpf.symbc.SymbolicListener` — primary, method summaries
- `gov.nasa.jpf.symbc.SymbolicListener2` — alternative
- `gov.nasa.jpf.symbc.HeuristicListener` — heuristic-based
- `gov.nasa.jpf.symbc.GreenListener` — Green solver integration
- `gov.nasa.jpf.symbc.heap.HeapSymbolicListener` — heap/lazy initialization

**Path properties in .jpf files:**

| Property | Current Pattern | Used In |
|----------|----------------|---------|
| `classpath` | `${jpf-symbc}/build/tests` or `${jpf-symbc}/build/examples` | All .jpf files |
| `sourcepath` | `${jpf-symbc}/src/tests` or `${jpf-symbc}/src/examples` | All .jpf files |
| `native_classpath` | Various — some reference `${jpf-symbc}/build/*.jar`, some use absolute paths | Some .jpf files |

## Data Contracts

### Input

- `~/.jpf/site.properties` — machine-level project paths
- `jpf.properties` — extension-level classpath and defaults
- `*.jpf` — per-target execution configuration

### Output

- JPF runtime configuration controlling symbolic execution behavior

### Side Effects

- None (configuration is read-only, consumed by JPF at startup)

## Invariants

- **INV-CFG-01**: `jvm.insn_factory.class` MUST be set to `gov.nasa.jpf.symbc.SymbolicInstructionFactory` for symbolic execution to function
- **INV-CFG-02**: `vm.storage.class` MUST be set to `nil` to disable state matching during symbolic execution
- **INV-CFG-03**: `classpath` in test `.jpf` files MUST point to the compiled test classes directory
- **INV-CFG-04**: `classpath` in example `.jpf` files MUST point to the compiled example classes directory
- **INV-CFG-05**: `symbolic.method` MUST use the format `fully.qualified.Class.method(sym#sym#con)` with `#` as parameter separator
- **INV-CFG-06**: `jpf-symbc.native_classpath` MUST include both the jpf-symbc JARs and all solver JARs required at runtime
- **INV-CFG-07**: `jpf-symbc.classpath` MUST include the model classes JAR (jpf-symbc-classes)
- **INV-CFG-08**: `jpf-symbc.peer_packages` MUST include `gov.nasa.jpf.symbc` for native peer discovery
- **INV-CFG-09**: `.jpf` file path properties MUST use `${jpf-symbc}` variable for portability (not absolute paths)

## Requirements

### Requirement: JPF Extension Registration (FR08)

jpf-symbc MUST register itself as a JPF extension via `jpf.properties` with correct classpaths.

#### Scenario: Extension Loading

WHEN JPF loads extensions from `site.properties`
AND `jpf-symbc` path is listed in `extensions`
THEN JPF reads `${jpf-symbc}/jpf.properties`
AND adds `jpf-symbc.native_classpath` entries to the host JVM classpath
AND adds `jpf-symbc.classpath` entries to the JPF model classpath

### Requirement: .jpf File Path Consistency (FR07, NFR03)

All `.jpf` files MUST reference valid paths to compiled classes and source files.

#### Scenario: Test .jpf File

WHEN a test `.jpf` file is loaded
THEN `classpath` resolves to the directory containing compiled test classes
AND `sourcepath` resolves to the directory containing test source files
AND `target` class is found on the resolved classpath

#### Scenario: Example .jpf File

WHEN an example `.jpf` file is loaded
THEN `classpath` resolves to the directory containing compiled example classes
AND `sourcepath` resolves to the directory containing example source files

### Requirement: Solver Selection (NFR01)

The configuration system MUST allow selecting any supported solver backend via `symbolic.dp`.

#### Scenario: Solver Configuration

WHEN `symbolic.dp=<solver>` is set in a `.jpf` file
THEN the corresponding solver backend is used for constraint solving
AND the solver's JAR(s) MUST be on `jpf-symbc.native_classpath`
AND for JNI-based solvers, native libraries MUST be loadable
