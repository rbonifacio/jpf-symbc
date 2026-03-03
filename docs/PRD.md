# JPF-SymBC — Migration Requirements Document

## 1. Overview

JPF-SymBC (Symbolic Java PathFinder) is a JPF extension that performs symbolic execution of Java bytecode. It supports symbolic execution on methods with basic type arguments (int, long, double, boolean), symbolic strings, arrays, and user-defined data structures, as well as a "symcrete" mode combining concrete and symbolic execution.

### 1.1 Key Facts

- **765 Java source files** across 6 source roots
- **28 JAR dependencies** in `lib/` (8 on Maven Central, 20 require local repository)
- **154 `.jpf` configuration files** (34 tests, 118 examples, 1 in src/main, 1 in doc/)
- **8+ constraint solver backends** (Z3, Choco, Coral, CVC3, STP, Yices, Green, HAMPI)
- **102 symbolic bytecode instruction classes** replacing standard JVM instructions
- **3 JARs produced**: jpf-symbc.jar, jpf-symbc-classes.jar, jpf-symbc-annotations.jar

### 1.2 Current State

| Aspect | Current | Target |
|--------|---------|--------|
| Build system | Apache Ant (build.xml) | Maven multi-module |
| Java version | 8 | 11 |
| jpf-core | Fork yannicnoller (Java 8, Ant) | Official javapathfinder/jpf-core (Java 11, Gradle) |
| Dependency management | Flat `lib/` directory (28 JARs, 34+ native libs) | Maven dependencies (8 Central) + local repository (`repo/`, 20 JARs) |
| Source organization | 6 source roots in `src/` | 5 Maven modules |

### 1.3 Repository

- **GitHub**: https://github.com/javapathfinder/jpf-symbc
- **License**: Apache 2.0
- **Note**: This is a third-party project. We do not have write access to the remote repository.

## 2. Problem Statement

### 2.1 Java 8 End of Life

JPF-SymBC requires Java 8, which reached end of public updates in 2019. The jpf-core project has already migrated to Java 11 with Gradle. Running jpf-symbc requires maintaining a separate Java 8 installation and a specific fork of jpf-core (yannicnoller/jpf-core), creating friction for researchers and contributors.

### 2.2 Ant Build Limitations

The Ant build system lacks dependency resolution, requiring all 28 JARs to be committed in `lib/`. There is no version management, no transitive dependency handling, and no standardized way to publish or consume artifacts. The build configuration is monolithic — a single `build.xml` manages 6 source roots with manual classpath wiring.

### 2.3 Fork Divergence

The yannicnoller/jpf-core fork used by jpf-symbc has diverged from the official jpf-core. Staying on the fork means missing bug fixes, performance improvements, and community contributions to jpf-core. The divergence grows over time, making future alignment harder.

## 3. Migration Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR01 | Migrate build system from Ant to Maven multi-module | MUST |
| FR02 | Organize source code into 5 Maven modules: annotations, main, classes, tests, examples | MUST |
| FR03 | Compile all source code with Java 11 (source and target level 11) | MUST |
| FR04 | Compile model classes (`java.*`) using `--patch-module` for Java module system compatibility | MUST |
| FR05 | Manage solver JARs without Maven Central via project-local repository (`repo/`) | MUST |
| FR06 | Manage solver JARs available on Maven Central via standard Maven dependencies | MUST |
| FR07 | Update all 154 `.jpf` configuration files with new artifact paths | MUST |
| FR08 | Update `jpf.properties` with new JAR locations | MUST |
| FR09 | Configure test execution with JUnit 4, fork per test, 1024MB max memory | MUST |
| FR10 | Preserve all test exclusions from current `build.xml` | MUST |
| FR11 | Build against official jpf-core (Java 11, Gradle) instead of yannicnoller fork | SHOULD |
| FR12 | Remove obsolete build artifacts (build.xml, .classpath, .project, nbproject/) | SHOULD |
| FR13 | Update documentation (README.md, CLAUDE.md) with new build commands | SHOULD |

### 3.2 Non-Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR01 | All 8+ solver backends MUST remain functional (Z3, Choco, Coral, CVC3, STP, Yices, Green, HAMPI) | MUST |
| NFR02 | Native libraries (.so/.dll/.dylib) in `lib/` MUST remain loadable at runtime | MUST |
| NFR03 | Existing `.jpf` configuration semantics MUST be preserved — only paths change | MUST |
| NFR04 | The output JARs MUST provide functional equivalence to the current 3 JARs — same classes are available at runtime. Annotations may ship in a dedicated JAR (INV-BLD-03 breaking change: `jpf-symbc-classes` no longer bundles annotations; both JARs must be on classpath). | MUST |
| NFR05 | Tests that pass today MUST continue to pass after migration | MUST |
| NFR06 | Build SHOULD work with `mvn compile` / `mvn test` / `mvn package` | SHOULD |
| NFR07 | Migration SHOULD be phased: Maven structure first (Java 8), then Java 11 upgrade | SHOULD |

## 4. Source Structure

### 4.1 Current Source Roots

| Source Root | Files | Purpose | Dependencies |
|-------------|-------|---------|-------------|
| `src/annotations` | 4 | Annotation definitions (@Symbolic, @Concrete, etc.) | None |
| `src/main` | 335 | Core symbolic execution engine | jpf-core, annotations |
| `src/peers` | 7 | Native peer implementations (JPF_*.java) | jpf-core |
| `src/classes` | 9 | Model classes executed inside JPF (java.*, gov.nasa.jpf.symbc.Debug) | jpf-core, annotations |
| `src/tests` | 197 | JUnit tests + ExSymExe* demo programs (129 files) | all above + JUnit 4 |
| `src/examples` | 213 | Example programs with .jpf configs (20+ categories) | main, classes, annotations |

### 4.2 Target Maven Modules

| Module | Source | JARs Produced |
|--------|--------|---------------|
| `jpf-symbc-annotations` | src/annotations | jpf-symbc-annotations.jar |
| `jpf-symbc-main` | src/main + src/peers (merged) | jpf-symbc.jar |
| `jpf-symbc-classes` | src/classes (split: regular + patch-module) | jpf-symbc-classes.jar |
| `jpf-symbc-tests` | src/tests | (test classes only) |
| `jpf-symbc-examples` | src/examples | (example classes only) |

### 4.3 Model Classes and Java Module System

Four model classes override JDK classes and require `--patch-module` compilation on Java 11:

| Class | Java Module | Cross-Dependencies |
|-------|-------------|-------------------|
| `java.lang.Math` | java.base | None |
| `java.util.Scanner` | java.base | Imports `gov.nasa.jpf.symbc.Debug` → needs `--add-reads java.base=ALL-UNNAMED` |
| `java.awt.image.BufferedImage` | java.desktop | Dead import of Debug (to be removed) |
| `java.awt.image.Kernel` | java.desktop | None |

## 5. Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| API incompatibility between fork and official jpf-core | HIGH | Medium | Quantify divergence via git diff before starting; focus on InstructionFactory, ClassInfo, MethodInfo |
| Model classes fail to compile with `--patch-module` | HIGH | Low | Follow jpf-core's proven pattern from gradle/source-sets.gradle |
| Native libraries (.so) incompatible with JDK 11 / modern glibc | MEDIUM | Medium | Smoke test System.loadLibrary with JDK 11 before investing in migration |
| 152 .jpf files with incorrect path updates | MEDIUM | High | Automated sed + mandatory post-verification grep |
| ClassLoader JPF + Java 11 module system interaction | MEDIUM | Medium | End-to-end testing in Phase 3 |
| Solver JARs incompatible with Java 11 | MEDIUM | Medium | Pure-Java JARs should work; JNI JARs need smoke test |
| opt4j-2.4.jar bundles ancient Guice+ASM+CGLIB | HIGH | High | opt4j 2.4 bundles Guice 1.0 with internal ASM 1.5.3 and CGLIB 2.1_3 — these cannot parse Java 11 class files (format 55). Coral solver uses opt4j for optimization and WILL crash at runtime. Must upgrade opt4j to 3.3 (Java 11 compatible) or isolate Coral. See https://github.com/SDARG/opt4j |
| Deprecated Java 8 APIs (40+ usages) | LOW | High | 40+ `new Integer()/Double()/Long()` constructor calls (deprecated in Java 9, removed in Java 16), `Class.newInstance()` (deprecated in Java 9), `finalize()` override. Java 11 will emit warnings but not fail — non-blocking for migration. |
| sat4j JARs are CUSTOM builds | LOW | Low | org.sat4j.core.jar and org.sat4j.pb.jar have `Bundle-Version: CUSTOM.v20100705` — they are NOT standard Maven Central releases. Must be placed in local repo, not declared as Maven Central deps. |

## 6. Phased Approach

```
Phase 0: Risk validation (go/no-go)
  ├── Verify jpf-core Maven coordinates
  ├── Smoke test native libraries with JDK 11
  └── Quantify fork divergence
    ↓
Phase 1: Maven multi-module structure (Java 8)
  ├── Create local repository for research JARs
  ├── Create Maven module structure and POMs
  ├── Move source files
  ├── Update .jpf file paths
  └── Validate: mvn compile (Java 8)
    ↓
Phase 2: Java 8 → 11 migration
  ├── Update Java version to 11
  ├── Configure --patch-module compilation
  ├── Configure --add-opens/--add-exports
  └── Validate: mvn compile (Java 11)
    ↓
Phase 3: Testing and jpf-core compatibility
  ├── Fix API differences with official jpf-core
  ├── Configure test exclusions in Surefire
  ├── Update jpf.properties
  └── Validate: mvn test + JPF example
    ↓
Phase 4: Cleanup and documentation
  ├── Remove obsolete build artifacts
  └── Update README.md and CLAUDE.md
```

## 7. Spec Domains

Specifications documenting the current system are organized in 3 domains covering the areas impacted by the migration:

| Domain | Scope | Spec |
|--------|-------|------|
| **build** | Build system, source roots, JARs produced, compilation targets | [build/spec.md](../openspec/specs/build/spec.md) |
| **dependencies** | jpf-core fork, 28 solver JARs, native libraries, classpath resolution | [dependencies/spec.md](../openspec/specs/dependencies/spec.md) |
| **configuration** | .jpf property files, jpf.properties, site.properties, path conventions | [configuration/spec.md](../openspec/specs/configuration/spec.md) |

Domains NOT impacted by the migration (symbolic execution engine, bytecode instructions, constraint solving logic) are not spec'd — functionality is preserved unchanged.
