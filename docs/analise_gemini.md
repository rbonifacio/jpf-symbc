Here is a rigorous validation of the change `/openspec/changes/gh1-migration-maven-java11`.

### Overall Impression

This is an exceptionally well-documented and thoroughly planned migration. The artifacts (`proposal.md`, `design.md`, `tasks.md`, and delta specs) adhere strictly to the Spec-Driven Development (SDD) principles outlined in the project's own documentation (`docs/SDD.md`). The planning demonstrates a deep understanding of both the existing system's intricacies and the complexities of the Java 11/Maven migration. The proactive identification of blockers (especially the `opt4j` issue) and the detailed, phased approach in `tasks.md` are exemplary.

This level of detailed, up-front specification and planning is the "gold standard" for the Full SDD track described in `docs/SDD-WORKFLOW.md`.

---

### Strengths

1.  **Exceptional Proactive Risk Assessment:** The plan excels at identifying and mitigating risks *before* starting implementation.
    *   **`opt4j` Blocker:** The identification of the indirect dependency chain (`ProblemCoral` → `coral.jar` → `opt4j-2.4` → Guice 1.0 → ancient ASM) and its incompatibility with Java 11 is a critical, non-obvious finding. Proposing the upgrade to `opt4j 3.3` is the correct solution.
    *   **Native Libraries:** The plan doesn't just assume native libraries will work. `tasks.md` includes a dedicated smoke test (Task 0.3) and an end-to-end test (Task 0.3b) to validate JNI compatibility with JDK 11 early on.
    *   **`jpf-core` API Divergence:** The proposal and design acknowledge the high risk of API incompatibility with the official `jpf-core`. Task 0.4 rightly quantifies this divergence *before* committing to the migration, with clear go/no-go thresholds.

2.  **Adherence to SDD Principles:**
    *   **Spec-Anchored:** The delta specs clearly define the `ADDED`, `MODIFIED`, and `REMOVED` invariants and requirements for the build, configuration, and dependency systems. This provides a clear contract for the change.
    *   **Proportional Ceremony:** While this is a full, ceremony-heavy process, it is proportional to the change's complexity—a project-wide infrastructure migration.
    *   **Living Documentation:** The artifacts collectively serve as enduring documentation for the new build system. The decision to archive `build.xml` (Task 7.1) instead of deleting it is a pragmatic choice to preserve historical knowledge.

3.  **Meticulous Task Breakdown:** The `tasks.md` file is outstanding.
    *   **Phased Approach:** The breakdown into 9 logical groups (0-8) isolates concerns, allowing for incremental validation (e.g., "Maven Structure with Java 8" before "Java 11 Migration").
    *   **Granularity:** Tasks are specific and actionable (e.g., "Verify Surefire exclusion parity with Ant," "SHA-256 JAR baseline"). This leaves very little room for ambiguity during implementation.
    *   **In-situ Commands:** Including the exact shell commands (`git clone`, `sdk use`, `mvn dependency:copy`, `grep`, etc.) within the tasks makes the plan directly executable and reduces the chance of error.

4.  **Technical Soundness:**
    *   **Maven Strategy:** The decision to use a multi-module build is standard practice. The hybrid dependency strategy (Maven Central + project-local `repo/`) is a practical solution for a project with many non-standard JARs.
    *   `--patch-module` **Handling:** The design correctly identifies the need for `--patch-module` for the `java.*` model classes and replicates the proven pattern from `jpf-core`, demonstrating a thorough understanding of the Java 11 module system's constraints.

---

### Weaknesses

The plan is overwhelmingly strong, and weaknesses are minor and mostly related to potential execution oversights rather than planning flaws.

1.  **Manual Verification Steps:** Several verification tasks rely on manual inspection (e.g., comparing `mvn test -X` output to `build.xml` for exclusion parity). This is error-prone. While a fully automated check might be out of scope, the risk of human error in these manual checks is non-zero.
2.  **Implicit Knowledge in Commands:** The `tasks.md` is excellent but assumes the developer running the commands understands the output. For example, Task 0.5 (opt4j compatibility) provides a command but doesn't specify what "success" or "failure" looks like in the output of `javac`. An inexperienced developer might not know what to look for.
3.  **`.jpf` File Placement:** Task 3.12 identifies the two extra `.jpf` files but defers the decision on their final placement. While a minor point, it's one of the few instances of ambiguity in an otherwise decisive plan. A definitive placement (`jpf-symbc-main/src/main/resources/` seems most logical for `TestMain.jpf`) would be stronger.

---

### Risks

The plan has already identified the most critical risks. This section highlights them and adds a few lower-level ones.

1.  **API Divergence Scope (HIGH):** As noted in the plan, the effort required to adapt to the official `jpf-core` API is the biggest unknown. Task 0.4 is the correct mitigation, but if the analysis is underestimated, the project could get bogged down in Phase 6.
2.  **Native Library Runtime Errors (MEDIUM):** The plan's smoke tests (0.3, 0.3b) are good, but subtle runtime issues related to the Java 11 module system's stricter encapsulation of internal JDK APIs might only appear during specific symbolic execution runs. The `--add-opens` and `--add-exports` flags may need to be expanded empirically.
3.  **"Death by a Thousand Cuts" in `.jpf` files (LOW):** The `sed` automation for updating paths is a good start, but with 154 files, there's a risk of edge cases (unusual formatting, non-standard properties) that the script misses and manual verification overlooks. An incorrect path in a single, rarely used example file could go unnoticed for a long time.
4.  **Environment Drift (LOW):** The plan relies heavily on `sdk use java ...` to manage JDK versions. If a developer has a different JDK configured in their shell profile (`.bashrc`, etc.) or IDE, it could override the `sdk` command, leading to hard-to-diagnose build failures. The instructions are clear, but this external factor remains a risk.

---

### Suggestions

1.  **Automate Verification Where Possible:** For Task 6.4b (Surefire exclusion validation), consider writing a small script to parse the Ant `build.xml` and the `mvn test -X` output to produce a diff of excluded/included tests. This would be more reliable than manual comparison.
2.  **Create a `setup-dev-env.sh` Script:** Task 0.1 and 0.2 require several manual `git clone`, `ant build`, and `gradlew` commands to set up the baseline `jpf-core` environments. A single, idempotent script could automate this, ensuring a consistent setup for any developer picking up the task and serving as executable documentation.
3.  **Add Expected Output to Critical Tasks:** For tasks like the `opt4j` compatibility check (0.5), add a note describing the expected output for both success (e.g., "compilation completes without errors") and failure (e.g., "look for errors related to `org.opt4j.core.something.Something` not being found").
4.  **Strengthen `.jpf` Path Verification:** In addition to `grep -rl 'build/...'`, add a verification step (Task 8.4) that confirms all `classpath=` and `sourcepath=` properties in `.jpf` files now point to valid directories within the new Maven structure. This confirms not only the absence of old paths but the presence of correct new paths.
    ```bash
    # Example check
    find . -name "*.jpf" -exec grep -H "classpath=" {} + | while IFS=':' read -r file line; do
      path=$(echo "$line" | sed 's/classpath=//;s/${jpf-symbc}/./')
      [ -d "$path" ] || echo "INVALID PATH: $path in $file"
    done
    ```
5.  **Prominently Document the `jpf-core` Prerequisite:** After the migration, the *first* thing a new developer must do before building is clone and install the official `jpf-core`. This is a significant manual step. This requirement should be the very first item in the "Build" section of the updated `README.md`, with the exact commands to run.
