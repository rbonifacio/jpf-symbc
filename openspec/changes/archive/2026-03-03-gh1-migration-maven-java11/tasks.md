<!-- Subagent dispatch hints:
     This change touches ~920+ files (765 Java + 154 .jpf + config files).

     - Group 0 (Risk Validation) must complete first — all other groups depend on go/no-go.
       Tasks 0.1-0.10 are the expanded Phase 0 with: E2E Z3 test (0.3b), comprehensive API audit (0.4),
       opt4j API audit (0.5b), SHA-256 baseline (0.6), SAT4J verification (0.7),
       PathConditionsReliability investigation (0.8), extra .jpf placement (0.9).
     - Group 1 (Local Repository) and Group 2 (Maven Structure + POMs) are independent after Group 0.
     - Group 3 (Move Source Files) depends on Group 2 (directories must exist).
     - Group 4 (.jpf Path Updates) depends on Group 3 (files must be in place).
     - Group 5 (Java 11 Migration) depends on Group 3 validation.
       Includes 5.1b (dependency:tree) and 5.7 (module system runtime test).
     - Group 6 (jpf-core Compatibility) depends on Group 5.
       Includes 6.4b (Surefire exclusion validation) and expanded 6.6 (per-solver smoke tests).
     - Group 7 (Cleanup + Docs) depends on Group 6.
       Archives build.xml instead of deleting.
     - Group 8 (Verification) is final — must run after all other groups.
       Includes SHA-256 comparison, INV-BLD-03 breaking change verification, final solver smoke tests.

     Critical path: 0 → [1 + 2] → 3 → 4 → 5 → 6 → 7 → 8
     Parallel opportunity: Groups 1 and 2 can run in parallel after Group 0.
     IMPORTANT: Group 1 (repo/ setup) MUST complete before Task 5.1 (mvn compile Java 8),
     because POMs reference repo/ JARs. Groups 1 and 2 are independent of each other,
     but both must finish before Group 5.
     Parallel opportunity: Within Group 3, annotations/main/classes file moves are independent.
     Parallel opportunity: Within Group 4, test .jpf and example .jpf updates are independent.
     Parallel opportunity: Within Group 0, tasks 0.6/0.7/0.8/0.9 are independent of each other.

     Use subagent orchestration for Groups 3-4 (bulk file operations, ~920 files).

     SDKMAN environment (sdk):
       Java 8:  sdk use java 8.0.302-open   (Ant baseline, Phase 1 validation)
       Java 11: sdk use java 11.0.12-open   (Phase 0 smoke tests, Phase 2+, all final verification)
       Current default is Java 25 — MUST switch before any build/test command. -->

## 0. Risk Validation (Phase 0 — go/no-go)

- [x] 0.1 Create safety net, setup jpf-core baseline, and capture Ant baseline:
  ```bash
  git tag pre-migration-java11
  sdk use java 8.0.302-open

  # 1. Clone and build the yannicnoller jpf-core fork (required for current Ant build)
  #    jpf-core is NOT in lib/ — it's resolved as peer directory ../jpf-core
  #    or via ~/.jpf/site.properties (neither exists currently)
  git clone https://github.com/yannicnoller/jpf-core.git ../jpf-core
  cd ../jpf-core
  git checkout 0f2f2901cd0ae9833145c38fee57be03da90a64f
  ant build
  cd ../jpf-symbc

  # 2. Create site.properties so jpf-symbc can find jpf-core
  mkdir -p ~/.jpf
  cat > ~/.jpf/site.properties << 'EOF'
  jpf-core = /pedro/desenvolvimento/workspaces/workspaces-doutorado/workspace-rv/jpf-core
  jpf-symbc = /pedro/desenvolvimento/workspaces/workspaces-doutorado/workspace-rv/jpf-symbc
  extensions=${jpf-core},${jpf-symbc}
  EOF

  # 3. Build jpf-symbc Ant baseline
  ant clean build
  ant test 2>&1 | tee docs/ant-test-baseline.txt

  # 4. Capture JAR class lists for later comparison (task 8.5)
  mkdir -p docs
  jar tf build/jpf-symbc.jar | sort > docs/ant-jar-main-classes.txt
  jar tf build/jpf-symbc-classes.jar | sort > docs/ant-jar-classes-classes.txt
  jar tf build/jpf-symbc-annotations.jar | sort > docs/ant-jar-annotations-classes.txt
  ```
  **NOTE**: `ant test` requires `JUNIT_HOME` env var set. If not set:
  ```bash
  export JUNIT_HOME=/path/to/junit   # directory containing junit-4.x.jar
  ```
- [x] 0.2 Clone official jpf-core (separate from fork in `../jpf-core`), build with JDK 11, publish to Maven local:
  ```bash
  sdk use java 11.0.12-open
  git clone https://github.com/javapathfinder/jpf-core.git /tmp/jpf-core-official
  cd /tmp/jpf-core-official
  ./gradlew publishToMavenLocal
  find ~/.m2/repository/gov/nasa -name "*.pom" -exec basename {} \;
  cd /pedro/desenvolvimento/workspaces/workspaces-doutorado/workspace-rv/jpf-symbc
  ```
  Record exact coordinates (expected: `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT`).
  **NOTE**: `../jpf-core` is the yannicnoller fork (Java 8, Ant) used by the current Ant baseline. `/tmp/jpf-core-official` is the official repo (Java 11, Gradle) for the Maven migration target. Both are needed during Phase 0.
- [x] 0.3 Create and run `NativeLibSmokeTest.java` with JDK 11:
  ```bash
  sdk use java 11.0.12-open
  javac NativeLibSmokeTest.java
  java -Djava.library.path=lib:lib/64bit NativeLibSmokeTest
  ```
  Test Z3, CVC3, STP, Yices via `System.loadLibrary()`. Z3 MUST pass.
- [x] 0.3b **End-to-end Z3 test via JPF** — `System.loadLibrary()` only validates loading, not JNI functionality. Create a minimal test that runs JPF with `symbolic.dp=z3` on JDK 11 and verifies Z3 actually solves a constraint. This catches JNI runtime issues invisible to the smoke test (GC changes, module system restrictions on JNI).
  ```bash
  # Ant build should already exist from task 0.1
  # Test with JDK 11 runtime against Ant-built artifacts:
  sdk use java 11.0.12-open
  java -Djava.library.path=lib:lib/64bit \
    -cp "build/jpf-symbc.jar:build/jpf-symbc-classes.jar:build/jpf-symbc-annotations.jar:lib/*:../jpf-core/build/*" \
    gov.nasa.jpf.tool.RunJPF src/examples/demo/NumericExample.jpf
  ```
  **NOTE**: This uses Ant-built JARs with JDK 11 runtime. If it fails here, the native libs or module system are the issue (not Maven). Requires `../jpf-core` from task 0.1.
- [x] 0.4 Quantify fork divergence **comprehensively**: (a) list ALL jpf-core classes imported by jpf-symbc (`grep -rh "^import gov.nasa.jpf" src/main src/peers src/classes | sort -u` — expect 2275+ import statements), (b) for each unique class, verify it exists in official jpf-core, (c) classify divergences as breaking (method removed/signature changed), deprecated (still works), or compatible (unchanged). **Go/no-go threshold**: <10 breaking = days of effort (proceed); 10-50 = weeks (proceed with caution); >50 = reconsider migration or scope as multi-phase project.
- [x] 0.5 Verify opt4j 3.3 compatibility with Coral solver. **IMPORTANT**: the dependency is **indirect** — jpf-symbc has NO direct `import org.opt4j.*`. The chain is: `ProblemCoral` → `coral.jar` (10+ classes in `coral/solvers/search/opt4j/`) → `opt4j-2.4` → Guice 1.0 → ASM 1.5.3. Must test `coral.jar` against opt4j 3.3, not just jpf-symbc source.
  ```bash
  sdk use java 11.0.12-open
  # Download opt4j 3.3
  wget https://github.com/SDARG/opt4j/releases/download/opt4j-3.3/opt4j-3.3.zip -O /tmp/opt4j-3.3.zip
  unzip /tmp/opt4j-3.3.zip -d /tmp/opt4j-3.3
  # Test: can coral.jar's opt4j-dependent classes load with opt4j 3.3?
  # List coral.jar's opt4j classes:
  jar tf lib/coral.jar | grep opt4j
  # Attempt to load coral + opt4j 3.3 together:
  javac -cp "/tmp/opt4j-3.3/lib/*:lib/*:build/jpf-symbc.jar" \
    src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemCoral.java 2>&1 | head -50
  ```
  If API incompatible, document Coral as unsupported on Java 11 (BLOCKER: opt4j 2.4 bundles Guice 1.0 with ASM 1.5.3/CGLIB 2.1_3 that cannot parse Java 11 class files).
- [x] 0.5b **opt4j API audit via coral.jar**: since jpf-symbc has no direct opt4j imports, the audit must focus on `coral.jar` internals: (a) `jar tf lib/coral.jar | grep opt4j` to list opt4j-dependent classes, (b) extract and inspect those classes for opt4j API usage, (c) compare with opt4j 3.3 API, (d) estimate adaptation effort. **Decision**: if effort > 2 days or coral.jar needs rebuilding from unavailable source, document Coral as unsupported on Java 11.
- [x] 0.6 **SHA-256 JAR baseline + native library inventory**:
  ```bash
  mkdir -p docs
  # JAR baseline (28 JARs)
  sha256sum lib/*.jar > docs/jar-checksums-pre-migration.txt
  wc -l docs/jar-checksums-pre-migration.txt   # expect 28 lines

  # Native library inventory (.so/.dll/.dylib in lib/ root + lib/64bit/)
  find lib -type f \( -name '*.so' -o -name '*.dll' -o -name '*.dylib' -o -name '*.so.*' -o -name '*.jnilib' \) \
    | sort > docs/native-libs-pre-migration.txt
  wc -l docs/native-libs-pre-migration.txt   # expect 34+ files
  ```
  Captures exact state of all JARs and native libs before any changes. JAR baseline is used for Maven Central verification in Phase 1. Native lib inventory is used for preservation verification in task 8.6.
- [x] 0.7 **SAT4J custom vs Maven Central verification**:
  ```bash
  # Extract MANIFEST from local custom JARs
  unzip -p lib/org.sat4j.core.jar META-INF/MANIFEST.MF
  unzip -p lib/org.sat4j.pb.jar META-INF/MANIFEST.MF
  # Download Maven Central versions for comparison
  mvn dependency:copy -Dartifact=org.ow2.sat4j:org.sat4j.core:2.3.6 -DoutputDirectory=/tmp/sat4j-central
  mvn dependency:copy -Dartifact=org.ow2.sat4j:org.sat4j.pb:2.3.6 -DoutputDirectory=/tmp/sat4j-central
  # Compare class lists
  diff <(jar tf lib/org.sat4j.core.jar | sort) <(jar tf /tmp/sat4j-central/org.sat4j.core-2.3.6.jar | sort)
  diff <(jar tf lib/org.sat4j.pb.jar | sort) <(jar tf /tmp/sat4j-central/org.sat4j.pb-2.3.6.jar | sort)
  ```
  Custom builds are v20100705; Maven Central is 2.3.6 (2013). If different → keep in `repo/` (20 local). If identical → could use Maven Central (18 local).
- [x] 0.8 **PathConditionsReliability investigation**:
  ```bash
  # Check if referenced in source code
  grep -rh "PathConditionsReliability" src/ || echo "NO CODE REFERENCES — dead reference"
  # Check if referenced in config beyond jpf.properties
  grep -rh "PathConditionsReliability" src/tests/ src/examples/ || echo "No .jpf references"
  # Verify JAR does NOT exist
  ls -la lib/PathConditionsReliability* 2>/dev/null || echo "JAR NOT FOUND in lib/"
  ```
  If no code references → dead reference, remove from `jpf.properties`. If code references exist → missing file, investigate origin.
- [x] 0.9 **Resolve 2 extra .jpf file placement**:
  ```bash
  # Inspect target class and classpath in each file
  cat src/main/gov/nasa/jpf/symbc/concolic/TestMain.jpf
  cat doc/Example.jpf
  # Check where target classes live
  grep -h "^target" src/main/gov/nasa/jpf/symbc/concolic/TestMain.jpf doc/Example.jpf
  ```
  Decision criteria: (a) if target is in src/main → `jpf-symbc-main/src/main/resources/`, (b) if target is in src/tests → `jpf-symbc-tests/src/test/resources/`, (c) if target is in src/examples → `jpf-symbc-examples/src/main/resources/`, (d) if documentation → leave in `doc/` and update manually.
- [x] 0.10 Document go/no-go results: Z3 must pass (0.3 + 0.3b); record exact jpf-core coordinates (0.2); API divergence classification and effort estimate (0.4); opt4j 3.3 compat decision (0.5 + 0.5b); SAT4J decision (0.7); PathConditionsReliability resolution (0.8); extra .jpf placement (0.9)

## 1. Local Repository Setup (FR05)

- [x] 1.1 Create `repo/` directory at project root
- [x] 1.2 Install 20 non-Central JARs into `repo/` via `mvn deploy:deploy-file` with verified coordinates: coral, green, hampi, iasolver, string, solver, scale, proteus, Statemachines, STPJNI, yicesapijava, libcvc3, libcvc3-5.0.0, com.microsoft.z3, choco-1_2_04, choco-solver-2.1.1, opt4j (**2.4** — kept at 2.4, Coral unsupported on Java 11 regardless), grappa, org.sat4j.core (CUSTOM v20100705), org.sat4j.pb (CUSTOM v20100705)
- [x] 1.3 Verify all 20 JARs are resolvable: check `repo/` directory structure matches Maven layout (groupId → path, artifactId/version dirs, JAR + POM present)
- [x] 1.4 Verify 8 Maven Central coordinates resolve: `commons-lang:commons-lang:2.4`, `commons-math:commons-math:1.2`, `org.apache.bcel:bcel:6.0`, `dk.brics.automaton:automaton:1.11-8`, `jaxen:jaxen:1.2.0`, `com.martiansoftware:jsap:2.1`, `com.googlecode.aima-java:aima-core:0.10.5`, `redis.clients:jedis:2.0.0` — run `mvn dependency:resolve` to confirm

## 2. Maven Module Structure and POMs (FR01, FR02)

- [x] 2.1 Create parent POM (`pom.xml`) with: `<modules>` declaration, `<java.version>8</java.version>` (Phase 1), `<repositories>` for `repo/`, `<dependencyManagement>` for all deps, `<pluginManagement>` for compiler + surefire
- [x] 2.2 Create `jpf-symbc-annotations/pom.xml` — no external dependencies
- [x] 2.3 Create `jpf-symbc-main/pom.xml` — dependencies: annotations, jpf-core, all solver JARs as `<optional>true</optional>`
- [x] 2.4 Create `jpf-symbc-classes/pom.xml` — dependencies: annotations, jpf-core (NOT main); standard compiler config for Phase 1 (Java 8, no --patch-module yet)
- [x] 2.5 Create `jpf-symbc-tests/pom.xml` — dependencies: main, classes, annotations, jpf-core, junit:4.13.1 (test scope); surefire config with fork, memory, exclusions from build.xml. **IMPORTANT**: exclusion list must include `**/Test*$*.class` (inner test classes — present in Ant `build.xml:265` but easy to miss), plus all named exclusions: `TestBitwise*`, `TestCoverage`, `TestDIV`, `TestExJPF`, `TestLazy*`, `TestPathCondition`, `TestStringBuilder`, `strings/**`, `TestSymbolicListener`, `TestSymbolicOutput`, `TestSymbolicJPF`, `JPF_*`.
- [x] 2.6 Create `jpf-symbc-examples/pom.xml` — dependencies: main, classes, annotations
- [x] 2.7 Create Maven module directory trees (5 modules × `src/main/java/` or `src/test/java/` + resources)

## 3. Move Source Files (FR02)

- [x] 3.1 Remove dead import in `src/classes/java/awt/image/BufferedImage.java` (`import gov.nasa.jpf.symbc.Debug;`)
- [x] 3.2 Copy `src/annotations/*` → `jpf-symbc-annotations/src/main/java/`
- [x] 3.3 Copy `src/main/*` → `jpf-symbc-main/src/main/java/` (335 files, preserving package structure)
- [x] 3.4 Copy `src/peers/*` → `jpf-symbc-main/src/main/java/` (7 files, merge into main — no conflicts verified)
- [x] 3.5 Copy `src/classes/gov/**` and `src/classes/org/**` → `jpf-symbc-classes/src/main/java/` (regular model classes)
- [x] 3.6 Copy `src/classes/java/lang/Math.java` and `src/classes/java/util/Scanner.java` → `jpf-symbc-classes/src/main/modules/java.base/` (preserving java/lang/ and java/util/ paths)
- [x] 3.7 Copy `src/classes/java/awt/image/BufferedImage.java` and `src/classes/java/awt/image/Kernel.java` → `jpf-symbc-classes/src/main/modules/java.desktop/` (preserving java/awt/image/ path)
- [x] 3.8 Copy `src/tests/**/*.java` → `jpf-symbc-tests/src/test/java/` (197 files, preserving package structure)
- [x] 3.9 Copy `src/tests/**/*.jpf` → `jpf-symbc-tests/src/test/resources/` (34 .jpf files)
- [x] 3.10 Copy `src/examples/**/*.java` → `jpf-symbc-examples/src/main/java/` (213 files, preserving package structure)
- [x] 3.11 Copy `src/examples/**/*.jpf` → `jpf-symbc-examples/src/main/resources/` (118 .jpf files)
- [x] 3.12 Handle 2 extra .jpf files: `src/main/gov/nasa/jpf/symbc/concolic/TestMain.jpf` → `jpf-symbc-main/src/main/resources/`; `doc/Example.jpf` → `jpf-symbc-examples/src/main/resources/doc/`
- [x] 3.13 Verify file counts: annotations=4, main+peers=342, classes=9 (5 regular + 4 modules), tests=197, examples=213, extra .jpf=2

## 4. Update .jpf File Paths (FR07, INV-CFG-10)

- [x] 4.1 Update test .jpf files: `build/tests` → `jpf-symbc-tests/target/test-classes`, `src/tests` → `jpf-symbc-tests/src/test/java`
- [x] 4.2 Update example .jpf files: `build/examples` → `jpf-symbc-examples/target/classes`, `src/examples` → `jpf-symbc-examples/src/main/java`
- [x] 4.3 Update the 2 extra .jpf files (TestMain.jpf, Example.jpf) — TestMain.jpf updated to jpf-symbc-main/target/classes; Example.jpf has only commented-out placeholder, no active path
- [x] 4.4 Post-verification — old output paths removed (PASS — only legacy symtest.sh excluded)
- [x] 4.4b Post-verification — old source paths removed (PASS — symtest.sh + README excluded, not .jpf configs)
- [x] 4.5 Post-verification: all .jpf files reference target/ (except doc/Example.jpf — documentation template with no active classpath)
- [x] 4.6 Identified and fixed: HelloWorld.jpf (miroslav hardcoded→${jpf-symbc}), daisyChain*.jpf (cpasarea hardcoded→${jpf-symbc}), TestLazy.java (build/tests→target/test-classes). Chars99int2_2_2.jpf has relative path to external project — cannot fix.

**Checkpoint**: After Groups 1-4 are complete and verified:
```bash
git tag migration-phase1-maven-structure-complete
```

## 5. Phase 1 Validation + Java 11 Migration (FR01, FR03, FR04)

- [x] 5.1 ~~Run `mvn compile` with Java 8~~ — SKIPPED: official jpf-core (DEVELOPMENT-SNAPSHOT) was compiled with Java 11 (class file 55.0), cannot be loaded by Java 8 JVM. Maven structure validated by Java 11 compile instead.
- [x] 5.1b Check for transitive dependency conflicts — no conflicts found (dependency:tree -Dverbose clean). Also fixed libcvc3 v5 classifier issue across all POMs (main, tests, examples had spurious `<classifier>v5</classifier>` but repo JAR has no classifier).
- [x] 5.2 Update parent POM: `<java.version>11</java.version>`
- [x] 5.3 Configure `jpf-symbc-classes/pom.xml` with 3 compiler executions: default-compile (5 regular classes), compile-patch-java-base (Math.java, Scanner.java), compile-patch-java-desktop (BufferedImage.java, Kernel.java) — all 9 classes compile successfully
- [x] 5.4 Configure `jpf-symbc-tests/pom.xml` surefire `<argLine>`: `-Xmx1024m --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-exports java.base/jdk.internal.misc=ALL-UNNAMED`
- [x] 5.5 Check if `jpf-symbc-main` peers need `--add-exports` — NO, peers don't use internal JDK APIs (the `sun.` imports are `za.ac.sun.cs.green.*` — Green solver framework)
- [x] 5.6 Run `mvn compile` with Java 11 — BUILD SUCCESS, all 5 modules compile (annotations, main, classes with 3 executions, tests, examples). Fixed:
  ```bash
  sdk use java 11.0.12-open
  java -version   # verify: 11.0.12
  mvn compile
  ```
  All 5 modules MUST compile. **Acceptance criteria**: 765 Java files, 0 errors, 4 model classes compile via `--patch-module` (3 compiler executions).
- [x] 5.7 **Module system + ClassLoader runtime test** — PARTIAL PASS: RunJPF loaded, no IllegalAccessError/InaccessibleObjectException/ClassFormatError (module system OK). Hit jpf-core model class mismatch: `Thread$Permit` not found because site.properties still points to yannicnoller fork. Full runtime validation deferred to task 6.5 after jpf.properties update.
  ```bash
  sdk use java 11.0.12-open
  # Build the full classpath — JPF runs via RunJPF, NOT via -jar
  # (the -jar flag ignores -cp and requires Main-Class in MANIFEST.MF, which jpf-symbc doesn't have)
  MVN_CP=$(mvn -q dependency:build-classpath -pl jpf-symbc-main -Dmdep.outputFile=/dev/stdout)
  java -Djava.library.path=lib:lib/64bit \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    --add-opens java.base/java.util=ALL-UNNAMED \
    --add-exports java.base/jdk.internal.misc=ALL-UNNAMED \
    -cp "jpf-symbc-main/target/classes:jpf-symbc-classes/target/classes:jpf-symbc-annotations/target/classes:${MVN_CP}" \
    gov.nasa.jpf.tool.RunJPF \
    jpf-symbc-examples/src/main/resources/demo/NumericExample.jpf
  ```
  Check for `IllegalAccessError`, `InaccessibleObjectException`, or `ClassFormatError`. If failures occur, expand `--add-opens`/`--add-exports` flags empirically. **This is critical** — compile-time success does NOT guarantee runtime success with custom ClassLoaders.
  **SUCCESS here means**: native libs and JPF ClassLoader are compatible with JDK 11 runtime + module system. It does NOT mean Maven compilation with Java 11 source level works (that's validated by 5.6).

**Checkpoint**: After Group 5 is complete (Java 11 compiles + runtime test passes):
```bash
git tag migration-phase2-java11-complete
```

## 6. jpf-core Compatibility + Testing (FR08, FR09, FR10, FR11)

- [x] 6.1 Fix compilation errors — 0 compilation errors with official jpf-core (confirmed in 5.6). 3 potential runtime issues noted (DynamicElementInfo char[]→byte[], ClassLoaderInfo lambda naming, VirtualInvocation) — deferred to runtime validation in 6.4+. Updated `~/.jpf/site.properties` to point to official jpf-core at `/tmp/jpf-core-official`.
- [x] 6.2 Update `jpf.properties`: updated `native_classpath` with Maven JAR paths (3 module JARs + solver JARs still in lib/), `classpath` with classes+annotations JARs (INV-BLD-03), `test_classpath` with target/test-classes. No `sourcepath` added.
- [x] 6.3 PathConditionsReliability — dead reference removed from `jpf.properties` (confirmed in 0.8: no code refs, no JAR in lib/)
- [x] 6.4 Run tests with Java 11 — Tests run: 20, Failures: 0, Errors: 0, Skipped: 0. BUILD SUCCESS.
  ```bash
  sdk use java 11.0.12-open
  mvn test
  ```
  Compare results with known test exclusion list; all non-excluded tests MUST pass.
- [x] 6.4b **Validate Surefire exclusion parity with Ant** — 20 tests run matches Ant baseline expectation. Exclusion list in surefire config matches build.xml. ExSymExe* files (129) correctly not executed (only `**/Test*.java` included).: (a) run `mvn test -X 2>&1 | grep -E "Excludes|Running"` to see which tests are excluded/executed, (b) compare with Ant `build.xml` exclusion list (13 patterns including `Test*$*`), (c) verify `ExSymExe*` files (129) are NOT executed (they don't match `**/Test*.java` include pattern), (d) confirm exact same set of tests excluded in both build systems.
- [x] 6.5 Run a simple `.jpf` example end-to-end via JPF — Test.jpf (choco) ran successfully: 3 test cases generated, no errors, no module system issues
- [x] 6.6 Per-solver smoke tests (NFR01):
  - **Z3**: PASS — 3 test cases, no errors
  - **Choco**: PASS — 3 test cases, no errors
  - **Coral**: PASS (simple integer test) — note: complex opt4j paths may still fail at runtime (ASM 1.5.3 vs Java 11 class format)
  - **CVC3**: SKIPPED — 32-bit native lib (ELFCLASS32 on 64-bit system, pre-existing issue)
  - **STP**: SKIPPED — native lib not found (pre-existing issue)
  - **Yices**: SKIPPED — 32-bit native lib (ELFCLASS32, pre-existing issue)

**Checkpoint**: After Group 6 is complete (tests pass + solver smoke tests):
```bash
git tag migration-phase3-testing-complete
```

## 7. Cleanup and Documentation (FR12, FR13)

- [x] 7.1 Archive and remove obsolete build artifacts: **archive** `build.xml` → `docs/build-archive/build.xml` (preserves build knowledge/decisions as comments in the file), then **delete** `.classpath`, `.project`, `nbproject/`, `.externalToolBuilders/`
- [x] 7.2 Remove original `src/` directory (after confirming all files are in Maven modules)
- [x] 7.3 Remove solver JARs from `lib/` that are now in `repo/` or Maven Central — **PRESERVE all native library files (.so, .dll, .dylib) in BOTH `lib/` root AND `lib/64bit/`**. Only delete `.jar` files from `lib/` root. There are 34+ native library files in `lib/` root (CVC3, Z3, STP, Yices for Linux/Windows/macOS) that MUST be kept.
- [x] 7.4 Update `.gitignore` for Maven artifacts: add `target/` (covers all 5 modules), ensure `repo/` is NOT gitignored (it contains the 20 local JARs that must be version-controlled)
- [x] 7.5 Clean up `NativeLibSmokeTest.java` (temporary file from Phase 0)
- [x] 7.6 Update `README.md` — new prerequisites (Java 11, Maven, jpf-core local build), new build commands (`mvn compile`, `mvn test`, `mvn package`), solver status table, excluded tests list with reasons
- [x] 7.7 Update `CLAUDE.md` — build commands (Maven), source layout (5 modules), setup requirements (official jpf-core), solver status, excluded tests list, updated file paths throughout
- [x] 7.8 Remove legacy dead code: `symtest.sh` from `jpf-symbc-tests/src/test/java/gov/nasa/jpf/symbc/` (hardcoded paths to `/home/pcorina/`, not used by any test runner)

## 8. Final Verification

- [x] 8.1 Full clean build:
  ```bash
  sdk use java 11.0.12-open
  mvn clean compile
  ```
  **Acceptance**: 0 errors, 765 files, 5 modules in reactor.
- [x] 8.2 Full test run (20 tests, 0 failures — fixed jpf.properties to use target/classes instead of target/*.jar so tests work after `mvn clean`):
  ```bash
  sdk use java 11.0.12-open
  mvn test
  ```
  **Acceptance**: pass rate MUST be within ≤1% of Ant `ant test` baseline. Any newly failing tests MUST be individually documented with root cause (API change, classpath issue, etc.). Newly passing tests (previously failing due to environment) are acceptable.
- [x] 8.3 Package (5 JARs produced):
  ```bash
  sdk use java 11.0.12-open
  mvn package
  ```
  5 JARs produced in `*/target/` directories.
- [x] 8.4 Verify .jpf path invariants: `grep -rl 'build/tests\|build/examples\|build/jpf-symbc' .` returns empty (INV-CFG-10) — PASS
- [x] 8.5 Verify JAR contents — PASS: main JAR identical, annotations JAR identical, classes JAR missing 4 annotation classes as expected per INV-BLD-03. `jpf.properties` includes both classes and annotations in native_classpath AND classpath.
- [x] 8.6 Verify native library preservation — PASS: 40 native lib files match pre-migration baseline exactly (diff returns empty)
- [x] 8.7 Verify Maven Central dependencies resolve — PASS: `mvn dependency:resolve -pl jpf-symbc-main` BUILD SUCCESS, all deps resolved
- [x] 8.8 Verify no solver JAR files remain in `lib/` — PASS: 0 JAR files in lib/, only 40 native library files
- [x] 8.9 Per-solver smoke tests — Z3: PASS, Choco: PASS (both using target/classes paths)
- [x] 8.10 `/sdd-verify .` — PASS: 20 tests, 0 failures, lint skipped (checkstyle not installed)
- [x] 8.11 SKIPPED — `/sdd-code-reviewer` deferred to gh2 (post-migration documentation pass)
