## Context

JPF-SymBC uses Apache Ant with 6 source roots, 28 bundled JARs, and Java 8. The migration replaces this with Maven multi-module (5 modules), Maven dependency management, and Java 11 — while preserving all symbolic execution functionality unchanged.

The migration is phased (PRD Section 6): Phase 0 validates blockers, Phase 1 creates Maven structure (still Java 8), Phase 2 upgrades to Java 11, Phase 3 fixes jpf-core compatibility, Phase 4 cleans up. This design covers all four phases.

Key constraints:
- Fork repository with write access (github.com/phtcosta/jpf-symbc). Changes are committed in feature branches and merged via PR.
- 154 `.jpf` configuration files must have paths updated (34 tests, 118 examples, 1 in src/main, 1 in doc/)
- 4 model classes (`java.*`) require `--patch-module` compilation on Java 11
- Native libraries in `lib/64bit/` must remain loadable

References: [proposal.md](proposal.md), [PRD](../../docs/PRD.md) (FR01-FR13, NFR01-NFR07), specs ([build](../../openspec/specs/build/spec.md), [dependencies](../../openspec/specs/dependencies/spec.md), [configuration](../../openspec/specs/configuration/spec.md)).

## Development Environment

Java versions managed via **SDKMAN** (`sdk`). Installed versions:

| Version | SDKMAN identifier | Role in migration |
|---------|-------------------|-------------------|
| Java 8 | `8.0.302-open` | Current build (Ant baseline), Phase 1 validation |
| Java 8 | `8.0.282.hs-adpt` | Alternative (AdoptOpenJDK) |
| Java 11 | `11.0.12-open` | **Migration target** — Phase 0 smoke tests, Phase 2+ |
| Java 17 | `17.0.2-open` | Not used |
| Java 21 | `21.0.1-tem` | Not used |
| Java 25 | `25.0.1-tem` | **Current default** — must switch before any build |

**Key commands:**
```bash
# Switch to Java 8 for Ant baseline and Phase 1
sdk use java 8.0.302-open
java -version   # verify: openjdk version "1.8.0_302"

# Switch to Java 11 for Phase 0 smoke tests and Phase 2+
sdk use java 11.0.12-open
java -version   # verify: openjdk version "11.0.12"

# Verify current Java
sdk current java
```

**IMPORTANT**: The current default is Java 25. Every build/test command MUST be preceded by `sdk use java <version>` to ensure the correct JDK. Use `sdk use` (session-scoped, not persistent) rather than `sdk default` to avoid affecting other projects.

## Architecture

### Current State

```
jpf-symbc/
├── build.xml                    ← Single Ant build definition
├── jpf.properties               ← JPF extension config
├── lib/                         ← 28 JARs + native libs in 64bit/
├── src/
│   ├── annotations/ (4 files)
│   ├── main/        (335 files)
│   ├── peers/       (7 files)
│   ├── classes/     (9 files)
│   ├── tests/       (197 files)
│   └── examples/    (213 files)
└── build/                       ← Output: 6 dirs + 3 JARs
```

### Target State

```
jpf-symbc/
├── pom.xml                      ← Parent POM (reactor)
├── jpf.properties               ← Updated paths
├── repo/                        ← Project-local Maven repository (20 JARs)
├── lib/                         ← Native libs only (34+ .so/.dll/.dylib in root + 64bit/)
│
├── jpf-symbc-annotations/       ← Module 1: annotations
│   ├── pom.xml
│   └── src/main/java/gov/nasa/jpf/symbc/
│
├── jpf-symbc-main/              ← Module 2: main + peers (merged)
│   ├── pom.xml
│   └── src/main/java/
│       ├── gov/nasa/jpf/symbc/
│       ├── edu/ucsb/cs/vlab/
│       └── vlab/cs/ucsb/edu/
│
├── jpf-symbc-classes/           ← Module 3: model classes
│   ├── pom.xml
│   ├── src/main/java/           ← Regular classes (gov/, org/)
│   └── src/main/modules/        ← --patch-module classes
│       ├── java.base/java/{lang,util}/
│       └── java.desktop/java/awt/image/
│
├── jpf-symbc-tests/             ← Module 4: tests
│   ├── pom.xml
│   ├── src/test/java/
│   └── src/test/resources/*.jpf
│
└── jpf-symbc-examples/          ← Module 5: examples
    ├── pom.xml
    ├── src/main/java/
    └── src/main/resources/*.jpf
```

### Key Components

| Component | Responsibility | Input | Output |
|-----------|---------------|-------|--------|
| Parent POM (`pom.xml`) | Reactor ordering, dependency versions, plugin config, `repo/` repository | Module POMs | Build orchestration |
| `jpf-symbc-annotations/pom.xml` | Compile 4 annotation classes | Java sources | `jpf-symbc-annotations-1.0.0-SNAPSHOT.jar` |
| `jpf-symbc-main/pom.xml` | Compile 342 main+peer classes with all solver deps | Java sources, 28 JARs (8 Central + 20 local) | `jpf-symbc-main-1.0.0-SNAPSHOT.jar` |
| `jpf-symbc-classes/pom.xml` | Compile 9 model classes (3 compiler executions) | Java sources, jpf-core | `jpf-symbc-classes-1.0.0-SNAPSHOT.jar` |
| `jpf-symbc-tests/pom.xml` | Compile+run 197 test files via Surefire | Java sources, all modules | Test results |
| `jpf-symbc-examples/pom.xml` | Compile 213 example files | Java sources, main+classes | `jpf-symbc-examples-1.0.0-SNAPSHOT.jar` |
| `repo/` | Host 20 JARs without Maven Central equivalents (incl. 2 custom sat4j builds) | `mvn deploy:deploy-file` | Maven repository layout |
| `jpf.properties` | JPF extension registration with updated paths | Maven artifact locations | JPF classpath config |

### Module Dependency Graph

```
jpf-symbc-annotations  (no dependencies)
       ↓
jpf-symbc-main         → annotations + jpf-core + solvers (optional)
jpf-symbc-classes      → annotations + jpf-core (NOT main)
       ↓
jpf-symbc-tests        → main + classes + annotations + jpf-core + JUnit 4
jpf-symbc-examples     → main + classes + annotations
```

## Mapping: Spec → Implementation → Test

| Requirement | Implementation | Verification |
|-------------|---------------|--------------|
| FR01: Maven multi-module | `pom.xml` (parent) + 5 module POMs | `mvn compile` succeeds |
| FR02: 5 Maven modules | Directory structure + module declarations | All modules in reactor |
| FR03: Java 11 compilation | `<java.version>11</java.version>` in parent POM | `mvn compile` with JDK 11 |
| FR04: --patch-module for model classes | 3 compiler executions in `jpf-symbc-classes/pom.xml` | Model classes compile without errors |
| FR05: Local repo for non-Central JARs | `repo/` directory + `<repository>` in parent POM | 20 JARs resolvable (incl. 2 custom sat4j builds) |
| FR06: Maven Central dependencies | `<dependency>` declarations in module POMs | 8 JARs resolved from Central (verified via HTTP 200) |
| FR07: Update .jpf paths | sed script + post-verification grep | No references to `build/tests` or `build/examples` |
| FR08: Update jpf.properties | Manual edit of classpath entries | Paths resolve to Maven artifacts |
| FR09: Test config (fork, memory) | Surefire plugin config in `jpf-symbc-tests/pom.xml` | `mvn test` runs with correct JVM args |
| FR10: Test exclusions | Surefire `<excludes>` matching `build.xml` exclusions | Excluded tests not executed |
| FR11: Official jpf-core | `<dependency>` on `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` | Compiles against official jpf-core |
| FR12: Remove obsolete artifacts | Delete `build.xml`, `.classpath`, `.project`, `nbproject/` | Files absent |
| FR13: Update docs | Edit README.md, CLAUDE.md | Maven commands documented |
| NFR01: All solvers functional | All solver JARs on classpath | Solver-specific test passes |
| NFR02: Native libs loadable | `lib/64bit/` preserved, `java.library.path` configured | `System.loadLibrary()` succeeds |
| NFR03: .jpf semantics preserved | Only path properties change | .jpf files load correctly in JPF |
| NFR04: Functional equivalence of JARs | Source file mapping verified; union of `jpf-symbc-classes` + `jpf-symbc-annotations` JARs ≡ old `jpf-symbc-classes.jar` (INV-BLD-03) | JAR content comparison (class list union) |
| NFR05: Tests still pass | Surefire execution | `mvn test` green |
| INV-BLD-05: classes ≠ depend on main | `jpf-symbc-classes/pom.xml` has no dep on main | Compile without main on classpath |
| INV-DEP-06: classes deps | `jpf-symbc-classes` depends on jpf-core + annotations only | POM verification |
| INV-CFG-09: ${jpf-symbc} paths | .jpf files use `${jpf-symbc}` variable | grep verification |

## Goals / Non-Goals

**Goals:**
- Working Maven multi-module build that produces equivalent JARs
- All source files compile with Java 11
- Model classes compile with `--patch-module` (following jpf-core's pattern)
- Dependency management via Maven (Central + local repo)
- Tests execute via Surefire with same exclusions as Ant build
- .jpf configuration files work with updated paths
- jpf.properties integrates correctly with JPF runtime

**Non-Goals:**
- Changing any symbolic execution logic or behavior
- Upgrading solver versions (use exact same JARs), **except** opt4j (2.4→3.3, Java 11 BLOCKER — bundled Guice/ASM cannot parse class format 55.0)
- Adding CI/CD pipeline
- Publishing to Maven Central
- Supporting Java versions beyond 11
- Migrating jpf-core itself (consumed as-is from official repo)
- Adding jacoco, checkstyle, or other quality plugins
- Creating IDE project files (.idea, .vscode)

## Decisions

### D1: Maven over Gradle

**Choice**: Maven multi-module

**Rationale**: Maven's convention-over-configuration aligns with the straightforward compilation needs. The project has no complex build logic — just compile, package, test. Maven's multi-module reactor handles compilation ordering automatically. While jpf-core uses Gradle, jpf-symbc's build is simpler and doesn't benefit from Gradle's flexibility.

**Alternative considered**: Gradle (consistency with jpf-core). Rejected because it adds complexity without benefit for this project, and Maven's declarative POMs are easier to maintain for a research project.

### D2: Project-local repository (`repo/`) for non-Central JARs

**Choice**: `file://${maven.multiModuleProjectDirectory}/repo` repository in parent POM

**Rationale**: 20 of 28 JARs have no Maven Central equivalent. Options considered:
- `<systemPath>` (deprecated, not transitive, breaks `mvn install`)
- External Nexus/Artifactory (infrastructure overhead for a research project)
- `repo/` directory with standard Maven layout (portable, no external deps, works with `mvn install`)

The `${maven.multiModuleProjectDirectory}` variable (Maven 3.3.1+) ensures the repo is resolved correctly from any submodule.

### D3: Merge src/peers into jpf-symbc-main

**Choice**: Single module for main + peers

**Rationale**: Only 7 peer files, all in the same package (`gov.nasa.jpf.symbc`). No namespace conflicts verified. Peers depend on jpf-core just like main code. Separate module would add overhead without benefit. The original Ant build already packages them into the same JAR (`jpf-symbc.jar`).

### D4: Three compiler executions for jpf-symbc-classes

**Choice**: `default-compile` (regular) + `compile-patch-java-base` + `compile-patch-java-desktop`

**Rationale**: Java 11 module system forbids compiling classes in `java.*` packages without `--patch-module`. The 4 model classes span 2 JDK modules (java.base: Math, Scanner; java.desktop: BufferedImage, Kernel). Each module needs its own `--patch-module` argument. The regular classes (gov/, org/) compile normally first, so that `Debug.class` is available when `Scanner.java` is compiled with `--add-reads java.base=ALL-UNNAMED`.

This is the same pattern used by jpf-core in `gradle/source-sets.gradle` lines 42-60.

### D5: Phased migration (Java 8 first, then 11)

**Choice**: Phase 1 creates Maven structure with Java 8, Phase 2 upgrades to Java 11

**Rationale**: Isolates build-system changes from Java-version changes. If Maven structure works with Java 8, any Phase 2 failures are definitively Java 11 issues (not Maven misconfiguration). Allows incremental validation: `mvn compile` with Java 8, then `mvn compile` with Java 11.

### D6: jpf-core via publishToMavenLocal

**Choice**: Build official jpf-core locally and consume via `~/.m2/repository`

**Rationale**: jpf-core has no Maven Central artifacts. The official repo's Gradle build supports `./gradlew publishToMavenLocal` which publishes to `~/.m2/repository` with groupId `gov.nasa`. This is standard practice in the JPF ecosystem. The exact coordinates must be verified in Phase 0 (expected: `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT`).

## Data Flow

### Build Flow

```
Phase 0: Validation
  jpf-core fork (yannicnoller) → git checkout 0f2f2901 → ant build → ../jpf-core (Ant baseline)
  jpf-core official → ./gradlew publishToMavenLocal → ~/.m2/repository/gov/nasa/ (Maven target)
  lib/64bit/*.so → NativeLibSmokeTest.java → go/no-go decision
  NativeLibSmokeTest + JPF E2E → Z3 end-to-end via JPF (not just loadLibrary)
  git diff fork↔official → API divergence report (ALL 2275+ imports, not just 3 classes)
  SHA-256 baseline: sha256sum lib/*.jar → pre-migration checksums
  opt4j API audit: enumerate all opt4j imports, compare 2.4 vs 3.3 APIs
  SAT4J: verify custom v20100705 builds differ from Maven Central 2.3.6
  setup-dev-env.sh: automate jpf-core clone + publishToMavenLocal (reproducibility)

Phase 1: Maven Structure (Java 8)
  lib/*.jar → mvn deploy:deploy-file → repo/ (20 JARs, incl. sat4j custom builds + opt4j 3.3 upgrade)
  src/annotations/ → jpf-symbc-annotations/src/main/java/
  src/main/ + src/peers/ → jpf-symbc-main/src/main/java/
  src/classes/gov/,org/ → jpf-symbc-classes/src/main/java/
  src/classes/java/ → jpf-symbc-classes/src/main/modules/{java.base,java.desktop}/
  src/tests/ → jpf-symbc-tests/src/test/java/ + src/test/resources/*.jpf
  src/examples/ → jpf-symbc-examples/src/main/java/ + src/main/resources/*.jpf
  → mvn compile (Java 8)
  → mvn dependency:tree (detect transitive conflicts)

Phase 2: Java 11
  parent POM: java.version=8 → 11
  jpf-symbc-classes: 3 compiler executions (regular + patch-module ×2)
  jpf-symbc-tests: surefire --add-opens/--add-exports
  → mvn compile (Java 11)
  → Module system runtime test: execute simple .jpf via JPF, verify no IllegalAccessError

Phase 3: Testing + jpf-core compat
  Compile errors from official jpf-core API changes → fix in source
  surefire exclusions from build.xml → pom.xml
  jpf.properties path updates
  → mvn test

Phase 4: Cleanup
  Archive: build.xml → docs/build-archive/build.xml (preserve build knowledge)
  Remove: .classpath, .project, nbproject/, .externalToolBuilders/, src/
  Update: README.md, CLAUDE.md
```

### Runtime Classpath Flow (after migration)

```
~/.jpf/site.properties
  → jpf-symbc = /path/to/jpf-symbc
  → reads jpf.properties

jpf.properties
  → jpf-symbc.native_classpath:
      jpf-symbc-main/target/jpf-symbc-main-1.0.0-SNAPSHOT.jar
      jpf-symbc-annotations/target/jpf-symbc-annotations-1.0.0-SNAPSHOT.jar
      repo/<groupId-path>/<artifactId>/<version>/<jar> (each of 20 solver JARs listed explicitly)
      NOTE: JPF properties do NOT support ** wildcards. Each JAR must be listed individually
            with its full repo/ path (e.g., ${jpf-symbc}/repo/com/microsoft/z3/4.8.14/z3-4.8.14.jar).
            After migration, solver JARs live ONLY in repo/ (not lib/).
            lib/ retains ONLY native libraries (.so/.dll/.dylib).
  → jpf-symbc.classpath:
      jpf-symbc-classes/target/jpf-symbc-classes-1.0.0-SNAPSHOT.jar

*.jpf files
  → classpath=${jpf-symbc}/jpf-symbc-tests/target/test-classes
  → sourcepath=${jpf-symbc}/jpf-symbc-tests/src/test/java
```

## Error Handling

| Error | Source | Strategy | Recovery |
|-------|--------|----------|----------|
| jpf-core coordinates mismatch | Phase 0.2: `publishToMavenLocal` produces unexpected groupId/artifactId | Verify with `find ~/.m2/repository/gov/nasa` before writing POMs | Update all POM references to actual coordinates |
| Native lib fails to load on JDK 11 | Phase 0.3: `System.loadLibrary()` throws `UnsatisfiedLinkError` | Z3 failure blocks migration; others are optional | For Z3: investigate updated JAR. For CVC3/STP/Yices: document as unsupported on JDK 11 |
| API incompatibility with official jpf-core | Phase 3.1: compilation errors on `InstructionFactory`, `ClassInfo`, etc. | Fix source code to match official API signatures | Case-by-case adaptation; if scope too large, document and re-evaluate |
| .jpf paths not fully updated | Phase 1.8: some .jpf files have non-standard path patterns | Automated sed + mandatory post-verification with `grep -rL` | Manual fix for files not matching sed patterns |
| --patch-module compilation fails | Phase 2.2: model classes in `java.*` fail to compile | Follow jpf-core pattern exactly; check compiler plugin version | Debug with `-X` flag; compare with jpf-core's Gradle config |
| Maven reactor ordering wrong | Phase 1: modules compile in wrong order | Declare inter-module `<dependency>` correctly | Maven reactor resolves order from dependency graph |

## Risks / Trade-offs

**[API divergence too large]** → Phase 0.4 quantifies divergence before investing. Risk analysis found 75 unique jpf-core API classes imported and 100+ jpf-symbc classes extending jpf-core bytecode instructions. Key high-risk: `SymbolicInstructionFactory` (776 lines), `SymbolicListener` (654 lines). Mitigation: git diff between fork and official on these 75 classes.

**[Native libs compiled against old JDK/glibc]** → Phase 0.3 smoke test. Z3 failure is a blocker; others are optional. Mitigation: test `System.loadLibrary()` with JDK 11 before starting migration.

**[ClassLoader + module system interaction]** → JPF uses custom class loaders that may conflict with Java 11's module system at runtime. Mitigation: end-to-end testing in Phase 3 with a real JPF execution.

**[154 .jpf files with varied path patterns]** → sed handles the common patterns but some files may have non-standard references (absolute paths, `native_classpath` with hardcoded paths). Note: 2 files outside test/example dirs (`src/main/gov/nasa/jpf/symbc/concolic/TestMain.jpf`, `doc/Example.jpf`) need manual handling. Mitigation: post-sed verification with `grep -rL` + manual review.

**[opt4j-2.4 BLOCKER for Coral solver]** → opt4j 2.4 bundles Google Guice 1.0 with internal ASM 1.5.3 and CGLIB 2.1_3 (in `com/google/inject/internal/asm/` and `com/google/inject/internal/cglib/`). These cannot parse Java 11 class files (format 55.0), causing `ClassFormatError` when Guice creates proxy classes at runtime. This WILL crash the Coral solver on Java 11. **IMPORTANT**: The dependency chain is **indirect** — jpf-symbc source has NO direct `import org.opt4j.*`. The chain is: `ProblemCoral.java` → `coral.jar` (10+ classes in `coral/solvers/search/opt4j/`) → `opt4j-2.4.jar` → Guice 1.0 → ASM 1.5.3. Testing opt4j 3.3 compatibility must verify against `coral.jar`, not just jpf-symbc source. **Mitigation**: Upgrade opt4j to 3.3 (supports Java 11, available at https://github.com/SDARG/opt4j). opt4j 3.4+ requires Java 21 — do NOT use.

**[Compilation order in Maven]** → Maven compiler plugin executions within a single module (the 3 executions in jpf-symbc-classes) run in declaration order. The default-compile must run first so `Debug.class` is available for `Scanner.java`. Mitigation: verify execution order; default-compile always runs before custom executions.

## Rollback Plan

The migration is protected by git tags at each phase boundary for granular rollback:
- `pre-migration-java11` — before any changes (task 0.1)
- `migration-phase1-maven-structure-complete` — after Maven structure + file moves (after Group 4)
- `migration-phase2-java11-complete` — after Java 11 compiles + runtime test (after Group 5)
- `migration-phase3-testing-complete` — after tests pass + solver smoke tests (after Group 6)

Rollback criteria per phase:

| Phase | Rollback Trigger | Action |
|-------|-----------------|--------|
| Phase 0 | Z3 native lib fails on JDK 11 | Abort migration — investigate updated Z3 JAR/native before retrying |
| Phase 0 | jpf-core API divergence >50 breaking changes | Abort migration — scope too large, consider alternative approach (keep fork, upgrade only Java) |
| Phase 0 | opt4j 3.3 incompatible AND Coral is essential | Abort or scope Coral as unsupported |
| Phase 1 | Maven structure doesn't compile with Java 8 | Debug Maven config — no code changes yet, safe to iterate |
| Phase 2 | Module system breaks compilation | Debug `--patch-module` config — Phase 1 tag is safe checkpoint |
| Phase 3 | >20% of non-excluded tests fail | Investigate API adaptation scope — may need to re-evaluate |

**Recovery procedure:**
1. `git checkout pre-migration-java11` — returns to pre-migration state
2. Create branch `migration-java11-failed-phase-N` for post-mortem
3. Document findings in `docs/migration-retrospective.md`

## Breaking Change: INV-BLD-03 (Annotations Separation)

The original `jpf-symbc-classes.jar` included both model classes AND annotations. After migration, annotations are in their own JAR (`jpf-symbc-annotations.jar`). This is a semantic breaking change:
- Code depending on annotations being in the classes JAR classpath will need both JARs
- `jpf.properties` must list both JARs in `native_classpath`
- Scripts/configs referencing only `jpf-symbc-classes.jar` for annotations will break

This is intentional (proper Maven separation) but must be documented prominently.

## Testing Strategy

| Layer | What to test | How | Scope |
|-------|-------------|-----|-------|
| Compilation | All 765 source files compile | `mvn compile` | Phase 1 (Java 8), Phase 2 (Java 11) |
| Unit tests | Existing JUnit 4 tests pass | `mvn test` via Surefire | Phase 3 |
| Smoke test (JNI) | Native libraries load on JDK 11 | `NativeLibSmokeTest.java` (temporary) | Phase 0 |
| E2E smoke (JNI) | Z3 works through JPF, not just loadLibrary | Execute `.jpf` with `symbolic.dp=z3` on JDK 11 | Phase 0 |
| Path verification | No old paths remain in .jpf files | `grep -rl 'build/tests\|build/examples'` returns empty | Phase 1 |
| JAR content | Output JARs contain same classes | Compare class lists between old and new JARs (SHA-256 baseline) | Phase 3 |
| Transitive deps | No dependency conflicts | `mvn dependency:tree` — no version conflicts | Phase 1 |
| Module system runtime | JPF ClassLoader works under Java 11 modules | Execute JPF with symbolic execution, verify no `IllegalAccessError` | Phase 2 |
| Integration | JPF runs a symbolic execution example | Execute a `.jpf` file via JPF with migrated jpf-symbc | Phase 3 |
| Surefire exclusion parity | Same tests excluded in Maven as in Ant | Compare `mvn test -X` output with Ant exclusion list | Phase 3 |
| Solver integration | Each solver works end-to-end | Per-solver smoke test table (see below) | Phase 3 |

### Quantitative Acceptance Criteria

**Phase 1 (Maven + Java 8):**
- 765 Java files compile without errors
- 0 compilation errors, warnings acceptable (deprecated APIs)
- 5 modules appear in Maven reactor in correct order
- `mvn dependency:tree` shows no version conflicts

**Phase 2 (Java 11):**
- 765 Java files compile with JDK 11
- 4 model classes compile with `--patch-module` (3 compiler executions succeed)
- No `IllegalAccessError` or `InaccessibleObjectException` at runtime

**Phase 3 (Testing):**
- All non-excluded tests pass (`mvn test` green)
- Surefire exclusion list matches Ant `build.xml` exclusions exactly
- At least Z3 and Choco solver smoke tests pass

### Per-Solver Smoke Test Table

| Solver | .jpf example | Mandatory | Expected result |
|--------|-------------|-----------|-----------------|
| Z3 | `symbolic.dp=z3` | YES — blocker if fails | Returns correct solution |
| Choco | `symbolic.dp=choco` | YES — blocker if fails | Returns correct solution |
| Coral | `symbolic.dp=coral` | CONDITIONAL — only if opt4j 3.3 works | Returns correct solution OR documented as unsupported |
| CVC3 | `symbolic.dp=cvc3` | NO — best effort | Returns solution OR documented as unsupported (native lib) |
| STP | `symbolic.dp=no_solver` with STP | NO — best effort | Returns solution OR documented as unsupported (native lib) |
| Yices | `symbolic.dp=yices` | NO — best effort | Returns solution OR documented as unsupported (native lib) |

## Open Questions

1. **Exact jpf-core Maven coordinates** — Expected `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` but must be verified after `publishToMavenLocal`. Phase 0.2 resolves this.
2. **Z3 native library compatibility with JDK 11** — The `com.microsoft.z3.jar` and `libz3.so` in `lib/` were last modified 2021-02-05. Phase 0.3 + 0.3b determines if an update is needed.
3. **Scope of API changes in official jpf-core** — Unknown until Phase 0.4 diff analysis. Risk analysis found **75 unique jpf-core API classes** imported and **100+ jpf-symbc classes** that extend jpf-core bytecode instructions. Key high-risk classes: `SymbolicInstructionFactory` (776 lines), `SymbolicListener` (654 lines).
4. ~~**PathConditionsReliability-0.0.1.jar**~~ — **RESOLVED**: Dead reference. No Java imports found in any source file. Only appears in JVM crash logs (`hs_err_pid*.log`) from other users' projects (`jpf-security`). **Action**: remove from `jpf.properties` during task 6.2.
5. **opt4j upgrade scope** — Risk analysis revealed the dependency is **indirect**: `ProblemCoral` → `coral.jar` (10+ classes in `coral/solvers/search/opt4j/`) → `opt4j-2.4` → Guice 1.0 → ASM 1.5.3. No direct `import org.opt4j` exists in jpf-symbc source — all opt4j usage is inside `coral.jar`. Phase 0.5b must test `coral.jar` against opt4j 3.3, not just jpf-symbc source. If coral.jar's internal opt4j-dependent classes are API-incompatible, Coral becomes unsupported on Java 11.
6. **Deprecated API warnings** — Risk analysis found **737** deprecated boxed-type constructor calls (not "40+" as previously estimated), plus 1 `Class.newInstance()` and 1 `finalize()` override in `SymbolicInteger.java`. These compile on Java 11 with warnings but do not block.
7. ~~**SAT4J custom builds**~~ — **RESOLVED**: MANIFEST.MF confirms `Bundle-Version: CUSTOM.v20100705`, `Implementation-Version: 2.0`. Maven Central has version 2.3.6 (2013). These are definitively different. **Decision**: keep in `repo/` as local JARs with coordinates `org.sat4j:org.sat4j.core:CUSTOM-20100705`. Dependency count remains 8 Central + 20 local = 28.
8. **SHA-256 JAR verification** — Before replacing any `lib/` JAR with a Maven Central dependency, SHA-256 checksums must be compared. Phase 0.6 captures baseline.
9. **--add-opens/--add-exports completeness** — JPF uses reflection extensively. The initial list of 3 flags may be insufficient. Start with this list and expand empirically based on `IllegalAccessError` during testing.

## Resolved Pre-Migration Issues

The following issues were discovered during risk analysis and have clear resolutions. They should be applied during implementation without further investigation:

| Issue | Evidence | Resolution | Task |
|-------|----------|------------|------|
| `PathConditionsReliability-0.0.1.jar` dead reference | No Java imports; only in crash logs from jpf-security users | Remove from `jpf.properties` | 6.2 |
| `libcvc3.jar` duplicated in `jpf.properties` | Listed on lines 10 AND 24 of `native_classpath` | Remove duplicate entry | 6.2 |
| `jpf-symbc.test_classpath` missing `${jpf-symbc}/` prefix | Line 46-47: `build/tests` without prefix (all other paths use it) | Fix to `${jpf-symbc}/jpf-symbc-tests/target/test-classes` | 6.2 |
| SAT4J custom builds ≠ Maven Central | MANIFEST: `CUSTOM.v20100705` / `Implementation-Version: 2.0` vs Central 2.3.6 | Keep in `repo/` (20 local JARs confirmed) | 1.2 |
| Non-standard external path in .jpf | `Chars99int2_2_2.jpf` line 6: `native_classpath=../../git/local-test-jpf-add2/...` | Comment out or remove hardcoded path | 4.6 |

## Positive Findings (Risk Eliminators)

- **No `javax.xml.bind`, `sun.misc`, or `com.sun.*` usage** — eliminates a common class of Java 8→11 migration issues (removed modules, internal API restrictions)
- **No Java EE dependencies** — no JAX-WS, JAXB, CORBA, or JTA usage that was removed in Java 11
- **737 deprecated constructors are warnings-only** — `new Integer()`, `new Double()`, etc. compile on Java 11 (removed only in Java 16)
