# Architecture Directory

Alphabetical index of architectural elements mentioned across views. For each element: name, type, which views contain it, and file path to its definition.

## A

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `AALOAD` (symbolic) | Bytecode instruction class | Decomposition | `src/main/gov/nasa/jpf/symbc/bytecode/AALOAD.java` |
| `AALOAD` (symarrays) | Bytecode instruction class | Decomposition | `src/main/gov/nasa/jpf/symbc/bytecode/symarrays/AALOAD.java` |
| `@Concrete` | Annotation | Decomposition, Install | `src/annotations/gov/nasa/jpf/symbc/Concrete.java` |
| `ArrayConstraint` | Constraint class | Decomposition, Generalization | `src/main/gov/nasa/jpf/symbc/arrays/ArrayConstraint.java` |
| `ArrayExpression` | Expression class | Decomposition | `src/main/gov/nasa/jpf/symbc/arrays/ArrayExpression.java` |
| `ATreeListener` | Listener class | Decomposition | `src/main/gov/nasa/jpf/symbc/tree/ATreeListener.java` |

## B

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `BinaryLinearIntegerExpression` | Expression class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/BinaryLinearIntegerExpression.java` |
| `BinaryNonLinearIntegerExpression` | Expression class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/BinaryNonLinearIntegerExpression.java` |
| `BinaryRealExpression` | Expression class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/BinaryRealExpression.java` |
| `build.xml` | Build script | Install | `build.xml` |
| `BytecodeUtils` | Utility class | Decomposition, Uses | `src/main/gov/nasa/jpf/symbc/bytecode/BytecodeUtils.java` |

## C

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `Comparator` | Enum | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/Comparator.java` |
| `ConcreteExecutionListener` | Listener class | Decomposition | `src/main/gov/nasa/jpf/symbc/concolic/ConcreteExecutionListener.java` |
| `Constraint` | Abstract class | Decomposition, Uses, Generalization, Mapping | `src/main/gov/nasa/jpf/symbc/numeric/Constraint.java` |
| `ConstraintExpressionVisitor` | Visitor interface | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/ConstraintExpressionVisitor.java` |

## D

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `Debug` | Model class | Decomposition, Install, Mapping | `src/classes/gov/nasa/jpf/symbc/Debug.java` |
| `DebugSolvers` | Solver class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/solvers/DebugSolvers.java` |
| `DerivedStringExpression` | Expression class | Decomposition | `src/main/gov/nasa/jpf/symbc/string/DerivedStringExpression.java` |
| `DOTVisualizerListener` | Listener class | Decomposition | `src/main/gov/nasa/jpf/symbc/tree/visualizer/DOTVisualizerListener.java` |

## E

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `Expression` | Abstract class | Decomposition, Uses, Generalization, Mapping | `src/main/gov/nasa/jpf/symbc/numeric/Expression.java` |

## F

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `FunctionExpression` | Expression class | Decomposition | `src/main/gov/nasa/jpf/symbc/concolic/FunctionExpression.java` |

## G

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `GreenListener` | Listener class | Decomposition, Uses, Generalization | `src/main/gov/nasa/jpf/symbc/GreenListener.java` |

## H

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `HeapChoiceGenerator` | Choice generator class | Decomposition, Generalization, Mapping | `src/main/gov/nasa/jpf/symbc/heap/HeapChoiceGenerator.java` |
| `HeapNode` | Data class | Decomposition | `src/main/gov/nasa/jpf/symbc/heap/HeapNode.java` |
| `HeapSymbolicListener` | Listener class | Decomposition, Generalization | `src/main/gov/nasa/jpf/symbc/heap/HeapSymbolicListener.java` |
| `Helper` (heap) | Utility class | Decomposition | `src/main/gov/nasa/jpf/symbc/heap/Helper.java` |
| `HeuristicListener` | Listener class | Decomposition, Generalization | `src/main/gov/nasa/jpf/symbc/HeuristicListener.java` |

## I

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `InitExpression` | Expression class | Decomposition | `src/main/gov/nasa/jpf/symbc/arrays/InitExpression.java` |
| `IntegerConstant` | Expression class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/IntegerConstant.java` |
| `IntegerExpression` | Abstract class | Decomposition, Generalization, Mapping | `src/main/gov/nasa/jpf/symbc/numeric/IntegerExpression.java` |

## J

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `jpf.properties` | Configuration file | Install, Mapping | `jpf.properties` |
| `JPF_gov_nasa_jpf_symbc_Debug` | Native peer class | Decomposition, Mapping | `src/peers/gov/nasa/jpf/symbc/JPF_gov_nasa_jpf_symbc_Debug.java` |
| `JPF_java_lang_Math` | Native peer class | Decomposition | `src/peers/gov/nasa/jpf/symbc/JPF_java_lang_Math.java` |

## L

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `LinearIntegerConstraint` | Constraint class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/LinearIntegerConstraint.java` |
| `LogicalORLinearIntegerConstraints` | Constraint class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/LogicalORLinearIntegerConstraints.java` |

## M

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `MathRealExpression` | Expression class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/MathRealExpression.java` |
| `MinMax` | Configuration class | Decomposition | `src/main/gov/nasa/jpf/symbc/numeric/MinMax.java` |
| `MixedConstraint` | Constraint class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/MixedConstraint.java` |

## N

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `NonLinearIntegerConstraint` | Constraint class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/NonLinearIntegerConstraint.java` |

## O

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `Observations` | Static data holder | Decomposition | `src/main/gov/nasa/jpf/symbc/Observations.java` |
| `Operator` | Enum | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/Operator.java` |
| `OSM` | Abstraction class | Decomposition | `src/main/gov/nasa/jpf/symbc/abstraction/OSM.java` |

## P

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `@Partition` | Annotation | Decomposition | `src/annotations/gov/nasa/jpf/symbc/Partition.java` |
| `PathCondition` | Core data class | Decomposition, Uses, Generalization, Mapping | `src/main/gov/nasa/jpf/symbc/numeric/PathCondition.java` |
| `PCAnalyzer` | Concolic analysis class | Decomposition, Uses | `src/main/gov/nasa/jpf/symbc/concolic/PCAnalyzer.java` |
| `PCChoiceGenerator` | Choice generator class | Decomposition, Uses, Generalization, Mapping | `src/main/gov/nasa/jpf/symbc/numeric/PCChoiceGenerator.java` |
| `PCParser` | Parser class | Decomposition, Uses | `src/main/gov/nasa/jpf/symbc/numeric/PCParser.java` |
| `@Preconditions` | Annotation | Decomposition | `src/annotations/gov/nasa/jpf/symbc/Preconditions.java` |
| `ProblemChoco` | Solver class | Decomposition, Uses, Generalization, Mapping | `src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemChoco.java` |
| `ProblemCoral` | Solver class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemCoral.java` |
| `ProblemCVC3` | Solver class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemCVC3.java` |
| `ProblemDReal` | Solver class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemDReal.java` |
| `ProblemGeneral` | Abstract solver class | Decomposition, Uses, Generalization, Mapping | `src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemGeneral.java` |
| `ProblemIAsolver` | Solver class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemIAsolver.java` |
| `ProblemYices` | Solver class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemYices.java` |
| `ProblemZ3` | Solver class | Decomposition, Uses, Generalization, Mapping | `src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemZ3.java` |
| `ProblemZ3BitVector` | Solver class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemZ3BitVector.java` |
| `ProblemZ3Incremental` | Solver class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemZ3Incremental.java` |
| `ProblemZ3Optimize` | Solver class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/solvers/ProblemZ3Optimize.java` |

## R

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `RealArrayConstraint` | Constraint class | Decomposition | `src/main/gov/nasa/jpf/symbc/arrays/RealArrayConstraint.java` |
| `RealConstant` | Expression class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/RealConstant.java` |
| `RealConstraint` | Constraint class | Generalization | `src/main/gov/nasa/jpf/symbc/numeric/RealConstraint.java` |
| `RealExpression` | Abstract class | Decomposition, Generalization | `src/main/gov/nasa/jpf/symbc/numeric/RealExpression.java` |

## S

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `SelectExpression` | Expression class | Decomposition | `src/main/gov/nasa/jpf/symbc/arrays/SelectExpression.java` |
| `SequenceChoiceGenerator` | Choice generator class | Decomposition | `src/main/gov/nasa/jpf/symbc/sequences/SequenceChoiceGenerator.java` |
| `SolverTranslator` | Translator class | Uses, Mapping | `src/main/gov/nasa/jpf/symbc/numeric/solvers/SolverTranslator.java` |
| `SpecialIntegerExpression` | Expression class | Decomposition | `src/main/gov/nasa/jpf/symbc/mixednumstrg/SpecialIntegerExpression.java` |
| `StoreExpression` | Expression class | Decomposition | `src/main/gov/nasa/jpf/symbc/arrays/StoreExpression.java` |
| `StringConstraint` | Constraint class | Decomposition | `src/main/gov/nasa/jpf/symbc/string/StringConstraint.java` |
| `StringExpression` | Abstract class | Decomposition | `src/main/gov/nasa/jpf/symbc/string/StringExpression.java` |
| `StringPathCondition` | Path condition class | Decomposition, Uses, Mapping | `src/main/gov/nasa/jpf/symbc/string/StringPathCondition.java` |
| `StringSymbolic` | Expression class | Decomposition | `src/main/gov/nasa/jpf/symbc/string/StringSymbolic.java` |
| `@Symbolic` | Annotation | Decomposition, Install, Mapping | `src/annotations/gov/nasa/jpf/symbc/Symbolic.java` |
| `SymbolicAbstractionListener` | Listener class | Decomposition | `src/main/gov/nasa/jpf/symbc/abstraction/SymbolicAbstractionListener.java` |
| `SymbolicConstraintsGeneral` | Solver dispatch class | Decomposition, Uses, Rationale | `src/main/gov/nasa/jpf/symbc/numeric/SymbolicConstraintsGeneral.java` |
| `SymbolicInputHeap` | Heap model class | Decomposition | `src/main/gov/nasa/jpf/symbc/heap/SymbolicInputHeap.java` |
| `SymbolicInstructionFactory` | Factory class | Decomposition, Uses, Generalization, Install, Rationale, Mapping | `src/main/gov/nasa/jpf/symbc/SymbolicInstructionFactory.java` |
| `SymbolicInteger` | Expression class | Decomposition, Generalization | `src/main/gov/nasa/jpf/symbc/numeric/SymbolicInteger.java` |
| `SymbolicListener` | Listener class | Decomposition, Uses, Generalization, Mapping | `src/main/gov/nasa/jpf/symbc/SymbolicListener.java` |
| `SymbolicListener2` | Listener class | Decomposition | `src/main/gov/nasa/jpf/symbc/SymbolicListener2.java` |
| `SymbolicReal` | Expression class | Decomposition, Generalization | `src/main/gov/nasa/jpf/symbc/numeric/SymbolicReal.java` |
| `SymbolicSequenceListener` | Listener class | Decomposition | `src/main/gov/nasa/jpf/symbc/sequences/SymbolicSequenceListener.java` |
| `SymbolicStringConstraintsGeneral` | String solver dispatch | Decomposition | `src/main/gov/nasa/jpf/symbc/string/SymbolicStringConstraintsGeneral.java` |
| `SymbolicStringHandler` | Bytecode utility class | Decomposition | `src/main/gov/nasa/jpf/symbc/bytecode/SymbolicStringHandler.java` |

## T

| Element | Type | Views | Source Path |
|---------|------|-------|-------------|
| `TranslateToZ3str2` | String solver translator | Decomposition | `src/main/gov/nasa/jpf/symbc/string/translate/TranslateToZ3str2.java` |
| `TranslateToABC` | String solver translator | Decomposition | `src/main/gov/nasa/jpf/symbc/string/translate/TranslateToABC.java` |
| `TranslateToAutomata` | String solver translator | Decomposition | `src/main/gov/nasa/jpf/symbc/string/translate/TranslateToAutomata.java` |
