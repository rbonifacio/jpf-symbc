# Architecture Rationale

## Primary Presentation

This document captures cross-cutting architectural decisions that span multiple views. These are decisions that shaped the overall structure of JPF-SymBC and are not specific to any single module.

## Element Catalog

### Decision 1: JPF Extension Model

**Decision**: JPF-SymBC integrates with JPF Core through two primary mechanisms: an instruction factory (`SymbolicInstructionFactory` extending `InstructionFactory`) and event listeners (extending `PropertyListenerAdapter`).

**Alternatives Considered**: (a) Modifying JPF Core directly to add symbolic execution support. (b) Using bytecode instrumentation as a preprocessing step.

**Rationale**: The extension model was chosen because it allows JPF-SymBC to be developed, versioned, and distributed independently of JPF Core. The instruction factory pattern is the standard JPF mechanism for replacing bytecode semantics. Listeners provide non-intrusive observation of VM events without modifying core execution logic.

**Trade-offs**: The extension model limits JPF-SymBC to the hooks that JPF Core provides. If a bytecode instruction is not covered by the `InstructionFactory` interface, it cannot be overridden. The listener-based approach requires event-driven rather than inline processing, which can complicate control flow in the symbolic execution logic.

### Decision 2: One Class Per Bytecode

**Decision**: Each JVM bytecode instruction that can operate on symbolic values has its own Java class (e.g., `IADD.java`, `ISUB.java`, `IF_ICMPGE.java`). This produces 102 classes in `bytecode/`, 19 in `bytecode/optimization/`, and 19 in `bytecode/symarrays/`.

**Alternatives Considered**: (a) A single dispatcher class with methods for each instruction. (b) A table-driven approach mapping opcodes to handler functions.

**Rationale**: This pattern follows JPF Core's own structure, where each bytecode is a separate class. It enables type-safe dispatch through the instruction factory and allows each instruction to carry its own state (e.g., target PC for branches). The `ClassInfoFilter` mechanism requires returning specific `Instruction` subclasses.

**Trade-offs**: The large number of small, similar classes creates maintenance overhead. Many bytecode classes follow nearly identical patterns (e.g., all integer arithmetic instructions perform similar symbolic expression construction). However, the pattern is consistent and each class is self-contained.

### Decision 3: Solver Abstraction via ProblemGeneral

**Decision**: All constraint solver backends implement the abstract class `ProblemGeneral`, which defines a uniform interface using `Object` as the type for solver-internal expression handles. Solver selection is configured via the `symbolic.dp` property and dispatched through string comparison in `SymbolicConstraintsGeneral`.

**Alternatives Considered**: (a) Java generics to type solver expression handles. (b) A plugin/registry pattern with dynamic class loading. (c) A single solver implementation.

**Rationale**: The `Object`-based approach provides a lowest-common-denominator interface that can wrap any solver API without requiring a common type hierarchy for solver-internal types. The string-based dispatch is straightforward and matches JPF's property-based configuration style.

**Trade-offs**: Loss of type safety at the solver boundary -- callers must trust that the `Object` returned by `makeIntVar` is compatible with the `Object` expected by `eq`, `plus`, etc. A misconfigured dispatch or a type mismatch results in a `ClassCastException` at runtime. The string-based dispatch requires manual maintenance when adding new solvers.

### Decision 4: Separate Constraint Domains

**Decision**: Numeric, string, and array constraints each have their own expression hierarchies, path condition types, and solver dispatch mechanisms. `PathCondition` handles numeric constraints; `StringPathCondition` handles string constraints (referenced from `PathCondition` via the `spc` field); array constraints are encoded within the numeric `PathCondition`.

**Alternatives Considered**: (a) A unified constraint model that handles all domains. (b) A single path condition type with tagged constraints.

**Rationale**: The numeric constraint system was developed first. String and array support were added later as separate subsystems. The string domain has fundamentally different solving strategies (automata-based, SAT-based) compared to numeric constraints (SMT, constraint programming), making a unified solving approach impractical.

**Trade-offs**: The parallel structures create duplication (both domains have expression hierarchies, constraints, path conditions, and solver dispatch). Cross-domain constraints (e.g., string length in a numeric comparison) require bridge types like `SymbolicLengthInteger` and `SpecialIntegerExpression`. The `StringPathCondition` is linked to the numeric `PathCondition` through a simple field reference rather than a compositional design.

### Decision 5: Committed Library Dependencies

**Decision**: All 28 JAR dependencies and native library binaries are committed directly to the `lib/` directory in the source repository. No dependency manager (Maven, Gradle, Ivy) is used.

**Alternatives Considered**: Maven/Ivy dependency resolution.

**Rationale**: This matches the jpf-core project's approach and ensures builds are reproducible without network access or a configured dependency manager. Some libraries (SAT4J custom builds, project-specific JARs like `PathConditionsReliability`) are not available from public repositories.

**Trade-offs**: Repository size is increased by the binary JARs and native libraries. Library version tracking relies on filename conventions rather than metadata. Upgrading a library requires manual replacement. Transitive dependencies are resolved manually.

### Decision 6: Configuration-Driven Symbolic Execution

**Decision**: The scope of symbolic execution (which methods, which argument types) is specified entirely through `.jpf` property files (`symbolic.method`, `symbolic.class`, `symbolic.dp`, etc.) rather than through code annotations or API calls.

**Rationale**: This follows JPF's configuration philosophy and allows the same compiled program to be analyzed with different symbolic execution configurations without recompilation. The `.jpf` file approach is consistent with how JPF Core handles all other configuration.

**Trade-offs**: Configuration is string-based and error-prone. Method signatures must be specified manually with type annotations (e.g., `sym#sym#con`). The `BytecodeUtils.isMethodSymbolic` method performs string parsing on every method invocation to determine symbolicity. The `@Symbolic` annotation exists as an alternative for field-level marking but is not the primary configuration mechanism.

### Decision 7: Stateless Execution

**Decision**: Symbolic execution in JPF-SymBC disables JPF's state matching mechanism (`vm.storage.class=nil`). Each execution path is explored independently without checking for previously visited states.

**Rationale**: Symbolic state includes path conditions, which are typically unique per path. State matching would rarely find matches and the overhead of comparing symbolic states outweighs any potential reduction in explored paths.

**Trade-offs**: Without state matching, the exploration space can be much larger than with concrete execution. Loops with symbolic bounds lead to unbounded exploration unless constrained by `symbolic.max_pc_length` or `symbolic.max_pc_msec`.

## Context Diagram

These decisions are system-wide and affect the relationship between JPF-SymBC and its external dependencies (JPF Core, solver libraries) as well as the internal structure of all modules.

## Variability Guide

The architectural decisions above define fixed structural aspects. The following variation points operate within these decisions:

- Solver backends can be added without changing the overall architecture (Decision 3).
- New bytecode instructions follow the established one-class-per-bytecode pattern (Decision 2).
- New constraint domains could be added following the pattern of string constraints (Decision 4), though integration with the existing path condition requires manual coordination.

## Rationale

This rationale document captures decisions that were made over the evolution of the project. Several decisions (particularly Decision 4: Separate Constraint Domains) reflect incremental growth rather than up-front design. The string and array subsystems were added after the numeric core was established, and their integration reflects this history.
