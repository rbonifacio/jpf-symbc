Symbolic (Java) PathFinder
==========================

This JPF extension provides symbolic execution for Java bytecode.
It performs a non-standard interpretation of byte-codes.
It allows symbolic execution on methods with arguments of basic types
(int, long, double, boolean, etc.). It also supports symbolic strings, arrays,
and user-defined data structures.

SPF now has a "symcrete" mode that executes paths
triggered by concrete inputs and collects constraints along the paths.

A paper describing Symbolic PathFinder appeared at ISSTA'08:

Title: Combining Unit-level Symbolic Execution and System-level Concrete
Execution for Testing NASA Software,
Authors: C. S. Pasareanu, P. C. Mehlitz, D. H. Bushnell, K. Gundy-Burlet,
M. Lowry, S. Person, M. Pape.

Prerequisites
-------------

- **Java 11** (tested with OpenJDK 11.0.12)
- **Apache Maven 3.6+**
- **jpf-core** built and installed to your local Maven repository

### Building jpf-core

Clone and build the official jpf-core, which publishes artifacts to your local Maven repository:

```bash
git clone https://github.com/javapathfinder/jpf-core.git /tmp/jpf-core-official
cd /tmp/jpf-core-official
./gradlew publishToMavenLocal
```

This produces `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` and `gov.nasa:jpf-classes:DEVELOPMENT-SNAPSHOT` in `~/.m2/repository/`.

### JPF Site Properties

Create `~/.jpf/site.properties`:

```properties
jpf-core = /path/to/jpf-core
jpf-symbc = /path/to/jpf-symbc
extensions=${jpf-core},${jpf-symbc}
```

Building
--------

```bash
mvn compile       # Compile all 5 modules
mvn test          # Run regression tests (20 tests)
mvn package       # Compile + test + generate JAR files
mvn install       # Install to local Maven repository
```

The project is structured as a Maven multi-module build with 5 modules:

| Module | Description |
|--------|-------------|
| `jpf-symbc-annotations` | Annotations usable by non-JPF applications |
| `jpf-symbc-main` | Main implementation (symbolic bytecodes, listeners, solvers) |
| `jpf-symbc-classes` | Model classes executed inside JPF (java.lang.*, java.awt.* stubs) |
| `jpf-symbc-tests` | JUnit regression test suite |
| `jpf-symbc-examples` | Example programs with `.jpf` configuration files |

### Solver JARs

20 solver JARs that are not available on Maven Central are stored in the `repo/` directory (a file-based Maven repository). These are resolved automatically during the build via a `<repository>` declaration in the parent POM. 8 additional dependencies are resolved from Maven Central.

### Native Libraries

Native solver libraries (.so, .dll, .dylib) are in `lib/` and `lib/64bit/`. These are required at runtime for solvers like Z3, CVC3, STP, and Yices.

Running Examples
----------------

Examples are `.jpf` configuration files in `jpf-symbc-examples/src/main/resources/`. Run them through JPF:

```bash
mvn compile -DskipTests
MVN_CP=$(mvn -q dependency:build-classpath -pl jpf-symbc-main -Dmdep.outputFile=/dev/stdout)
java -Djava.library.path=lib:lib/64bit \
  --add-opens java.base/java.lang=ALL-UNNAMED \
  --add-opens java.base/java.util=ALL-UNNAMED \
  --add-exports java.base/jdk.internal.misc=ALL-UNNAMED \
  -cp "jpf-symbc-main/target/classes:jpf-symbc-classes/target/classes:jpf-symbc-annotations/target/classes:${MVN_CP}" \
  gov.nasa.jpf.tool.RunJPF \
  jpf-symbc-examples/src/main/resources/demo/NumericExample.jpf
```

Constraint Solvers
------------------

JPF-SymBC supports pluggable constraint solvers configured via `.jpf` files (`symbolic.dp` property):

| Solver | Status on Java 11 |
|--------|--------------------|
| **Z3** | Supported (primary solver) |
| **Choco** | Supported |
| **Coral** | Partial (simple constraints work; complex opt4j paths may fail due to ASM 1.5.3 incompatibility with Java 11 class format) |
| **CVC3** | Requires 64-bit native libraries |
| **STP** | Requires native libraries |
| **Yices** | Requires 64-bit native libraries |

Notes
-----

- opt4j is kept at version 2.4 (bundled with Coral solver). Upgrading to 3.3 would require rebuilding `coral.jar` from unavailable source code.
- SAT4J JARs are custom builds (v20100705), not Maven Central releases. They are kept in the local `repo/` directory.
- Tests use JUnit 4, forked per test with 1024MB max memory. Only `**/Test*.java` files are included. Excluded tests (matching original Ant build.xml exclusions):
  - `TestBitwise*`, `TestCoverage`, `TestDIV`, `TestExJPF` — solver/environment-specific failures
  - `TestLazy*` — lazy initialization tests (environment-dependent)
  - `TestPathCondition`, `TestStringBuilder` — known instabilities
  - `strings/**` — string solver tests (require specific solver setup)
  - `TestSymbolicListener`, `TestSymbolicOutput`, `TestSymbolicJPF` — integration tests with external dependencies
  - `JPF_*` — native peer classes (not tests)
  - `Test*$*` — inner test classes (not standalone tests)
