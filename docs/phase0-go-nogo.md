# Phase 0 Go/No-Go Results

Date: 2026-03-03

## Summary: GO — Proceed with migration

## Task Results

### 0.1 Safety Net + Ant Baseline
- Tag `pre-migration-java11` created
- jpf-core fork (yannicnoller) cloned and built at `../jpf-core`
- jpf-symbc Ant build: BUILD SUCCESSFUL (12s)
- Ant tests: BUILD SUCCESSFUL (32s), all non-excluded tests pass
- JAR class lists captured: main=481, classes=27, annotations=10

### 0.2 Official jpf-core
- Cloned to `/tmp/jpf-core-official`, built with JDK 11
- `publishToMavenLocal` successful
- **Verified coordinates**:
  - `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT`
  - `gov.nasa:jpf-classes:DEVELOPMENT-SNAPSHOT`
  - `gov.nasa:jpf-annotations:DEVELOPMENT-SNAPSHOT`

### 0.3 Native Library Smoke Test (JDK 11)
- **Z3: PASS** (libz3 + libz3java loaded)
- CVC3: FAIL (ELFCLASS32 — 32-bit lib on 64-bit system, not a regression)
- STP: FAIL (not found in library path)
- Yices: FAIL (ELFCLASS32 — 32-bit lib, not a regression)

### 0.3b E2E Z3 Test via JPF
- Z3 JNI on JDK 11: **PASS** (no IllegalAccessError, no module system issues)
- Full E2E blocked by model class mismatch (Thread$Permit) — expected, will be resolved when compiling against official jpf-core

### 0.4 Fork Divergence
- **67 unique jpf-core classes** imported by jpf-symbc
- **0 missing** from official jpf-core
- **0 compilation-breaking** changes
- **3 potential runtime issues**:
  1. `DynamicElementInfo`: String backing changed from `char[]` to `byte[]` (Java 9+ compact strings) — affects `SymbolicStringHandler.getStringEquiv()` lines 2718/2725
  2. `ClassLoaderInfo`: Lambda class naming change (`$$Lambda$` → `$`)
  3. `VirtualInvocation`: Added private method call resolution
- **GO threshold: <10 breaking → PROCEED**

### 0.5 + 0.5b opt4j / Coral Compatibility
- **Decision: Coral UNSUPPORTED on Java 11**
- Reason: opt4j 2.4 bundles Guice 1.0 with ASM 1.5.3 (can't parse Java 11 class format 55.0). opt4j 3.x completely restructured packages. coral.jar bundles 40 opt4j-dependent classes with old package names. Source unavailable for rebuild.
- Keep `opt4j-2.4.jar` and `coral.jar` in `repo/` for compilation. Document Coral as unsupported at runtime on Java 11.

### 0.6 SHA-256 JAR Baseline + Native Lib Inventory
- 28 JARs checksummed → `docs/jar-checksums-pre-migration.txt`
- 40 native lib files inventoried → `docs/native-libs-pre-migration.txt`

### 0.7 SAT4J Custom Build Verification
- Confirmed CUSTOM builds: `Bundle-Version: CUSTOM.v20100705`, `Implementation-Version: 2.0`
- Maven Central has version 2.3.6 (2013) — definitively different
- **Decision: Keep in `repo/` as local JARs**

### 0.8 PathConditionsReliability
- **Dead reference** — no Java imports, no .jpf references, JAR not in lib/
- Only appears in JVM crash logs (hs_err_pid) from other users' jpf-security projects
- **Decision: Remove from jpf.properties**

### 0.9 Extra .jpf File Placement
- `TestMain.jpf` → target is `gov.nasa.jpf.symbc.concolic.TestMain` (src/main) → `jpf-symbc-main/src/main/resources/gov/nasa/jpf/symbc/concolic/`
- `Example.jpf` → documentation file, target `examples.Example`, classpath commented out → leave in `doc/`
