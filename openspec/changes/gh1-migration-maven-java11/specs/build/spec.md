## Purpose

The build system migrates from Apache Ant (`build.xml`) to Maven multi-module (parent POM + 5 module POMs). The 6 source roots consolidate into 5 Maven modules: `jpf-symbc-annotations`, `jpf-symbc-main` (merging `src/main` + `src/peers`), `jpf-symbc-classes`, `jpf-symbc-tests`, and `jpf-symbc-examples`. Compilation ordering, previously managed by Ant target dependencies, is now handled by Maven's reactor via inter-module `<dependency>` declarations. Java source/target level changes from 8 to 11.

The `jpf-symbc-classes` module requires special handling: model classes in `java.*` packages cannot compile normally on Java 11 due to the module system. The `maven-compiler-plugin` is configured with 3 executions — one for regular classes (`gov/**`, `org/**`), one for `java.base` classes (Math, Scanner) with `--patch-module java.base`, and one for `java.desktop` classes (BufferedImage, Kernel) with `--patch-module java.desktop`. This follows the same pattern used by jpf-core's Gradle build (`gradle/source-sets.gradle`).

Build outputs change from `build/` subdirectories + 3 JARs to Maven's `target/` directories with one JAR per module. The 3 original JARs map directly to 3 module JARs: `jpf-symbc-main` (was `jpf-symbc.jar`), `jpf-symbc-classes` (was `jpf-symbc-classes.jar`), `jpf-symbc-annotations` (was `jpf-symbc-annotations.jar`).

## MODIFIED Invariants

- **INV-BLD-01**: All source MUST compile with Java 11 source/target level (`<java.version>11</java.version>`)
- **INV-BLD-02**: `jpf-symbc-main-1.0.0-SNAPSHOT.jar` MUST contain classes from both `src/main` and `src/peers` (merged in `jpf-symbc-main/src/main/java/`)
- **INV-BLD-03**: `jpf-symbc-classes-1.0.0-SNAPSHOT.jar` MUST contain classes from `src/classes` only. Annotations are available at compile time via Maven `<dependency>` on `jpf-symbc-annotations` but are NOT physically included in the classes JAR (they ship in their own JAR). **BREAKING CHANGE**: The original `jpf-symbc-classes.jar` included annotations — after migration, runtime classpath MUST include both `jpf-symbc-classes` AND `jpf-symbc-annotations` JARs. Any code, script, or configuration that depended on annotations being in the classes JAR will need both JARs on the classpath. `jpf.properties` `native_classpath` must list both.
- **INV-BLD-04**: `jpf-symbc-annotations-1.0.0-SNAPSHOT.jar` MUST contain classes from `src/annotations` only

## ADDED Invariants

- **INV-BLD-09**: Model classes in `java.lang` and `java.util` packages MUST compile with `--patch-module java.base` and `--add-reads java.base=ALL-UNNAMED`
- **INV-BLD-10**: Model classes in `java.awt` packages MUST compile with `--patch-module java.desktop`
- **INV-BLD-11**: The default-compile execution MUST run before patch-module executions so that `gov.nasa.jpf.symbc.Debug.class` is available for `java.util.Scanner`
- **INV-BLD-12**: Maven reactor MUST resolve module compilation order from `<dependency>` declarations: annotations → main, classes → tests, examples

## REMOVED Invariants

- **INV-BLD-07**: Compilation MUST enable debug symbols (`debug = on`) — **Reason**: Maven compiler plugin enables debug by default. No explicit configuration needed.
- **INV-BLD-08**: Compilation MUST report deprecation warnings (`deprecation = on`) — **Reason**: Configured via `<showDeprecation>true</showDeprecation>` in parent POM pluginManagement, not a spec-level invariant.

## MODIFIED Requirements

### Requirement: Compile All Sources (FR01)

The build system MUST compile all 5 Maven modules in dependency order and produce compiled class files. Compilation ordering is handled by Maven reactor based on inter-module `<dependency>` declarations.

#### Scenario: Full Compilation

- **WHEN** `mvn compile` is executed with JDK 11
- **THEN** all 5 Maven modules compile without errors
- **AND** compiled classes are placed in each module's `target/classes/` directory

#### Scenario: Default Build

- **WHEN** `mvn package` is executed
- **THEN** sources are compiled
- **AND** 5 JAR files are produced, one per module in each module's `target/` directory
- **AND** `jpf-symbc-main-1.0.0-SNAPSHOT.jar` contains classes from original `src/main` and `src/peers`

#### Scenario: Model Class Compilation with --patch-module

- **WHEN** `mvn compile` is executed on the `jpf-symbc-classes` module
- **THEN** regular classes (`gov/**`, `org/**`) compile first via the default-compile execution
- **AND** `java.base` classes (Math, Scanner) compile with `--patch-module java.base` and `--add-reads java.base=ALL-UNNAMED`
- **AND** `java.desktop` classes (BufferedImage, Kernel) compile with `--patch-module java.desktop`
- **AND** all 3 compiler executions succeed

### Requirement: Test Execution (FR09, FR10)

The build system MUST run JUnit 4 tests via `maven-surefire-plugin` with specific configuration, exclusions, and Java 11 module system flags.

#### Scenario: Test Run

- **WHEN** `mvn test` is executed on the `jpf-symbc-tests` module
- **THEN** tests are executed with `<forkCount>1</forkCount>` and `<reuseForks>false</reuseForks>`
- **AND** each test JVM has `-Xmx1024m` max memory
- **AND** each test JVM has `--add-opens java.base/java.lang=ALL-UNNAMED`
- **AND** each test JVM has `--add-opens java.base/java.util=ALL-UNNAMED`
- **AND** each test JVM has `--add-exports java.base/jdk.internal.misc=ALL-UNNAMED`
- **AND** the following test patterns are excluded:
  - `**/JPF_*.java`
  - `**/TestBitwise*.java`
  - `**/TestCoverage.java`
  - `**/TestDIV.java`
  - `**/TestExJPF.java`
  - `**/TestLazy*.java`
  - `**/TestPathCondition.java`
  - `**/TestStringBuilder.java`
  - `**/strings/**`
  - `**/TestSymbolicListener.java`
  - `**/TestSymbolicOutput.java`
  - `**/TestSymbolicJPF.java`
  - `**/Test*$*.class` (inner/anonymous test classes — present in Ant `build.xml:265`)

#### Scenario: ExSymExe Programs Not Executed

- **WHEN** `mvn test` is executed
- **THEN** 129 `ExSymExe*.java` files are NOT executed as tests (they do not match the `**/Test*.java` include pattern)
- **AND** they ARE compiled as part of the test source root

### Requirement: Clean Build (FR01)

#### Scenario: Clean

- **WHEN** `mvn clean` is executed
- **THEN** each module's `target/` directory is removed
- **AND** no compiled classes or JARs remain

## REMOVED Requirements

### Requirement: Ant Build Targets

The `build.xml` file and all Ant targets (`compile`, `build`, `jar`, `test`, `dist`, `clean`) are removed. **Reason**: Replaced by Maven lifecycle (`mvn compile`, `mvn package`, `mvn test`, `mvn clean`). Complete deletion per P3 principle — no backward-compatibility wrapper scripts.
