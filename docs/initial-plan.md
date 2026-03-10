# Migration Plan: jpf-symbc → Maven Multi-Module + Java 11

## Context

jpf-symbc currently depends on a specific fork of jpf-core (yannicnoller/jpf-core) that uses Java 8. The official jpf-core (javapathfinder/jpf-core) has already migrated to Java 11 with a Gradle build. The goal is to migrate jpf-symbc to work with the current jpf-core, starting with the migration from Ant to a multi-module Maven setup and from Java 8 to Java 11.

**Current state of jpf-symbc:**
- Build: Apache Ant (`build.xml`)
- Java: 8
- jpf-core: yannicnoller fork (Java 8, Ant)
- 6 source roots: `src/main`, `src/peers`, `src/annotations`, `src/classes`, `src/tests`, `src/examples`
- 28 JARs in `lib/`, most without a Maven Central artifact
- 3 JARs produced: `jpf-symbc.jar`, `jpf-symbc-classes.jar`, `jpf-symbc-annotations.jar`

**Current state of the official jpf-core:**
- Build: Gradle (`build.gradle`)
- Java: 11
- `java.*` model classes use `--patch-module` to compile (see `gradle/source-sets.gradle`)
- Publishes artifacts via `./gradlew publishToMavenLocal` (groupId `gov.nasa`)
- Tests use `--add-opens` and `--add-exports` for Java 11 modules

**Java 8 → 11 compatibility analysis:**
- No use of internal `sun.*` or `com.sun.*` APIs in the source code
- No use of APIs removed in Java 11 (javax.xml.bind, java.activation, CORBA)
- No use of problematic reflection (setAccessible, etc.)
- Lambdas and Streams used in ~45 files — fully compatible
- Main challenge: compiling `java.*` model classes with the module system

**Model classes and their Java modules (verified):**

| Class | Java Module | --patch-module required |
|--------|-------------|--------------------------|
| `java.lang.Math` | `java.base` | `--patch-module java.base=...` |
| `java.util.Scanner` | `java.base` | `--patch-module java.base=...` |
| `java.awt.image.BufferedImage` | `java.desktop` | `--patch-module java.desktop=...` |
| `java.awt.image.Kernel` | `java.desktop` | `--patch-module java.desktop=...` |

**Cross-dependencies between model classes (verified):**

| Class | Imports | Impact |
|--------|---------|---------|
| `java.util.Scanner` | `gov.nasa.jpf.symbc.Debug` | Requires `--add-reads java.base=ALL-UNNAMED` |
| `java.awt.image.BufferedImage` | `gov.nasa.jpf.symbc.Debug` (import present but **usage is commented out**) | Remove dead import; no functional impact |
| `java.lang.Math` | (no cross-dependencies) | Clean |
| `java.awt.image.Kernel` | (no cross-dependencies) | Clean |
| `gov.nasa.jpf.symbc.Debug` | `gov.nasa.jpf.vm.Verify` (from jpf-core) | jpf-symbc-classes depends on jpf-core |

**Dependencies between source roots (empirically verified):**

| Source root | Imports from | Does NOT import from |
|-------------|-----------|-----------------|
| `src/annotations` | (none) | — |
| `src/main` | jpf-core, annotations | `src/classes` (confirmed: 0 imports) |
| `src/peers` | jpf-core | `src/classes` (confirmed: 0 imports) |
| `src/classes/gov/**` | jpf-core (`Verify`), own module (`Debug`) | `src/main` (confirmed: 0 imports) |
| `src/classes/java/**` | `Debug` (same classes module) | `src/main` |
| `src/tests` | all of the above + junit | — |
| `src/examples` | main, classes, annotations | — |

> Implication: `jpf-symbc-classes` does **not** depend on `jpf-symbc-main`. The only dependencies are: `annotations` + `jpf-core`.

---

## Architectural Decisions

| Decision | Choice | Justification |
|---------|---------|---------------|
| Maven Structure | Multi-module | Clear separation of concerns, one JAR per module |
| JARs without Maven Central | Local repository (`repo/`) | Portable, clean, no deprecated system scope |
| Solvers | Keep all (including CVC3) | Preserve full compatibility |
| jpf-core | `./gradlew publishToMavenLocal` | No artifacts in Maven Central; local build is standard practice in the JPF ecosystem |

---

## Phase 0: Validation of Blocking Risks

> Goal: Before investing in the migration, validate the 3 risks that could block the entire project. Estimated effort: 1-2h.

### 0.1 Create a safety net

```bash
git tag pre-migration-java11
```

### 0.2 Install and verify jpf-core Maven coordinates

```bash
# Clone the official jpf-core (Java 11)
git clone https://github.com/javapathfinder/jpf-core.git
cd jpf-core
# Publish to local Maven repository (~/.m2/repository)
./gradlew publishToMavenLocal
```

**Mandatory verification** — before writing any POM:

```bash
# List the actual published artifacts
find ~/.m2/repository/gov/nasa -name "*.pom" | head -20
# Note the EXACT groupId, artifactId, and version
```

Expected artifacts (confirm after execution):
- `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` (jpf.jar — main + peers + annotations)
- `gov.nasa:jpf-annotations:DEVELOPMENT-SNAPSHOT`
- `gov.nasa:jpf-classes:DEVELOPMENT-SNAPSHOT`

> **Success criterion:** Maven coordinates confirmed. If they are different from what's expected, update all references in the plan before proceeding.

### 0.3 Smoke test of native libraries (JNI) with Java 11

The native libraries (.so/.dll/.dylib) in `lib/` were compiled years ago against specific JDKs and glibc. This test validates if they load in JDK 11.

```java
// NativeLibSmokeTest.java — compile and run with JDK 11
public class NativeLibSmokeTest {
    public static void main(String[] args) {
        String[] libs = {"z3", "cvc3", "stpjni", "yicesapijava"};
        for (String lib : libs) {
            try {
                System.loadLibrary(lib);
                System.out.println("[OK]   " + lib);
            } catch (UnsatisfiedLinkError e) {
                System.out.println("[FAIL] " + lib + " — " + e.getMessage());
            }
        }
    }
}
```

```bash
# Run with java.library.path pointing to lib/64bit/
javac NativeLibSmokeTest.java
java -Djava.library.path=lib/64bit NativeLibSmokeTest
```

> **Success criterion:** Z3 must load (main solver). Failures in CVC3/STP/Yices do not block the migration — these solvers are optional and rarely used. Document the results for a go/no-go decision.

### 0.4 Quantify divergence from the jpf-core fork

Analyze the differences between the yannicnoller fork (currently used) and the official jpf-core (migration target), focusing on the APIs that jpf-symbc actually uses.

```bash
# 1. List jpf-core classes imported by jpf-symbc
grep -rh "^import gov.nasa.jpf" src/main src/peers src/classes src/tests \
  | sort -u | sed 's/import //' | sed 's/;$//' > /tmp/jpf-symbc-imports.txt

# 2. In the official jpf-core directory, compare with the fork
cd /path/to/jpf-core
git remote add fork https://github.com/yannicnoller/jpf-core.git
git fetch fork
# Diff between the fork and official on the files jpf-symbc uses
git diff fork/master..HEAD -- src/main/gov/nasa/jpf/ | diffstat
```

> **Success criterion:** Understand the scope of the changes. If there are changes in `InstructionFactory`, `ClassInfo`, or `MethodInfo`, estimate the adaptation effort before proceeding.

---

## Phase 1: Maven Multi-Module Structure (compiling with Java 8)

> Goal: Validate the Maven structure without changing the Java version. `mvn compile` must work with Java 8.

### 1.1 Prerequisite: jpf-core installed locally

> Already executed in Phase 0.2. Confirm that `~/.m2/repository/gov/nasa/` contains the artifacts.

### 1.2 Create a local repository for research JARs (`repo/`)

For each JAR without a Maven Central artifact, install it in the project's local repo:

```bash
# Example for each JAR:
mvn deploy:deploy-file \
  -DgroupId=gov.nasa.jpf.symbc -DartifactId=coral -Dversion=1.0.0 \
  -Dfile=lib/coral.jar -Dpackaging=jar \
  -Durl=file://$(pwd)/repo -DrepositoryId=project-local
```

**JARs for the project's local repository (`repo/`):**

Includes all JARs with no verified artifact in Maven Central:

| JAR | groupId | artifactId | version |
|-----|---------|------------|---------|
| coral.jar | gov.nasa.jpf.symbc | coral | 1.0.0 |
| green.jar | za.ac.sun.cs | green | 1.0.0 |
| hampi.jar | edu.stanford | hampi | 1.0.0 |
| iasolver.jar | gov.nasa.jpf.symbc | iasolver | 1.0.0 |
| string.jar | gov.nasa.jpf.symbc | string-solver | 1.0.0 |
| solver.jar | gov.nasa.jpf.symbc | solver | 1.0.0 |
| scale.jar | gov.nasa.jpf.symbc | scale | 1.0.0 |
| proteus.jar | gov.nasa.jpf.symbc | proteus | 1.0.0 |
| Statemachines.jar | gov.nasa.jpf.symbc | statemachines | 1.0.0 |
| STPJNI.jar | gov.nasa.jpf.symbc | stp-jni | 1.0.0 |
| yicesapijava.jar | gov.nasa.jpf.symbc | yices-api | 1.0.0 |
| libcvc3.jar | gov.nasa.jpf.symbc | cvc3-legacy | 1.0.0 |
| libcvc3-5.0.0.jar | gov.nasa.jpf.symbc | cvc3 | 5.0.0 |
| PathConditionsReliability-0.0.1.jar | gov.nasa.jpf.symbc | pc-reliability | 0.0.1 |
| grappa.jar | att.grappa | grappa | 1.0.0 |
| com.microsoft.z3.jar | com.microsoft | z3 | 4.8.14 |
| opt4j-2.4.jar | org.opt4j | opt4j | 2.4 |
| choco-1_2_04.jar | choco | choco-solver | 1.2.04 |
| choco-solver-2.1.1-*.jar | choco | choco-solver | 2.1.1 |

> **Note:** Z3, Choco 1.2/2.1.1, and opt4j 2.4 **were not found on Maven Central** with the originally planned coordinates. All should go into the local `repo/`.

**JARs WITH a verified equivalent on Maven Central:**

| Current JAR | Maven Central (verified) |
|-----------|---------------------------|
| commons-lang-2.4.jar | `org.apache.commons:commons-lang:2.4` |
| commons-math-1.2.jar | `org.apache.commons:commons-math:1.2` |
| bcel.jar | `org.apache.bcel:bcel:6.0` |
| automaton.jar | `dk.brics.automaton:automaton:1.11-8` |
| jaxen.jar | `jaxen:jaxen:1.2.0` |
| JSAP-2.1.jar | `com.martiansoftware:jsap:2.1` |
| aima-core.jar | `com.googlecode.aima-java:aima-core:0.10.5` |
| org.sat4j.core.jar | `org.ow2.sat4j:org.ow2.sat4j.core:2.3.6` |
| org.sat4j.pb.jar | `org.ow2.sat4j:org.ow2.sat4j.pb:2.3.6` |
| jedis-2.0.0.jar | `redis.clients:jedis:2.0.0` (verify exact available version) |

### 1.3 Pre-cleanup: remove dead import

Before moving files, remove the unused import in `BufferedImage.java`:

```java
// src/classes/java/awt/image/BufferedImage.java — line 28
// REMOVE: import gov.nasa.jpf.symbc.Debug;  (the code that used it is commented out)
```

### 1.4 Create directory structure

```
jpf-symbc/
├── pom.xml                                  ← Parent POM
├── repo/                                    ← Project's local Maven repository
├── jpf.properties                           ← Updated for new paths
├── lib/                                     ← Kept (native libs .so/.dll/.dylib)
│
├── jpf-symbc-annotations/
│   ├── pom.xml
│   └── src/main/java/
│       └── gov/nasa/jpf/symbc/
│           ├── Concrete.java
│           ├── Partition.java
│           ├── Preconditions.java
│           └── Symbolic.java
│
├── jpf-symbc-main/
│   ├── pom.xml
│   └── src/main/java/
│       ├── gov/nasa/jpf/symbc/              ← src/main/ + src/peers/ (merged, no conflicts verified)
│       │   ├── SymbolicListener.java
│       │   ├── SymbolicInstructionFactory.java
│       │   ├── JPF_java_lang_Math.java      ← (from src/peers/)
│       │   ├── JPF_gov_nasa_jpf_symbc_Debug.java  ← (from src/peers/)
│       │   ├── bytecode/
│       │   ├── numeric/
│       │   ├── string/
│       │   ├── heap/
│       │   ├── arrays/
│       │   ├── concolic/
│       │   └── ...
│       ├── edu/ucsb/cs/vlab/
│       └── vlab/cs/ucsb/edu/
│
├── jpf-symbc-classes/
│   ├── pom.xml
│   ├── src/main/java/                       ← Regular classes (normal compilation)
│   │   ├── gov/nasa/jpf/symbc/              (Debug, DNN, TestPC, TestUtils)
│   │   └── org/sosy_lab/sv_benchmarks/      (Verifier)
│   └── src/main/modules/                    ← Classes that override JDK (--patch-module)
│       ├── java.base/                       ← java.base module
│       │   └── java/
│       │       ├── lang/Math.java
│       │       └── util/Scanner.java
│       └── java.desktop/                    ← java.desktop module
│           └── java/
│               └── awt/image/
│                   ├── BufferedImage.java
│                   └── Kernel.java
│
├── jpf-symbc-tests/
│   ├── pom.xml
│   ├── src/test/java/                       ← src/tests/*.java (including InvokeTest.java and ExSymExe*)
│   └── src/test/resources/                  ← src/tests/*.jpf (paths updated)
│
└── jpf-symbc-examples/
    ├── pom.xml
    ├── src/main/java/                       ← src/examples/*.java
    └── src/main/resources/                  ← src/examples/*.jpf (paths updated)
```

### 1.5 Parent POM (`pom.xml`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>gov.nasa.jpf</groupId>
    <artifactId>jpf-symbc-parent</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>pom</packaging>
    <name>JPF Symbolic PathFinder</name>

    <modules>
        <module>jpf-symbc-annotations</module>
        <module>jpf-symbc-main</module>
        <module>jpf-symbc-classes</module>
        <module>jpf-symbc-tests</module>
        <module>jpf-symbc-examples</module>
    </modules>

    <properties>
        <java.version>8</java.version>  <!-- Phase 1: Java 8; change to 11 in Phase 2 -->
        <maven.compiler.source>${java.version}</maven.compiler.source>
        <maven.compiler.target>${java.version}</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.build.resourceEncoding>UTF-8</project.build.resourceEncoding>
        <jpf-core.version>DEVELOPMENT-SNAPSHOT</jpf-core.version>
    </properties>

    <!--
        Uses ${maven.multiModuleProjectDirectory} to resolve the local repo/
        correctly from any submodule (Maven 3.3.1+).
    -->
    <repositories>
        <repository>
            <id>project-local</id>
            <url>file://${maven.multiModuleProjectDirectory}/repo</url>
        </repository>
    </repositories>

    <dependencyManagement>
        <!-- All dependencies with centralized versions -->
    </dependencyManagement>

    <build>
        <pluginManagement>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-compiler-plugin</artifactId>
                    <version>3.11.0</version>
                    <configuration>
                        <source>${java.version}</source>
                        <target>${java.version}</target>
                        <debug>true</debug>
                        <showDeprecation>true</showDeprecation>
                    </configuration>
                </plugin>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-surefire-plugin</artifactId>
                    <version>3.2.5</version>
                </plugin>
            </plugins>
        </pluginManagement>
    </build>
</project>
```

### 1.6 Modules — dependencies

**jpf-symbc-annotations:** no external dependencies

**jpf-symbc-main:**
- `gov.nasa.jpf:jpf-symbc-annotations` (internal module)
- `gov.nasa:jpf-core` (official jpf-core)
- All solver JARs as `<optional>true</optional>`

**jpf-symbc-classes:**
- `gov.nasa.jpf:jpf-symbc-annotations`
- `gov.nasa:jpf-core` (required: Debug.java imports `gov.nasa.jpf.vm.Verify`)
- ~~`gov.nasa.jpf:jpf-symbc-main`~~ — **NOT required** (verified: no imports from src/main in src/classes)

**jpf-symbc-tests:**
- `gov.nasa.jpf:jpf-symbc-main`
- `gov.nasa.jpf:jpf-symbc-classes`
- `gov.nasa.jpf:jpf-symbc-annotations`
- `gov.nasa:jpf-core`
- `junit:junit:4.13.1` (test scope)

**jpf-symbc-examples:**
- `gov.nasa.jpf:jpf-symbc-main`
- `gov.nasa.jpf:jpf-symbc-classes`
- `gov.nasa.jpf:jpf-symbc-annotations`

### 1.7 Move source files

```bash
# Annotations
mkdir -p jpf-symbc-annotations/src/main/java
cp -r src/annotations/* jpf-symbc-annotations/src/main/java/

# Main + Peers (merge — verified: no name conflicts between the 7 peers and src/main)
mkdir -p jpf-symbc-main/src/main/java
cp -r src/main/* jpf-symbc-main/src/main/java/
cp -r src/peers/* jpf-symbc-main/src/main/java/

# Classes — separate by Java module
# 1) Regular classes (gov.*, org.*)
mkdir -p jpf-symbc-classes/src/main/java
cp -r src/classes/gov jpf-symbc-classes/src/main/java/
cp -r src/classes/org jpf-symbc-classes/src/main/java/
# 2) java.base module (Math, Scanner)
mkdir -p jpf-symbc-classes/src/main/modules/java.base/java/lang
mkdir -p jpf-symbc-classes/src/main/modules/java.base/java/util
cp src/classes/java/lang/Math.java jpf-symbc-classes/src/main/modules/java.base/java/lang/
cp src/classes/java/util/Scanner.java jpf-symbc-classes/src/main/modules/java.base/java/util/
# 3) java.desktop module (BufferedImage, Kernel)
mkdir -p jpf-symbc-classes/src/main/modules/java.desktop/java/awt/image
cp src/classes/java/awt/image/BufferedImage.java jpf-symbc-classes/src/main/modules/java.desktop/java/awt/image/
cp src/classes/java/awt/image/Kernel.java jpf-symbc-classes/src/main/modules/java.desktop/java/awt/image/

# Tests (including ExSymExe* and InvokeTest)
mkdir -p jpf-symbc-tests/src/test/java
mkdir -p jpf-symbc-tests/src/test/resources
find src/tests -name "*.java" | while read f;
    rel="${f#src/tests/}"
    mkdir -p "jpf-symbc-tests/src/test/java/$(dirname "$rel")"
    cp "$f" "jpf-symbc-tests/src/test/java/$rel"
done
find src/tests -name "*.jpf" -exec cp {} jpf-symbc-tests/src/test/resources/ \;

# Examples
mkdir -p jpf-symbc-examples/src/main/java
mkdir -p jpf-symbc-examples/src/main/resources
find src/examples -name "*.java" | while read f;
    rel="${f#src/examples/}"
    mkdir -p "jpf-symbc-examples/src/main/java/$(dirname "$rel")"
    cp "$f" "jpf-symbc-examples/src/main/java/$rel"
done
find src/examples -name "*.jpf" -exec cp {} jpf-symbc-examples/src/main/resources/ \;
```

### 1.8 Update paths in the 152 .jpf files

All 152 `.jpf` files (34 in tests, 118 in examples) reference `${jpf-symbc}/build/tests` or `${jpf-symbc}/build/examples`. These paths must be updated to the Maven directories:

```bash
# In test .jpf files:
# build/tests → jpf-symbc-tests/target/test-classes
# src/tests   → jpf-symbc-tests/src/test/java
find jpf-symbc-tests/src/test/resources -name "*.jpf" -exec sed -i \
    -e 's|build/tests|jpf-symbc-tests/target/test-classes|g' \
    -e 's|src/tests|jpf-symbc-tests/src/test/java|g' {} \;

# In example .jpf files:
# build/examples → jpf-symbc-examples/target/classes
# src/examples   → jpf-symbc-examples/src/main/java
find jpf-symbc-examples/src/main/resources -name "*.jpf" -exec sed -i \
    -e 's|build/examples|jpf-symbc-examples/target/classes|g' \
    -e 's|src/examples|jpf-symbc-examples/src/main/java|g' {} \;
```

> **Post-sed verification (mandatory):**

```bash
# 1. List .jpf files that were NOT updated (possible exceptions to the pattern)
grep -rL 'target/' jpf-symbc-tests/src/test/resources/*.jpf || echo "All updated"
grep -rL 'target/' jpf-symbc-examples/src/main/resources/*.jpf || echo "All updated"

# 2. List .jpf files that still reference old paths (should return empty)
grep -rl 'build/tests|build/examples' jpf-symbc-tests/ jpf-symbc-examples/ || echo "OK: no old paths"

# 3. Check .jpf files with references to native_classpath or absolute paths (handle manually)
grep -rl 'native_classpath=.*git|native_classpath=.*home' jpf-symbc-tests/ jpf-symbc-examples/
```

> **Note:** Some .jpf files may have additional references like `native_classpath=../../git/...` that need individual attention.

### 1.9 Handle ExSymExe* files (129 files)

There are **129 `ExSymExe*.java` files** in `src/tests/` (including sub-packages like `strings/`). They are NOT JUnit tests — they are demo programs with a `main()` method, executable via JPF. Options:

**Decision: keep them in jpf-symbc-tests but exclude them from surefire.** They will be compiled as part of the tests (to validate that the code compiles) but not executed automatically. The exclusion is implicit because surefire uses `<include>**/Test*.java</include>`, and `ExSymExe*` does not follow this pattern.

### 1.10 Validation

```bash
mvn clean compile
```

Success criterion: all 5 modules compile without error.

---

## Phase 2: Java 8 → Java 11 Migration

> Goal: Compile and test with Java 11. Requires configuration of --patch-module, --add-reads, and --add-opens.

### 2.1 Update Java version in the parent POM

```xml
<java.version>11</java.version>
```

### 2.2 Compile model classes with --patch-module (3 executions)

In `jpf-symbc-classes/pom.xml`, the `maven-compiler-plugin` needs **3 executions** in order:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <executions>
        <!--
            Execution 1 (default-compile): Compiles regular classes (gov/, org/)
            This includes Debug.java which is imported by Scanner.java in execution 2.
            Uses the default configuration from pluginManagement (source/target 11).
        -->

        <!--
            Execution 2: Compiles java.base module classes (Math, Scanner)
            Scanner.java imports gov.nasa.jpf.symbc.Debug → needs --add-reads
            Must run AFTER the default execution so that Debug.class is available.
        -->
        <execution>
            <id>compile-patch-java-base</id>
            <phase>compile</phase>
            <goals><goal>compile</goal></goals>
            <configuration>
                <compileSourceRoots>
                    <compileSourceRoot>${project.basedir}/src/main/modules/java.base</compileSourceRoot>
                </compileSourceRoots>
                <compilerArgs>
                    <arg>--patch-module</arg>
                    <arg>java.base=${project.basedir}/src/main/modules/java.base</arg>
                    <arg>--add-reads</arg>
                    <arg>java.base=ALL-UNNAMED</arg>
                </compilerArgs>
            </configuration>
        </execution>

        <!--
            Execution 3: Compiles java.desktop module classes (BufferedImage, Kernel)
            Kernel.java has no cross-dependencies.
            BufferedImage.java had its Debug import REMOVED (it was dead code).
        -->
        <execution>
            <id>compile-patch-java-desktop</id>
            <phase>compile</phase>
            <goals><goal>compile</goal></goals>
            <configuration>
                <compileSourceRoots>
                    <compileSourceRoot>${project.basedir}/src/main/modules/java.desktop</compileSourceRoot>
                </compileSourceRoots>
                <compilerArgs>
                    <arg>--patch-module</arg>
                    <arg>java.desktop=${project.basedir}/src/main/modules/java.desktop</arg>
                </compilerArgs>
            </configuration>
        </execution>
    </executions>
</plugin>
```

**Reference:** jpf-core uses this pattern in `gradle/source-sets.gradle` lines 42-60 and the `compileModules` task in `build.gradle`.

### 2.3 Configure --add-exports for peers (if necessary)

Check if the peers in `jpf-symbc-main` use internal JDK APIs. If so, in `jpf-symbc-main/pom.xml`:

```xml
<compilerArgs>
    <arg>--add-exports</arg>
    <arg>java.base/jdk.internal.misc=ALL-UNNAMED</arg>
</compilerArgs>
```

### 2.4 Configure tests with --add-opens

In `jpf-symbc-tests/pom.xml`, the surefire plugin:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <argLine>
            -Xmx1024m
            --add-opens java.base/java.lang=ALL-UNNAMED
            --add-opens java.base/java.util=ALL-UNNAMED
            --add-exports java.base/jdk.internal.misc=ALL-UNNAMED
            --add-opens java.base/jdk.internal.misc=ALL-UNNAMED
        </argLine>
    </configuration>
</plugin>
```

**Reference:** jpf-core `build.gradle` parallelTest/singleThreadTest jvmArgs.

### 2.5 Verify library compatibility

> Results from the Phase 0.3 smoke test should guide this step.

Test the compilation and runtime of each solver with Java 11:
- **Z3**: Recent versions (4.8+) support Java 11. The JAR in `lib/` might work; if not, update to a recent version.
- **Choco, SAT4J**: Pure-Java JARs — generally work with Java 11 without issues.
- **Native libs (.so/.dll)**: The smoke test results (Phase 0.3) determine which JNI solvers work. Libs compiled years ago against old JDK/glibc may fail with `UnsatisfiedLinkError`. For solvers that failed the smoke test, evaluate: (a) updating to a newer version, (b) recompiling from source, or (c) disabling the solver.

### 2.6 Validation

```bash
# With Java 11 in JAVA_HOME
mvn clean compile
mvn test   # May have runtime failures — handle in Phase 3
```

---

## Phase 3: Tests and Compatibility with official jpf-core

> Goal: Ensure tests pass and the integration with JPF works.

### 3.1 Fix API errors between the fork and the official jpf-core

Compile against `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` and fix any errors. High-risk areas:

| JPF Class | Usage in jpf-symbc | Risk |
|------------|------------------|-------|
| `InstructionFactory` | Base of `SymbolicInstructionFactory` | HIGH — signature changes possible |
| `ClassInfoFilter` | Class filter in `SymbolicInstructionFactory` | MEDIUM |
| `PropertyListenerAdapter` | Base of `SymbolicListener` | LOW — stable interface |
| `VM`, `ThreadInfo`, `StackFrame` | Used in 46+ imports | MEDIUM — core API |
| `MJIEnv`, `NativePeer` | Base of peers | LOW |

### 3.2 Configure test exclusions in surefire

Migrate exclusions from `build.xml` (lines 251-269):

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <forkCount>1</forkCount>
        <reuseForks>false</reuseForks>
        <argLine>
            -Xmx1024m
            --add-opens java.base/java.lang=ALL-UNNAMED
            --add-opens java.base/java.util=ALL-UNNAMED
            --add-exports java.base/jdk.internal.misc=ALL-UNNAMED
            --add-opens java.base/jdk.internal.misc=ALL-UNNAMED
        </argLine>
        <includes>
            <include>**/Test*.java</include>
        </includes>
        <excludes>
            <exclude>**/JPF_*.java</exclude>
            <exclude>**/TestBitwise*.java</exclude>
            <exclude>**/TestCoverage.java</exclude>
            <exclude>**/TestDIV.java</exclude>
            <exclude>**/TestExJPF.java</exclude>
            <exclude>**/TestLazy*.java</exclude>
            <exclude>**/TestPathCondition.java</exclude>
            <exclude>**/TestStringBuilder.java</exclude>
            <exclude>**/strings/**</exclude>
            <exclude>**/TestSymbolicListener.java</exclude>
            <exclude>**/TestSymbolicOutput.java</exclude>
            <exclude>**/TestSymbolicJPF.java</exclude>
        </excludes>
    </configuration>
</plugin>
```

> **Note:** The 129 `ExSymExe*.java` files do not need explicit exclusion as they don't follow the `Test*` pattern.

### 3.3 Update jpf.properties and .jpf files

**jpf.properties (root):**

```properties
jpf-symbc = ${config_path}

jpf-symbc.native_classpath=
  ${jpf-symbc}/jpf-symbc-main/target/jpf-symbc-main-1.0.0-SNAPSHOT.jar;
  ${jpf-symbc}/jpf-symbc-annotations/target/jpf-symbc-annotations-1.0.0-SNAPSHOT.jar;
  ... (solver JARs — keep references to repo/ or lib/)

jpf-symbc.classpath=
  ${jpf-symbc}/jpf-symbc-classes/target/jpf-symbc-classes-1.0.0-SNAPSHOT.jar

jpf-symbc.test_classpath=
  ${jpf-symbc}/jpf-symbc-tests/target/test-classes

jpf-symbc.peer_packages = gov.nasa.jpf.symbc
jvm.insn_factory.class=gov.nasa.jpf.symbc.SymbolicInstructionFactory
vm.storage.class=nil
```

**Alternative (recommended):** Use `maven-dependency-plugin` to copy the produced JARs to a `build/` directory, maintaining backward compatibility with `jpf.properties` and `.jpf` files:

```xml
<!-- In the parent POM, after mvn package: -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-dependency-plugin</artifactId>
    <executions>
        <execution>
            <id>copy-module-jars</id>
            <phase>package</phase>
            <goals><goal>copy</goal></goals>
            <configuration>
                <artifactItems>
                    <!-- Copy module JARs to build/ in the root -->
                </artifactItems>
                <outputDirectory>${maven.multiModuleProjectDirectory}/build</outputDirectory>
            </configuration>
        </execution>
    </executions>
</plugin>
```

### 3.4 Validation

```bash
mvn clean test
# Run a simple example to validate integration:
# java -jar path/to/RunJPF.jar src/examples/demo/NumericExample.jpf
```

---

## Phase 4: Cleanup and Documentation

### 4.1 Remove obsolete artifacts

| File/Directory | Action |
|-------------------|------|
| `build.xml` | Remove |
| `.classpath` | Remove |
| `.project` | Remove |
| `nbproject/` | Remove |
| `.externalToolBuilders/` | Remove |
| `src/` (original) | Remove after confirming complete migration |

### 4.2 Keep

| File/Directory | Reason |
|-------------------|-------|
| `lib/` | Native libraries (.so, .dll, .dylib) needed at runtime |
| `jpf.properties` | JPF integration |
| `LICENSE-2.0.txt` | License |

### 4.3 Update documentation

- **README.md** — New prerequisites (Java 11, local jpf-core), new Maven commands
- **CLAUDE.md** — Updated commands (`mvn compile`, `mvn test`, `mvn package`)

---

## Critical Files

| File | Action | Notes |
|---------|------|-------|
| `NativeLibSmokeTest.java` | Create (temporary) | Phase 0.3 — JNI smoke test; remove after validation |
| `pom.xml` (root) | Create | Parent POM with modules and dependencyManagement |
| `jpf-symbc-annotations/pom.xml` | Create | No external dependencies |
| `jpf-symbc-main/pom.xml` | Create | Dependencies for all solvers (optional) |
| `jpf-symbc-classes/pom.xml` | Create | 3 compiler executions: regular + java.base + java.desktop |
| `jpf-symbc-tests/pom.xml` | Create | Surefire with exclusions and --add-opens |
| `jpf-symbc-examples/pom.xml` | Create | Dependencies on internal modules |
| `repo/` | Create | ~19 locally installed JARs |
| `jpf.properties` | Edit | New Maven JAR paths |
| `152 .jpf files` | Edit | Update build/tests → target/test-classes etc. paths |
| `BufferedImage.java` | Edit | Remove dead import of Debug |
| `README.md` | Edit | Updated build instructions |
| `CLAUDE.md` | Edit | Maven commands |
| `build.xml` | Remove | Phase 4 |
| `.classpath`, `.project` | Remove | Phase 4 |
| `nbproject/` | Remove | Phase 4 |

---

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|-------|---------|---------------|-----------|
| `java.*` model classes fail to compile with `--patch-module` | HIGH | Low | Follow jpf-core's exact pattern; separate java.base and java.desktop |
| Incompatible API between yannicnoller fork and official jpf-core | **HIGH** | Medium | **Phase 0.4:** quantify divergence with git diff before starting; focus on `InstructionFactory`, `ClassInfo`, `MethodInfo` |
| Compilation order in maven-compiler-plugin | MEDIUM | Medium | Ensure default-compile runs before patch-module executions |
| Old solver JARs incompatible with Java 11 | MEDIUM | Medium | **Phase 0.3:** JNI smoke test with JDK 11 before investing in migration |
| 152 .jpf files with outdated paths | MEDIUM | High | Automated sed script + **mandatory post-sed verification** (grep -rL) |
| Native libs (.so) incompatible with JDK 11 / modern glibc | **MEDIUM** | **Medium** | **Phase 0.3:** System.loadLibrary smoke test with JDK 11; libs were compiled years ago against specific JDK/glibc |
| Tests fail due to behavioral changes in jpf-core | MEDIUM | Medium | Analyze failures case-by-case; update tests if necessary |
| JPF ClassLoader + Java 11 module system (new) | **MEDIUM** | Medium | JPF uses custom class loaders; interaction with the module path could cause `ClassNotFoundException` at runtime. Test end-to-end in Phase 3 |

---

## End-to-End Verification

1.  **Compilation:** `mvn clean compile` — all 5 modules compile without error
2.  **Tests:** `mvn test` — non-excluded tests pass
3.  **Packaging:** `mvn package` — 5 JARs produced correctly
4.  **JPF Integration:** Run a simple `.jpf` example via JPF with the migrated jpf-symbc
5.  **Solver:** Run a test that uses Z3 as a decision procedure to validate integration

---

## Recommended Order of Execution

```
Phase 0.1   git tag pre-migration-java11 (safety net)
Phase 0.2   Install jpf-core + VERIFY exact Maven coordinates
Phase 0.3   JNI smoke test: Z3/CVC3/STP/Yices with JDK 11 → go/no-go decision
Phase 0.4   git diff fork↔official on APIs used by jpf-symbc → estimate Phase 3 effort
    ↓ (go/no-go: if Z3 fails the smoke test, investigate before proceeding)
Phase 1.1   Create repo/ with research JARs (~19 JARs)
Phase 1.2   Remove dead import in BufferedImage.java
Phase 1.3   Create Maven directory structure
Phase 1.4   Create POMs (parent + 5 modules)
Phase 1.5   Move source files
Phase 1.6   Update 152 .jpf files (paths) + post-sed verification
Phase 1.7   Validate: mvn compile (Java 8)
    ↓
Phase 2.1   Change java.version to 11
Phase 2.2   Configure 3 compiler executions in jpf-symbc-classes
Phase 2.3   Configure --add-exports/--add-opens
Phase 2.4   Verify library compatibility
Phase 2.5   Validate: mvn compile (Java 11)
    ↓
Phase 3.1   Fix jpf-core API errors (scope estimated in Phase 0.4)
Phase 3.2   Configure test exclusions (surefire)
Phase 3.3   Update jpf.properties
Phase 3.4   Validate: mvn test + JPF example
    ↓
Phase 4.1   Remove obsolete artifacts
Phase 4.2   Update documentation
Phase 4.3   Validate: full clean build
```

---

## Changelog

### Revision 2 (2026-02-27) — Incorporating external feedback

Analyses from Gemini and Qwen were evaluated. Changes applied:

| Change | Origin | Justification |
|---------|--------|---------------|
| **New Phase 0** with validation of blocking risks | Gemini (Phase 0), Qwen (#1, #6, #28) | Detect blockers (JNI, Maven coordinates, fork divergence) before investing in the migration |
| **Fixed jpf-symbc-classes dependencies**: removed dependency on jpf-symbc-main | Empirical verification (0 imports from src/main in src/classes) | Simplifies dependency graph; classes only depends on annotations + jpf-core |
| **Risk table updated**: native libs LOW→MEDIUM, fork divergence MEDIUM→HIGH, new ClassLoader+modules risk | Gemini (3.1), Qwen (3.1) | Original ratings were too optimistic |
| **ExSymExe count**: 60→129 | Qwen (#20), empirically verified | Factual correction |
| **Mandatory post-sed verification** on the 152 .jpf files | Gemini (recommendation 5), Qwen (#17) | `grep -rL` to catch un-updated files |
| **Distinct libcvc3 artifactIds**: cvc3-legacy (1.0.0) and cvc3 (5.0.0) | Qwen (#3) | They are two different JARs, they need unique artifactIds |
| **resourceEncoding UTF-8** in parent POM | Qwen (#11) | Good practice for .jpf files |
| **git tag** as a safety net before migration | Qwen (#38) | Cheap and communicative |

**Suggestions discarded** (over-engineering for this project):
maven-enforcer-plugin, maven-failsafe-plugin, jacoco, source/javadoc JARs, JAR provenance documentation, specific version instead of DEVELOPMENT-SNAPSHOT, formal IDE validation, CI/CD (does not exist).

```