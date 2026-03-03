# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JPF-SymBC (Symbolic Java PathFinder) is a JPF extension that provides symbolic execution for Java bytecode. It performs non-standard interpretation of bytecodes, enabling symbolic execution on methods with basic type arguments (int, long, double, boolean), symbolic strings, arrays, and user-defined data structures. It also supports a "symcrete" mode that combines concrete and symbolic execution.

**Requires Java 8 specifically — does not work with newer Java versions.**

## Build Commands

Build tool is **Apache Ant**. The `jpf-core` dependency must be available as a peer directory (`../jpf-core`) or configured in `~/.jpf/site.properties`.

```bash
ant compile    # Compile all sources
ant build      # Compile + generate JAR files (default target)
ant clean      # Remove build artifacts
ant test       # Run regression tests (requires JUNIT_HOME env var set)
```

Tests use JUnit 4, forked per test with 1024MB max memory. Many test classes are excluded from the automated `ant test` run (see exclusions in `build.xml`).

## Setup Requirements

Create `~/.jpf/site.properties`:
```properties
jpf-core = /path/to/jpf-core
jpf-symbc = /path/to/jpf-symbc
extensions=${jpf-core},${jpf-symbc}
```

The required jpf-core fork: https://github.com/yannicnoller/jpf-core/tree/0f2f2901cd0ae9833145c38fee57be03da90a64f

## Source Layout

```
src/main/         → Main implementation (JVM-level code)
src/classes/      → Model classes executed inside JPF (e.g., java.lang.* stubs)
src/annotations/  → Annotations usable by non-JPF apps
src/peers/        → Native peer implementations
src/tests/        → JUnit test suite
src/examples/     → Example programs with .jpf config files
lib/              → External solver JARs and native libraries
```

Build outputs go to `build/` with separate dirs for each source set, plus JAR files:
- `build/jpf-symbc.jar` — main JVM code
- `build/jpf-symbc-classes.jar` — JPF model classes + annotations
- `build/jpf-symbc-annotations.jar` — annotations only

## Architecture

### JPF Extension Model

JPF-SymBC plugs into JPF core via two main mechanisms:

1. **`SymbolicInstructionFactory`** (`src/main/gov/nasa/jpf/symbc/SymbolicInstructionFactory.java`) — Replaces standard JVM bytecode instructions with symbolic versions. Uses a `ClassInfoFilter` to selectively apply symbolic instructions only to target classes. Each bytecode (IADD, ISUB, IF_ICMPGE, etc.) has a symbolic counterpart in `gov.nasa.jpf.symbc.bytecode`.

2. **`SymbolicListener`** (`src/main/gov/nasa/jpf/symbc/SymbolicListener.java`) — Event listener extending `PropertyListenerAdapter` that hooks into JPF VM events (method entry/exit, instruction execution, choice generation). Manages path conditions and produces method summaries. Alternative listeners: `SymbolicListener2`, `HeuristicListener`, `GreenListener`.

### Core Packages (all under `gov.nasa.jpf.symbc`)

- **`bytecode/`** — Symbolic bytecode instruction implementations (60+ classes). Each overrides a JVM instruction to track symbolic values and generate constraints. Sub-packages: `optimization/`, `symarrays/`.

- **`numeric/`** — Constraint representation and solving. Key classes:
  - `PathCondition` — accumulated constraints along an execution path
  - `Expression` → `IntegerExpression` / `RealExpression` — expression tree hierarchy
  - `SymbolicInteger`, `SymbolicReal` — symbolic variable representations
  - `Constraint`, `LinearIntegerConstraint`, `NonLinearIntegerConstraint` — constraint types
  - `PCChoiceGenerator` — generates choice points at branches
  - `solvers/` — solver integrations (Choco, Coral, Z3, CVC3, etc.)

- **`string/`** — String symbolic execution. `StringExpression`, `StringConstraint`, `StringPathCondition`. Translators for Z3-str2 and ABC string solvers in `translate/`.

- **`heap/`** — Symbolic heap/object modeling with lazy initialization support.

- **`arrays/`** — Symbolic array indexing and element access.

- **`concolic/`** — Hybrid concrete-symbolic execution. `PCAnalyzer` analyzes path conditions from concrete runs.

- **`sequences/`** — Sequence-based testing support.

### Constraint Solver Backends

The system supports pluggable solvers configured via `.jpf` files. Solver JARs live in `lib/`:
- **Z3** (com.microsoft.z3.jar) — primary SMT solver, with native libs in `lib/64bit/`
- **Choco** — constraint programming
- **Coral** — constraint optimization
- **CVC3**, **STP**, **Yices** — additional SMT solvers
- **Green** (green.jar) — unified constraint solver framework
- **HAMPI**, **automaton.jar** — string constraint solving

### Running Examples

Examples are `.jpf` configuration files in `src/examples/` that specify the target class, symbolic method signatures, solver choice, and listeners. They are run through JPF with the SPF extension loaded.

### Configuration via .jpf Files

JPF-SymBC behavior is configured through `.jpf` property files that specify:
- `symbolic.method` — methods to execute symbolically with argument type annotations
- `symbolic.dp` — decision procedure/solver to use
- `listener` — which listener class to attach
- `jvm.insn_factory.class` — must be `gov.nasa.jpf.symbc.SymbolicInstructionFactory`
- `vm.storage.class=nil` — disables state matching (required for symbolic execution)

<!-- SDD-SECTION-START -->
## SDD Toolkit & Workflow

The project uses Spec-Driven Development (SDD) with the SDD Toolkit in **Full mode**. Specifications precede and guide implementation. The OpenSpec framework manages the process layer (what to build and why); sdd-* skills provide the execution layer (how to build it).

Full reference: `.sdd/docs/SDD-WORKFLOW.md`

### Infrastructure

- **Neo4j** knowledge graph in Docker (`sdd-graphdb`, bolt://localhost:7687)
- **MCP server `sdd`** for code analysis via `mcp__sdd__*` tools (get_component, get_dependencies, query_cypher)
- **Knowledge Graph** populated with ~773 units and ~5973 callables extracted from the codebase via tree-sitter
- **Config**: `.sdd/sdd-config.yaml` (mode: full)
- **Skills**: `.claude/skills/sdd-*/` (40 sdd-* skills) + `.claude/skills/openspec-*/` (10 openspec-* skills)
- **MCP servers** (`.mcp.json`): sdd, memory, sequential-thinking, context7

If the graph becomes stale after code changes, run `/sdd-extract` to re-populate.

### OpenSpec Workflow (Change Lifecycle)

Changes follow a structured artifact workflow. Track selection depends on whether design decisions are needed:

| Track | When | Entry Point |
|-------|------|-------------|
| **Full SDD** | Design decisions + multi-module/architectural | `/opsx:new` |
| **Fast-Forward** | Design decisions + single module, clear requirements | `/opsx:ff` |
| **Quick Path** | No design decisions, mechanical changes | `/opsx:new` with `sdd-quick-path` schema |

**Full SDD flow:**
```
/opsx:explore     → Think through the problem
/opsx:new         → Create change + proposal
/opsx:continue    → Create specs, design, tasks (repeat)
/opsx:apply       → Implement tasks (use component skills, NOT orchestrators)
/opsx:verify      → Validate implementation against specs
/opsx:archive     → Finalize and archive
```

**Artifacts produced per change** (in `openspec/changes/<name>/`):
- `proposal.md` — Why/what/impact
- `specs/*.md` — Delta specifications (WHEN/THEN/AND scenarios, INV-XX-NN invariants)
- `design.md` — Architecture, API design, decisions with rationale
- `tasks.md` — Ordered implementation checklist with verification steps

**Existing specs** (brownfield — document CURRENT behavior):
- `openspec/specs/build/spec.md` — Build system (Ant, source roots, JARs)
- `openspec/specs/dependencies/spec.md` — Dependencies (jpf-core fork, 28 JARs, native libs)
- `openspec/specs/configuration/spec.md` — Configuration (.jpf files, jpf.properties, site.properties)

### Current Change In Progress

**`openspec/changes/gh1-migration-maven-java11/`** — Migration to Maven multi-module + Java 11 ([#1](https://github.com/phtcosta/jpf-symbc/issues/1))
- All 4 artifacts complete (proposal, specs, design, tasks)
- 8 task groups with 50+ subtasks (Phase 0: risk validation → Phase 4: cleanup)
- Cross-LLM review incorporated (Codex, Gemini, Minimax, Qwen)
- **Next step**: `/opsx:apply` to begin implementation

Supporting docs:
- `docs/PRD.md` — 13 FRs + 7 NFRs for the migration
- `docs/pre-plan.md` — Detailed migration plan (4 phases, rev2)

### Key Skills

**During `/opsx:apply`** — use component skills directly (not orchestrators):
- `/sdd-test-run` — Run test suite (`ant test`)
- `/sdd-verify` — Full verification (tests + lint + complexity)
- `/sdd-qa-lint-fix` — Auto-fix lint issues
- `/sdd-test-add [file]` — Generate tests for a code unit

**Standalone workflows** (outside OpenSpec):
- `/sdd-feature [name]` — Full feature lifecycle
- `/sdd-tdd [target]` — TDD with RED-GREEN-REFACTOR
- `/sdd-refactor [module]` — Safe refactoring with verification
- `/sdd-architect [target]` — Architectural analysis (uses Neo4j)
- `/sdd-code-reviewer` — Multi-dimension code review
- `/sdd-onboarder` — Project onboarding guide

**Analysis** (read-only, mode-aware — Full mode queries Neo4j):
- `/sdd-analyze-module [path]` — Module architecture
- `/sdd-analyze-complexity [path]` — Complexity hotspots
- `/sdd-analyze-dependencies [path]` — Dependency graph, circular deps
- `/sdd-impact-analyzer [target]` — Reverse deps, affected tests

### Prerequisites

- Claude CLI (`claude`)
- Node.js (`npx`) — MCP tools (sequential-thinking, memory, context7)
- Docker + Python 3.11+ + uv — Neo4j + MCP server (Full mode)
- OpenSpec CLI (`openspec`) — change lifecycle management
<!-- SDD-SECTION-END -->
