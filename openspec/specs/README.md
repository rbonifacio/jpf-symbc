# JPF-SymBC Specifications

## Organization

Specs are organized by 3 domains covering the areas impacted by the migration (Maven multi-module, Java 11). These document the **post-migration behavior** of the system after applying the `gh1-migration-maven-java11` change.

| Domain | Scope | Invariants | Scenarios | Spec |
|--------|-------|------------|-----------|------|
| **build** | Maven modules, compilation order, JARs, --patch-module | 10 | 6 | [build/spec.md](build/spec.md) |
| **dependencies** | jpf-core (official), Maven Central + local repo, native libraries | 12 | 11 | [dependencies/spec.md](dependencies/spec.md) |
| **configuration** | .jpf files, jpf.properties, site.properties, Maven paths | 12 | 6 | [configuration/spec.md](configuration/spec.md) |
| **Total** | | **34** | **23** | |

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

These specs document the **target behavior** after the `gh1-migration-maven-java11` change.
They were synced from delta specs after the migration artifacts were finalized.

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
