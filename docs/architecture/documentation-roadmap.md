# Documentation Roadmap

## Generated Views

| View | File | What It Shows | Evidence |
|------|------|---------------|----------|
| Module: Decomposition | `module-decomposition.md` | Top-level package structure, module responsibilities, source root organization | 6 source directories, 19 packages under `gov.nasa.jpf.symbc`, clear package boundaries |
| Module: Uses | `module-uses.md` | Inter-module dependencies and external library dependencies | Import statement analysis across 319 main source files; 28 JARs in `lib/` |
| Module: Generalization | `module-generalization.md` | Inheritance hierarchies for expressions, constraints, and solver backends | `Expression` hierarchy (10+ subclasses), `Constraint` hierarchy (5 subclasses), `ProblemGeneral` hierarchy (14 subclasses) |
| Allocation: Install | `alloc-install.md` | Build system, prerequisites, packaging, library bundling | `build.xml` with 6 compile targets, `jpf.properties` classpath, 28 JARs + native libs in `lib/` |

## Omitted Views

| View | Reason for Omission |
|------|---------------------|
| Module: Layered | No layered directory structure detected. Packages are organized by domain concern (bytecode, numeric, string, heap, arrays), not by layer (e.g., controller/service/repository). Call direction does not follow a strict top-to-bottom pattern. |
| Module: Aspects | No cross-cutting concern mechanisms detected. No AOP annotations, decorators, interceptors, or middleware patterns. Logging is done via direct `System.out.println` calls. |
| Module: Data Model | No database models, ORM entities, schema definitions, or migration files. The project operates on in-memory symbolic expression trees and constraint structures. |
| C&C: Pipe-Filter | No data transformation pipelines or stream processing patterns. Symbolic execution is tree-structured (branching exploration), not pipeline-structured. |
| C&C: Client-Server | No API endpoints, HTTP servers, or REST controllers. JPF-SymBC is a library/extension, not a networked service. |
| C&C: SOA | No service discovery, service registry, or service mesh configuration. |
| C&C: Pub-Sub | No message queue configuration (RabbitMQ, Kafka, etc.). No event bus or topic/subscription patterns. |
| C&C: Shared-Data | No shared database configuration. While the `jedis-2.0.0.jar` library is present in `lib/`, no Redis usage was detected in source code. |
| Allocation: Deployment | No Dockerfile, docker-compose, Kubernetes manifests, Helm charts, or CI/CD configuration files. The project is deployed by cloning and building locally. |
| Allocation: Work Assignment | No CODEOWNERS file. No team-scoped directory structure. |

## Beyond Views

| Document | File | Purpose |
|----------|------|---------|
| System Overview | `architecture-overview.md` | High-level project description, component diagram, technology stack, architectural drivers |
| Documentation Roadmap | `documentation-roadmap.md` | This document. Index of all generated and omitted views with justification. |
| View Mapping | `view-mapping.md` | Cross-view element correspondence table showing how elements appear across views |
| Architecture Rationale | `architecture-rationale.md` | Cross-cutting architectural decisions: extension model, one-class-per-bytecode, solver abstraction, etc. |
| Architecture Directory | `architecture-directory.md` | Alphabetical index of architectural elements |

## Reading Guide

### For a Developer New to the Project

1. Start with **System Overview** (`architecture-overview.md`) for high-level orientation.
2. Read **Module: Decomposition** (`module-decomposition.md`) to understand the package structure and module responsibilities.
3. Read **Module: Uses** (`module-uses.md`) to understand how modules depend on each other.
4. Read **Allocation: Install** (`alloc-install.md`) to set up a development environment.

### For an Architect Evaluating the Design

1. Start with **System Overview** (`architecture-overview.md`) for architectural drivers.
2. Read **Architecture Rationale** (`architecture-rationale.md`) for key design decisions and trade-offs.
3. Read **Module: Generalization** (`module-generalization.md`) to understand the extension points.
4. Use **View Mapping** (`view-mapping.md`) to trace elements across views.

### For Someone Adding a New Solver Backend

1. Read **Module: Generalization** (`module-generalization.md`), specifically the `ProblemGeneral` hierarchy section.
2. Read **Module: Uses** (`module-uses.md`) to understand the solver isolation pattern.
3. Read **Allocation: Install** (`alloc-install.md`) for library packaging requirements.
4. Read **Architecture Rationale** (`architecture-rationale.md`), Decision 3 (Solver Abstraction).

### For Someone Maintaining the Build System

1. Read **Allocation: Install** (`alloc-install.md`) for the complete build structure.
2. Read **Module: Decomposition** (`module-decomposition.md`), specifically the "Separate Source Roots" section.
3. Use **Architecture Directory** (`architecture-directory.md`) to locate specific elements.

## Checklists Applied

| Checklist | Items Found | Total | Notes |
|-----------|------------|-------|-------|
| Context Modeling | 11 / 20 | Items found: system boundary, external systems (solvers), external libraries, entry points (instruction factory, listeners), configuration sources (.jpf files, site.properties), data inputs/outputs (bytecodes in, path conditions out), variation points (solver selection, symbolic method config, array mode, optimization mode), build dependencies (Ant, jpf-core), third-party dependencies (28 JARs), integration contracts (ProblemGeneral API), data flow (bytecodes -> expressions -> constraints -> solver). Items not found: authentication, monitoring, compliance, security perimeter, versioning strategy, temporal dependencies, error propagation across boundaries, regulatory boundaries, deployment targets. |
| Structural Modeling | 16 / 20 | Items found: top-level decomposition (19 packages), module responsibilities, module dependencies, dependency direction (bytecode -> numeric -> solvers), public vs internal interfaces (ProblemGeneral, Expression, Constraint), shared types (Expression, PathCondition), namespace conventions (gov.nasa.jpf.symbc.*), coupling patterns (numeric hub), cohesion patterns (domain-based packages), utility modules (BytecodeUtils), configuration module (jpf.properties), test organization, build module boundaries (6 source roots), extension module boundaries (ProblemGeneral, listeners), entry point modules (SymbolicInstructionFactory). Items not found: circular dependency detection (not performed), module size distribution (not measured), data access patterns (N/A), plugin boundaries (partially, via ProblemGeneral). |
| Behavioral Modeling | 6 / 22 | Items found: request processing flow (bytecode -> expression -> constraint -> solver), concurrency model (forked per-test JVMs, JPF's thread model), state management (stateless symbolic execution, vm.storage.class=nil), error handling (RuntimeException for unsupported operations), background processing (N/A), data validation (MinMax bounds, max PC length/time). Items not found: most behavioral items are N/A for a library/extension (no HTTP, no caching, no sessions, no transactions, etc.). |
| Interaction Modeling | 5 / 20 | Items found: synchronous communication (JNI calls to native solvers, Java API calls to solver JARs), data serialization (SMT-LIB format for Z3-str2, prefix notation for Z3), configuration distribution (jpf.properties, .jpf files), inter-process communication (JNI bridge to native code), database connection patterns (N/A). Items not found: most interaction items are N/A for a non-networked library. |
| Interface Modeling | 7 / 20 | Items found: public API surface (ProblemGeneral, Expression hierarchy, PathCondition, annotations), internal API surface (per-module interfaces), extension points (ProblemGeneral for new solvers, listeners for new analyses), configuration interface (.jpf properties), CLI interface (JPF command-line via jpf-core), event/message interface (JPF listener events), deprecation (none formal). Items not found: REST/GraphQL APIs, webhooks, admin endpoints, migration interfaces, monitoring interfaces, error code taxonomy (all N/A). |
