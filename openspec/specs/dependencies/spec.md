# Specification: Dependencies

## Purpose

Dependency management uses Maven dependency resolution. JARs with verified Maven Central equivalents (8, confirmed via HTTP 200) are standard `<dependency>` declarations. JARs without Maven Central equivalents (20, including 2 custom sat4j builds) are installed into a project-local Maven repository (`repo/`) and declared as normal dependencies with a `<repository>` pointing to `file://${maven.multiModuleProjectDirectory}/repo`.

The jpf-core dependency is the official repository (javapathfinder/jpf-core, Java 11, Gradle). jpf-core is consumed via `~/.m2/repository` after running `./gradlew publishToMavenLocal` on the official repo, rather than via peer directory resolution or `site.properties` path.

Native libraries in `lib/` (both root and `64bit/` subdirectory -- 34+ files for Linux, Windows, macOS) remain unchanged -- they are not Maven artifacts and are loaded at runtime via `java.library.path`.

### jpf-core Dependency

JPF-SymBC depends on the official jpf-core:

| Property | Value |
|----------|-------|
| Repository | https://github.com/javapathfinder/jpf-core |
| Java version | 11 |
| Build system | Gradle |
| Maven coordinates | `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` |
| Installation | `./gradlew publishToMavenLocal` |

jpf-core is resolved at build time via Maven dependency resolution from `~/.m2/repository`. The `site.properties` file is still used by JPF at runtime for extension discovery, but not by the Maven build.

### Third-Party JARs

28 JARs, categorized by Maven Central availability:

**Available on Maven Central (8 JARs):**

| JAR | Maven Central Coordinates | Verified |
|-----|--------------------------|----------|
| commons-lang-2.4.jar | `commons-lang:commons-lang:2.4` | HTTP 200 |
| commons-math-1.2.jar | `commons-math:commons-math:1.2` | HTTP 200 |
| bcel.jar | `org.apache.bcel:bcel:6.0` | HTTP 200 (exact version unverified -- JAR has no manifest) |
| automaton.jar | `dk.brics.automaton:automaton:1.11-8` | HTTP 200 |
| jaxen.jar | `jaxen:jaxen:1.2.0` | HTTP 200 |
| JSAP-2.1.jar | `com.martiansoftware:jsap:2.1` | HTTP 200 |
| aima-core.jar | `com.googlecode.aima-java:aima-core:0.10.5` | HTTP 200 |
| jedis-2.0.0.jar | `redis.clients:jedis:2.0.0` | HTTP 200 |

**NOT on Maven Central -- installed in project-local `repo/` (20 JARs):**

| JAR | Solver/Purpose |
|-----|---------------|
| org.sat4j.core.jar | SAT4J solver (CUSTOM build v20100705 -- NOT on Maven Central; Maven Central has org.sat4j:org.sat4j.core:2.3.1 but different build) |
| org.sat4j.pb.jar | SAT4J pseudo-boolean solver (CUSTOM build v20100705 -- same issue) |
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
| opt4j-3.3.jar | Opt4J optimization framework (upgraded from 2.4 for Java 11 compatibility) |
| grappa.jar | Graph visualization |

**Missing JAR (referenced but not in lib/):**
- `PathConditionsReliability-0.0.1.jar` -- referenced in `jpf.properties` but not present in `lib/`

### Native Libraries

Native libraries exist in two locations:

**`lib/` root** -- 34+ native library files for multiple platforms:

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

**`lib/64bit/`** -- Linux 64-bit specific:

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

- `~/.m2/repository` -- jpf-core Maven artifacts (installed via `./gradlew publishToMavenLocal`)
- `repo/` -- project-local Maven repository with 20 non-Central JARs
- Maven Central -- 8 solver/utility JARs
- `lib/64bit/*.so` -- native JNI libraries
- System-installed native libraries (Z3, ABC)

### Output

- Maven dependency resolution providing compilation and runtime classpaths
- `jpf.properties` -> `jpf-symbc.native_classpath` listing all required JARs

### Side Effects

- Maven downloads Central dependencies to `~/.m2/repository` on first build
- jpf-core must be pre-installed via `./gradlew publishToMavenLocal`

## Invariants

- **INV-DEP-01**: jpf-core MUST be resolvable as a Maven dependency (`gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT`) from `~/.m2/repository`, installed via `./gradlew publishToMavenLocal` on the official javapathfinder/jpf-core repository
- **INV-DEP-02**: All 28 solver/utility JARs MUST be resolvable by Maven -- 8 from Maven Central as `<dependency>` declarations (verified), 20 from the project-local `repo/` directory (including 2 custom sat4j builds)
- **INV-DEP-03**: Z3 native library MUST be loadable for Z3 solver backend to function
- **INV-DEP-04**: CVC3 native libraries (`libcvc3jni.so`, `libgmp.so`) MUST be in `lib/64bit/` for CVC3 backend
- **INV-DEP-05**: `jpf-symbc.native_classpath` in `jpf.properties` MUST list all JARs required at JPF runtime, using Maven output directories (`*/target/classes`) for module artifacts and `repo/` or `lib/` paths for solver JARs
- **INV-DEP-06**: `src/classes` depends on jpf-core (`gov.nasa.jpf.vm.Verify`) and annotations, NOT on `src/main`
- **INV-DEP-07**: `src/main` and `src/peers` depend on jpf-core but NOT on `src/classes`
- **INV-DEP-08**: The project-local repository (`repo/`) MUST be declared in the parent POM with `<url>file://${maven.multiModuleProjectDirectory}/repo</url>` (Maven 3.3.1+)
- **INV-DEP-09**: Each of the 20 non-Central JARs MUST be installed in `repo/` with unique groupId:artifactId:version coordinates using `mvn deploy:deploy-file`
- **INV-DEP-10**: Maven Central dependencies MUST use exact version matches to the current JARs in `lib/` (no version upgrades), **except** opt4j which MUST be upgraded from 2.4 to 3.3 for Java 11 compatibility (BLOCKER: bundled Guice 1.0 ASM/CGLIB cannot parse Java 11 class files)
- **INV-DEP-11**: jpf-core MUST be the official javapathfinder/jpf-core (Java 11, Gradle), NOT the yannicnoller fork
- **INV-DEP-12**: opt4j MUST be version 3.3 (Java 11 compatible) -- version 2.4 bundles Guice 1.0 with ASM 1.5.3/CGLIB 2.1_3 that crash on Java 11 class format 55.0. Version 3.4+ requires Java 21 and MUST NOT be used.

## Requirements

### Requirement: jpf-core Resolution (FR11)

The build MUST resolve jpf-core as a Maven dependency from `~/.m2/repository`. The official jpf-core repository publishes artifacts via `./gradlew publishToMavenLocal`.

#### Scenario: Resolution via Maven Local Repository

- **WHEN** `./gradlew publishToMavenLocal` has been executed on the official jpf-core
- **AND** `~/.m2/repository/gov/nasa/` contains jpf-core artifacts
- **THEN** Maven resolves `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` from the local repository
- **AND** jpf-core classes are available on the compilation classpath

#### Scenario: Missing jpf-core in Maven Local

- **WHEN** jpf-core has not been published to Maven local
- **THEN** Maven dependency resolution fails
- **AND** compilation fails with unresolved dependency error on `gov.nasa:jpf-core`

#### Scenario: jpf-core Coordinate Verification

- **WHEN** the migration begins (Phase 0.2)
- **THEN** the exact groupId, artifactId, and version from `publishToMavenLocal` MUST be verified with `find ~/.m2/repository/gov/nasa -name "*.pom"`
- **AND** all POM references MUST use the verified coordinates

### Requirement: Solver JAR Availability (NFR01)

All solver JARs MUST be available as Maven dependencies -- either from Maven Central or the project-local repository.

#### Scenario: Local Repository Solver (Choco)

- **WHEN** `symbolic.dp=choco` is configured
- **THEN** Choco JARs are resolved from the project-local `repo/` directory (Choco is NOT on Maven Central with these coordinates)
- **AND** the JARs are on the classpath via Maven dependency resolution

#### Scenario: Local Repository Solver

- **WHEN** `symbolic.dp=z3` is configured
- **THEN** `com.microsoft:z3:4.8.14` is resolved from the project-local `repo/` directory
- **AND** the JAR is on the classpath via Maven dependency resolution
- **AND** `libz3.so` and `libz3java.so` MUST be loadable via `java.library.path`

#### Scenario: All 20 Local Repository JARs Resolvable

- **WHEN** `mvn compile` is executed
- **THEN** all 20 JARs in `repo/` are resolved without errors
- **AND** their coordinates match the verified dependency table

### Requirement: Native Library Loading (NFR02)

Native libraries MUST remain loadable at runtime. They are NOT managed by Maven -- they stay in `lib/` (both root and `64bit/` subdirectory).

#### Scenario: Native Library Path

- **WHEN** JPF runs with a JNI-based solver (Z3, CVC3, STP, Yices)
- **THEN** `java.library.path` MUST include `lib/64bit/` (or system library path)
- **AND** `System.loadLibrary()` MUST succeed for the solver's native library on JDK 11

#### Scenario: JDK 11 Native Library Smoke Test

- **WHEN** `NativeLibSmokeTest.java` is executed with JDK 11 (Phase 0.3)
- **THEN** Z3 (`libz3`) MUST load successfully (blocker if it fails)
- **AND** CVC3, STP, Yices failures are documented but do not block migration

### Requirement: JAR Integrity Verification

Maven Central dependencies MUST be verified against the pre-migration JAR baseline to ensure byte-level or functional equivalence.

#### Scenario: SHA-256 Baseline Capture

- **WHEN** Phase 0.6 executes
- **THEN** `sha256sum lib/*.jar` is captured to `docs/jar-checksums-pre-migration.txt`
- **AND** this baseline is used for all subsequent JAR comparisons

#### Scenario: Maven Central JAR Verification

- **WHEN** an 8 Maven Central dependencies are resolved in Phase 1
- **THEN** SHA-256 of each downloaded JAR is compared against the pre-migration baseline
- **AND** any differences are investigated (version mismatch, local modification, or repackaging)
- **AND** functionally different JARs are flagged for manual review

#### Scenario: SAT4J Custom Build Verification

- **WHEN** SAT4J JARs (`org.sat4j.core`, `org.sat4j.pb`) are processed in Phase 0.7
- **THEN** their class lists and MANIFEST.MF are compared with Maven Central `org.ow2.sat4j:org.sat4j.core:2.3.6`
- **AND** if they differ (expected -- custom v20100705 vs Maven Central 2013), they MUST remain in `repo/` as local JARs
- **AND** if they are identical, they MAY be moved to Maven Central dependencies
