# Specification: Dependencies

## Purpose

JPF-SymBC depends on jpf-core (the JPF runtime) and 28 third-party JAR files bundled in the `lib/` directory. There is no dependency manager — all JARs are committed directly into the repository. Native libraries for JNI-based solvers reside in `lib/64bit/`. The project resolves jpf-core at build time via `~/.jpf/site.properties` or a peer directory convention.

### jpf-core Dependency

JPF-SymBC currently requires a specific fork of jpf-core:

| Property | Value |
|----------|-------|
| Repository | https://github.com/yannicnoller/jpf-core |
| Commit | 0f2f2901cd0ae9833145c38fee57be03da90a64f |
| Java version | 8 |
| Build system | Ant |
| Alternative fork | https://github.com/corinus/jpf-core |

The official jpf-core (https://github.com/javapathfinder/jpf-core) has migrated to Java 11 with Gradle and publishes artifacts via `./gradlew publishToMavenLocal` with groupId `gov.nasa`.

jpf-core is resolved at build time through:
1. `~/.jpf/site.properties` → `jpf-core = /path/to/jpf-core`
2. Fallback: peer directory `../jpf-core`

The `build.xml` reads `${jpf-core}/jpf.properties` to obtain `jpf-core.native_classpath`.

### Third-Party JARs

28 JARs in `lib/`, categorized by Maven Central availability:

**Available on Maven Central (8 JARs):**

| JAR | Maven Central Coordinates | Verified |
|-----|--------------------------|----------|
| commons-lang-2.4.jar | `commons-lang:commons-lang:2.4` | HTTP 200 |
| commons-math-1.2.jar | `commons-math:commons-math:1.2` | HTTP 200 |
| bcel.jar | `org.apache.bcel:bcel:6.0` | HTTP 200 (exact version unverified — JAR has no manifest) |
| automaton.jar | `dk.brics.automaton:automaton:1.11-8` | HTTP 200 |
| jaxen.jar | `jaxen:jaxen:1.2.0` | HTTP 200 |
| JSAP-2.1.jar | `com.martiansoftware:jsap:2.1` | HTTP 200 |
| aima-core.jar | `com.googlecode.aima-java:aima-core:0.10.5` | HTTP 200 |
| jedis-2.0.0.jar | `redis.clients:jedis:2.0.0` | HTTP 200 |

**NOT on Maven Central — require local repository (20 JARs):**

| JAR | Solver/Purpose |
|-----|---------------|
| org.sat4j.core.jar | SAT4J solver (CUSTOM build v20100705 — NOT on Maven Central; Maven Central has org.sat4j:org.sat4j.core:2.3.1 but different build) |
| org.sat4j.pb.jar | SAT4J pseudo-boolean solver (CUSTOM build v20100705 — same issue) |
| com.microsoft.z3.jar | Z3 SMT solver Java bindings |
| choco-1_2_04.jar | Choco constraint solver v1.2 |
| choco-solver-2.1.1-*.jar | Choco constraint solver v2.1 |
| coral.jar | Coral constraint optimization |
| green.jar | Green unified solver framework |
| hampi.jar | HAMPI string constraint solver |
| iasolver.jar | Interval arithmetic solver |
| string.jar | String constraint solver |
| solver.jar | Generic solver interface |
| scale.jar | Scale solver |
| proteus.jar | Proteus solver |
| Statemachines.jar | State machine support |
| STPJNI.jar | STP solver JNI bindings |
| yicesapijava.jar | Yices solver Java API |
| libcvc3.jar | CVC3 legacy solver |
| libcvc3-5.0.0.jar | CVC3 v5.0.0 solver |
| opt4j-2.4.jar | Opt4J optimization framework (bundles ASM 1.5.3 + CGLIB 2.1_3 — incompatible with Java 11 class files) |
| grappa.jar | Graph visualization |

**Missing JAR (referenced but not in lib/):**
- `PathConditionsReliability-0.0.1.jar` — referenced in `jpf.properties` but not present in `lib/`

### Native Libraries

Native libraries exist in two locations:

**`lib/` root** — 34+ native library files for multiple platforms:

| Library | Platforms | Purpose |
|---------|-----------|---------|
| libcvc3jni.* | .so (4 versions), .dll (4), .dylib (4) | CVC3 JNI bindings |
| libcvc3.* | .so (4 versions), .dll (2), .dylib (4) | CVC3 solver |
| libgmp.* | .dylib | GNU Multiple Precision (CVC3 dependency) |
| libz3.* | .so, .dll, .dylib | Z3 solver core |
| libz3java.* | .so, .dll, .dylib | Z3 Java bindings |
| libSTPJNI.so | .so | STP solver JNI bindings |
| libYicesLite.so | .so | Yices solver (lite variant) |
| libyices.so | .so | Yices solver |

**`lib/64bit/`** — Linux 64-bit specific:

| Library | Versions | Purpose |
|---------|----------|---------|
| libcvc3jni.so | .so, .so.5, .so.5.0, .so.5.0.0 | CVC3 JNI bindings |
| libgmp.so | .so, .so.3 | GNU Multiple Precision (CVC3 dependency) |

Additional native libraries referenced in `jpf.properties` but expected to be installed system-wide:
- `libabc.so` (ABC string solver, expected at `/usr/local/lib/`)

### Solver Backends

| Solver | JAR(s) | Native Lib | Status |
|--------|--------|------------|--------|
| Z3 | com.microsoft.z3.jar | libz3.so, libz3java.so | Primary solver |
| Choco | choco-1_2_04.jar, choco-solver-2.1.1-*.jar | None (pure Java) | Active |
| Coral | coral.jar + opt4j, commons-math, commons-lang | None (pure Java) | Active |
| CVC3 | libcvc3.jar, libcvc3-5.0.0.jar | libcvc3jni.so, libgmp.so | Legacy |
| STP | STPJNI.jar | (system) | Legacy |
| Yices | yicesapijava.jar | (system) | Legacy |
| Green | green.jar | None (framework) | Active |
| HAMPI | hampi.jar | None (pure Java) | Active |
| ABC | (external) | libabc.so | External |

## Data Contracts

### Input

- `~/.jpf/site.properties` — jpf-core path resolution
- `lib/*.jar` — all solver and utility JARs
- `lib/64bit/*.so` — native JNI libraries
- System-installed native libraries (Z3, ABC)

### Output

- Classpath entries for compilation and runtime
- `jpf.properties` → `jpf-symbc.native_classpath` listing all required JARs

### Side Effects

- None (dependencies are static, no download or resolution at build time)

## Invariants

- **INV-DEP-01**: jpf-core MUST be resolvable via `~/.jpf/site.properties` or `../jpf-core` peer directory
- **INV-DEP-02**: All 28 JARs in `lib/` MUST be on the compilation classpath
- **INV-DEP-03**: Z3 native library MUST be loadable for Z3 solver backend to function
- **INV-DEP-04**: CVC3 native libraries (`libcvc3jni.so`, `libgmp.so`) MUST be in `lib/64bit/` for CVC3 backend
- **INV-DEP-05**: `jpf-symbc.native_classpath` in `jpf.properties` MUST list all JARs required at JPF runtime
- **INV-DEP-06**: `src/classes` depends on jpf-core (`gov.nasa.jpf.vm.Verify`) and annotations, NOT on `src/main`
- **INV-DEP-07**: `src/main` and `src/peers` depend on jpf-core but NOT on `src/classes`

## Requirements

### Requirement: jpf-core Resolution (FR11)

The build MUST locate jpf-core and include its classpath for compilation.

#### Scenario: Resolution via site.properties

WHEN `~/.jpf/site.properties` contains `jpf-core = /path/to/jpf-core`
THEN the build reads `${jpf-core}/jpf.properties`
AND adds `${jpf-core.native_classpath}` to the compilation classpath

#### Scenario: Missing jpf-core

WHEN jpf-core cannot be resolved
THEN compilation fails with classpath errors on `gov.nasa.jpf.*` imports

### Requirement: Solver JAR Availability (NFR01)

All solver JARs MUST be available on the classpath for their respective solver backends to function.

#### Scenario: Z3 Solver

WHEN `symbolic.dp=z3` is configured in a `.jpf` file
THEN `com.microsoft.z3.jar` MUST be on the native classpath
AND `libz3.so` and `libz3java.so` MUST be loadable via `java.library.path`

#### Scenario: Pure-Java Solver

WHEN `symbolic.dp=choco` is configured
THEN `choco-1_2_04.jar` MUST be on the native classpath
AND no native libraries are required

### Requirement: Native Library Loading (NFR02)

Native libraries MUST be loadable at runtime for JNI-based solver backends.

#### Scenario: Native Library Path

WHEN JPF runs with a JNI-based solver (Z3, CVC3, STP, Yices)
THEN `java.library.path` MUST include `lib/64bit/` (or system library path)
AND `System.loadLibrary()` MUST succeed for the solver's native library
