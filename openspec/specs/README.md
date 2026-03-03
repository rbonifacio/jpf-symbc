# JPF-SymBC Specifications

## Organization

Specs are organized by 3 domains covering the areas impacted by the planned migration (Ant/Java 8 → Maven/Java 11). These document the **current implemented behavior** of the system — not aspirational or post-migration state.

| Domain | Scope | Invariants | Scenarios | Spec |
|--------|-------|------------|-----------|------|
| **build** | Build system, source roots, JARs, compilation targets | 8 | 5 | [build/spec.md](build/spec.md) |
| **dependencies** | jpf-core, 28 solver JARs, native libraries | 7 | 4 | [dependencies/spec.md](dependencies/spec.md) |
| **configuration** | .jpf files, jpf.properties, site.properties | 9 | 5 | [configuration/spec.md](configuration/spec.md) |
| **Total** | | **24** | **14** | |

Domains NOT impacted by the migration (symbolic execution engine, bytecode instructions, constraint solving logic) are not spec'd — that functionality is preserved unchanged.

## Spec Structure

Each spec follows four sections:

1. **Purpose** — Narrative description with architecture, data models, and cross-domain relationships
2. **Data Contracts** — Input, Output, Side-Effects
3. **Invariants** — Testable assertions using RFC 2119 keywords (INV-XX-NN)
4. **Requirements** — One per FR/NFR with WHEN/THEN/AND scenarios

## Conventions

- **Language**: English throughout
- **Keywords**: RFC 2119 (MUST, MUST NOT, SHALL, SHOULD, MAY)
- **Invariant IDs**: `INV-XX-NN` where XX is the domain abbreviation
  - BLD (build), DEP (dependencies), CFG (configuration)
- **Requirement format**: `### Requirement: Name (FR/NFR ID)`
- **Scenario format**: `#### Scenario: Descriptive Name` with WHEN/THEN/AND

## Brownfield Rule

These specs document the **current implemented behavior** of the system.
They are NOT aspirational — they describe what exists today.

Future changes follow the OpenSpec workflow:
1. Create a change proposal in `openspec/changes/`
2. Generate artifacts: proposal.md, specs/ (delta), design.md, tasks.md
3. Implement, verify, and archive
4. Sync delta specs to main specs via `/openspec-sync-specs`

## Related Documents

- **PRD**: [docs/PRD.md](../../docs/PRD.md) — Migration requirements (13 FRs, 7 NFRs)
- **Pre-plan**: [20260227_plano_migracao_java11.md](../../20260227_plano_migracao_java11.md) — Detailed migration plan (input document)
- **CLAUDE.md**: [CLAUDE.md](../../CLAUDE.md) — Development guide
- **Config**: [openspec/config.yaml](../config.yaml) — OpenSpec rules and conventions
