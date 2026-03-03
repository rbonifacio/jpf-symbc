## Purpose

Dependency management migrates from a flat `lib/` directory with 28 committed JARs to Maven dependency resolution. JARs with verified Maven Central equivalents (8, confirmed via HTTP 200) become standard `<dependency>` declarations. JARs without Maven Central equivalents (20, including 2 custom sat4j builds) are installed into a project-local Maven repository (`repo/`) and declared as normal dependencies with a `<repository>` pointing to `file://${maven.multiModuleProjectDirectory}/repo`.

The jpf-core dependency changes from a fork (yannicnoller/jpf-core, Java 8, Ant) to the official repository (javapathfinder/jpf-core, Java 11, Gradle). jpf-core is consumed via `~/.m2/repository` after running `./gradlew publishToMavenLocal` on the official repo, rather than via peer directory resolution or `site.properties` path.

Native libraries in `lib/` (both root and `64bit/` subdirectory — 34+ files for Linux, Windows, macOS) remain unchanged — they are not Maven artifacts and are loaded at runtime via `java.library.path`.

## MODIFIED Invariants

- **INV-DEP-01**: jpf-core MUST be resolvable as a Maven dependency (`gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT`) from `~/.m2/repository`, installed via `./gradlew publishToMavenLocal` on the official javapathfinder/jpf-core repository
- **INV-DEP-02**: All 28 solver/utility JARs MUST be resolvable by Maven — 8 from Maven Central as `<dependency>` declarations (verified), 20 from the project-local `repo/` directory (including 2 custom sat4j builds)
- **INV-DEP-05**: `jpf-symbc.native_classpath` in `jpf.properties` MUST list all JARs required at JPF runtime, using Maven artifact paths (`*/target/*.jar`) for module JARs and `repo/` or `lib/` paths for solver JARs

## ADDED Invariants

- **INV-DEP-08**: The project-local repository (`repo/`) MUST be declared in the parent POM with `<url>file://${maven.multiModuleProjectDirectory}/repo</url>` (Maven 3.3.1+)
- **INV-DEP-09**: Each of the 20 non-Central JARs MUST be installed in `repo/` with unique groupId:artifactId:version coordinates using `mvn deploy:deploy-file`
- **INV-DEP-10**: Maven Central dependencies MUST use exact version matches to the current JARs in `lib/` (no version upgrades), **except** opt4j which MUST be upgraded from 2.4 to 3.3 for Java 11 compatibility (BLOCKER: bundled Guice 1.0 ASM/CGLIB cannot parse Java 11 class files)
- **INV-DEP-11**: jpf-core MUST be the official javapathfinder/jpf-core (Java 11, Gradle), NOT the yannicnoller fork
- **INV-DEP-12**: opt4j MUST be version 3.3 (Java 11 compatible) — version 2.4 bundles Guice 1.0 with ASM 1.5.3/CGLIB 2.1_3 that crash on Java 11 class format 55.0. Version 3.4+ requires Java 21 and MUST NOT be used.

## MODIFIED Requirements

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

All solver JARs MUST be available as Maven dependencies — either from Maven Central or the project-local repository.

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

Native libraries MUST remain loadable at runtime. They are NOT managed by Maven — they stay in `lib/` (both root and `64bit/` subdirectory).

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
- **AND** if they differ (expected — custom v20100705 vs Maven Central 2013), they MUST remain in `repo/` as local JARs
- **AND** if they are identical, they MAY be moved to Maven Central dependencies

## REMOVED Requirements

### Requirement: Peer Directory Resolution

jpf-core resolution via `../jpf-core` peer directory or `~/.jpf/site.properties` path for build-time classpath is removed. **Reason**: Replaced by Maven dependency on `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` resolved from `~/.m2/repository`. The `site.properties` file is still used by JPF at runtime for extension discovery, but not by the Maven build.

### Requirement: Flat lib/ Directory

The `lib/` directory as the sole source of solver JARs is removed. **Reason**: 8 JARs move to Maven Central dependencies, 20 JARs move to `repo/` as a Maven-standard local repository. `lib/` retains only native libraries (34+ files in root for Windows/macOS/Linux + `64bit/` subdirectory for Linux 64-bit specific). Solver JARs previously committed in `lib/` are deleted after migration to `repo/` or Maven Central — **native library files (.so, .dll, .dylib) in `lib/` root MUST be preserved**.
