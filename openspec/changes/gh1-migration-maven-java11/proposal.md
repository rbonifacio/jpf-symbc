## Why

JPF-SymBC is locked to Java 8 (end of public updates since 2019) and depends on a stale fork of jpf-core (yannicnoller/jpf-core). The official jpf-core has migrated to Java 11 with Gradle and continues receiving updates, while the fork diverges further over time. The Ant build system lacks dependency management — 28 JARs are committed directly in `lib/` with no version tracking or transitive resolution. These constraints create friction for researchers, prevent adoption of Java 11+ language features, and isolate jpf-symbc from the active jpf-core community.

## What Changes

- **BREAKING**: Replace Apache Ant (`build.xml`) with Maven multi-module build (parent POM + 5 module POMs)
- **BREAKING**: Raise Java source/target level from 8 to 11
- **BREAKING**: Switch jpf-core dependency from yannicnoller fork (Java 8, Ant) to official javapathfinder/jpf-core (Java 11, Gradle) — may require API adaptation in `SymbolicInstructionFactory`, `SymbolicListener`, and peers
- Reorganize 6 source roots (`src/main`, `src/peers`, `src/annotations`, `src/classes`, `src/tests`, `src/examples`) into 5 Maven modules (`jpf-symbc-annotations`, `jpf-symbc-main`, `jpf-symbc-classes`, `jpf-symbc-tests`, `jpf-symbc-examples`)
- Merge `src/peers` (7 files) into `jpf-symbc-main` module (no namespace conflicts verified)
- Split `src/classes` into regular compilation (`gov/**`, `org/**`) and `--patch-module` compilation (`java.base`, `java.desktop`) for Java 11 module system compatibility
- Move 8 JARs with verified Maven Central equivalents to standard `<dependency>` declarations
- Move 20 JARs without Maven Central equivalents (including 2 custom sat4j builds) to a project-local Maven repository (`repo/`)
- Update path references in all 154 `.jpf` files (`build/tests` → `jpf-symbc-tests/target/test-classes`, etc.)
- Investigate opt4j-2.4.jar BLOCKER: bundles Guice 1.0 with ancient ASM/CGLIB that cannot parse Java 11 class files — Coral solver will crash; must upgrade opt4j to 3.3 or isolate
- Update `jpf.properties` with new JAR locations and classpath entries
- Remove dead import in `src/classes/java/awt/image/BufferedImage.java` (`gov.nasa.jpf.symbc.Debug` — usage is commented out)
- Configure `maven-surefire-plugin` with `--add-opens`, `--add-exports` for Java 11 module system
- Remove obsolete build artifacts: `build.xml`, `.classpath`, `.project`, `nbproject/`, `.externalToolBuilders/`

## Capabilities

### New Capabilities

None — this is an infrastructure migration, not a feature addition.

### Modified Capabilities

- `build`: Build system changes from Ant to Maven multi-module. Source roots reorganized into 5 modules. Compilation order enforced by Maven reactor instead of Ant target dependencies. Java level changes from 8 to 11. Model classes (`java.*`) require `--patch-module` compilation with 3 separate compiler executions.
- `dependencies`: Dependency management changes from flat `lib/` directory to Maven dependencies (8 from Maven Central, verified) + project-local repository (20 in `repo/`, including custom sat4j builds). jpf-core resolved via `~/.m2/repository` (publishToMavenLocal) instead of peer directory. Native libraries remain in `lib/` (both root and `64bit/` subdirectory). opt4j-2.4.jar requires upgrade to 3.3 for Java 11 compatibility (BLOCKER for Coral solver).
- `configuration`: Path references in 154 `.jpf` files and `jpf.properties` change to reflect Maven output directories (`target/classes`, `target/test-classes`). Configuration semantics and property names are preserved unchanged. Note: `jpf-symbc.sourcepath` does not exist in current `jpf.properties` — only `native_classpath`, `classpath`, `test_classpath`, and `peer_packages`.

## Impact

**Source files (all 765):**
- Every `.java` file moves from `src/<root>/` to a Maven module's `src/main/java/` or `src/test/java/`
- No code changes required (Java 8 source is forward-compatible with Java 11) except dead import removal in `BufferedImage.java`

**Configuration files (156):**
- 154 `.jpf` files: path property updates (automated via sed + post-verification); includes 1 in `src/main/` (TestMain.jpf) and 1 in `doc/` (Example.jpf) beyond the 152 in tests+examples
- `jpf.properties`: classpath entries updated to Maven artifact paths
- `~/.jpf/site.properties`: no changes (still points to project root)

**Dependencies:**
- jpf-core: must be built from official repo and published to local Maven (`./gradlew publishToMavenLocal`)
- 8 JARs: replaced by Maven Central dependencies (exact version match, SHA-256 verified)
- 20 JARs: installed in project-local `repo/` directory (including 2 custom sat4j builds)
- Native libraries: unchanged (remain in `lib/64bit/`)

**Build artifacts removed:**
- `build.xml`, `.classpath`, `.project`, `nbproject/`, `.externalToolBuilders/`
- `src/` directory (after confirming migration completeness)

**Risk areas (from PRD Section 5):**
- API incompatibility between jpf-core fork and official (HIGH impact, medium probability) — affects `InstructionFactory`, `ClassInfo`, `MethodInfo`
- Native library compatibility with JDK 11 (MEDIUM impact, medium probability) — requires smoke test
- `--patch-module` compilation of model classes (HIGH impact, low probability) — proven pattern from jpf-core
- ClassLoader JPF + Java 11 module system interaction (MEDIUM impact, medium probability) — requires end-to-end testing
