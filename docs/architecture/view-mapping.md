# View Mapping

## Primary Presentation

This document maps elements across the four generated views (Decomposition, Uses, Generalization, Install) to show how the same architectural elements appear in different contexts.

## Element Correspondence Table

| Element | Decomposition View | Uses View | Generalization View | Install View |
|---------|-------------------|-----------|--------------------|--------------|
| `SymbolicInstructionFactory` | Root package entry point | Source of dependencies on bytecode, numeric, Green, jpf-core | Extends jpf-core `InstructionFactory` | Compiled in `-compile-main` target; packaged into `jpf-symbc.jar` |
| `SymbolicListener` | Root package listener | Depends on bytecode, numeric, concolic, jpf-core | Extends jpf-core `PropertyListenerAdapter`; implements `PublisherExtension` | Compiled in `-compile-main` target; packaged into `jpf-symbc.jar` |
| `bytecode` package | 102 symbolic instruction classes + 2 utility classes | Depends on numeric, string, heap, arrays, jpf-core | Each class extends a jpf-core bytecode instruction class | Compiled in `-compile-main` target |
| `bytecode.optimization` | 19 optimized branch instruction classes | Depends on numeric, jpf-core | Each class extends corresponding `bytecode` class | Compiled in `-compile-main` target |
| `bytecode.symarrays` | 19 array-theory instruction classes | Depends on numeric, arrays, jpf-core | Each class extends corresponding jpf-core/bytecode class | Compiled in `-compile-main` target |
| `Expression` | Base type in numeric module | Used by all modules that manipulate symbolic values | Root of expression inheritance hierarchy | Part of `build/main` and `jpf-symbc.jar` |
| `IntegerExpression` | Numeric module expression type | Used by bytecode, string, heap, concolic, mixednumstrg | Extends `Expression`; parent of 6+ concrete subclasses | Part of `build/main` and `jpf-symbc.jar` |
| `Constraint` | Numeric module constraint type | Used by numeric, concolic, arrays | Root of constraint hierarchy; 5 subclasses | Part of `build/main` and `jpf-symbc.jar` |
| `PathCondition` | Central data structure in numeric module | Used by bytecode, listeners, numeric.solvers, concolic, string | Contains `Constraint` chain + `StringPathCondition` + array expressions | Part of `build/main` and `jpf-symbc.jar` |
| `ProblemGeneral` | Abstract solver interface in numeric.solvers | Depended on by all solver implementations | Root of solver implementation hierarchy; 14 subclasses | Part of `build/main` and `jpf-symbc.jar` |
| `ProblemZ3` | Z3 solver impl in numeric.solvers | Depends on Z3 Java API (external) | Extends `ProblemGeneral` | Requires `com.microsoft.z3.jar` + native `libz3*.so/dll` |
| `ProblemChoco` | Choco solver impl in numeric.solvers | Depends on Choco JARs (external) | Extends `ProblemGeneral` | Requires `choco-1_2_04.jar` |
| `StringPathCondition` | String module path condition type | Depends on numeric (linked from `PathCondition.spc`) | Standalone class (no inheritance hierarchy) | Part of `build/main` and `jpf-symbc.jar` |
| `HeapChoiceGenerator` | Heap module choice generator | Depends on numeric, jpf-core | Extends jpf-core `ChoiceGenerator` | Part of `build/main` and `jpf-symbc.jar` |
| `PCChoiceGenerator` | Numeric module choice generator | Used by bytecode, listeners | Extends jpf-core `IntIntervalGenerator` | Part of `build/main` and `jpf-symbc.jar` |
| `@Symbolic` annotation | Annotations source root | No internal dependencies | Java annotation type | Compiled in `-compile-annotations`; packaged into both `jpf-symbc-classes.jar` and `jpf-symbc-annotations.jar` |
| `Debug` model class | Classes source root | Depends on jpf-core `Verify` | Standalone class with `native` methods | Compiled in `-compile-classes`; packaged into `jpf-symbc-classes.jar` |
| Native peer classes | Peers source root | Depends on numeric, string, jpf-core | Follow `JPF_<class>` naming convention | Compiled in `-compile-peers`; packaged into `jpf-symbc.jar` |
| Green framework | External library | Used by `SymbolicInstructionFactory`, `PathCondition`, `SolverTranslator` | N/A (external) | `lib/green.jar` |
| Z3 native libraries | External native code | Used by `ProblemZ3*` classes via JNI | N/A (external) | `lib/libz3java.so`, `lib/64bit/libz3.so` (Linux) |

## Cross-View Consistency Notes

1. **Source roots map to build targets and JARs**: The 6 source roots (`main`, `classes`, `annotations`, `peers`, `tests`, `examples`) in the Decomposition view correspond 1:1 to the build targets in the Install view. The JAR packaging in the Install view groups them: `main+peers` into `jpf-symbc.jar`, `classes+annotations` into `jpf-symbc-classes.jar`, `annotations` alone into `jpf-symbc-annotations.jar`.

2. **Module dependencies map to classpath entries**: Every internal dependency shown in the Uses view is satisfied by compile-time classpath entries in `build.xml`. The `lib.path` classpath reference in the Install view provides all external dependencies shown in the Uses view.

3. **Generalization hierarchies are within single modules**: Each inheritance hierarchy (expression, constraint, solver) shown in the Generalization view exists entirely within the `numeric` package and its `solvers` sub-package. Cross-package inheritance exists only for string-derived integer expressions (in `string` package extending `numeric.IntegerExpression`) and for listeners extending jpf-core base classes.

4. **External dependencies in Uses view map to lib/ JARs in Install view**: Every external library dependency shown in the Uses view has a corresponding JAR file in the `lib/` directory documented in the Install view. Native solver dependencies additionally require platform-specific shared libraries.

## Variability Guide

When making changes, maintain these cross-view consistencies:
- Adding a new source root requires updating `build.xml` (Install), `jpf.properties` classpath entries (Install), and the Decomposition view.
- Adding a new solver backend requires a new `ProblemGeneral` subclass (Generalization), a new dispatch branch in `SymbolicConstraintsGeneral` (Uses), a new JAR in `lib/` and `jpf.properties` (Install).
- Adding a new module affects the Decomposition view structure and the Uses view dependency graph.

## Rationale

This mapping was created to help readers navigate between views. The dominant pattern is that the Decomposition view defines what exists, the Uses view defines how it connects, the Generalization view defines how it specializes, and the Install view defines how it is built and packaged.
