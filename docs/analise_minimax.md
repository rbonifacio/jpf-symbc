# Análise Rigorosa da Mudança: gh1-migration-maven-java11

> **Analista**: Minimax M2.5 (opencode/minimax-m2.5-free)  
> **Data**: 2026-03-03  
> **Artefatos Analisados**: proposal.md, design.md, tasks.md, specs/build/spec.md, specs/dependencies/spec.md, specs/configuration/spec.md  
> **Referência SDD**: docs/SDD.md, docs/skills-agents-architecture.md, .sdd/docs/SDD-WORKFLOW.md

---

## Sumário Executivo

| Aspecto | Avaliação |
|---------|-----------|
| **Conformidade SDD** | Alta - segue todos os 4 artefatos requeridos |
| **Completude** | Excelente - 59 tasks organizadas em 9 grupos |
| **Qualidade das Specs** | Boa - formato WHEN/THEN/AND, INVariants definidos |
| **Qualidade do Design** | Muito Boa - decisões documentadas, rollback claro |
| **Qualidade das Tasks** | Excelente - critérios quantitativos, dependências explícitas |
| **Risco Geral** | Médio-Alto - migração de build system + Java version |

**Veredito Final**: APROVADO COM RESSALVAS - A mudança está bem preparada e segue os princípios SDD. Recomenda-se prosseguir com a implementação após corrigir o typo em INV-BLD-12 e considerar a simplificação da Fase 0.

---

## 1. Proposal.md - Análise Detalhada

### 1.1 Avaliação de "Why"

O documento identifica corretamente os três problemas fundamentais:

1. **Java 8 EOL**: Java 8 encerrou atualizações públicas em janeiro de 2019, representando um risco de segurança e incompatibilidade.
2. **Stale jpf-core fork**: O fork yannicnoller/jpf-core está desatualizado e diverge do oficial javapathfinder/jpf-core.
3. **Falta de dependency management**: 28 JARs commitados diretamente em `lib/` sem version tracking ou resolução transitiva.

A análise é precisa e estabelece claramente a necessidade de migração.

### 1.2 Avaliação de "What Changes"

As 20 mudanças listadas são específicas e quantificáveis:

| Categoria | Quantidade | Exemplos |
|-----------|------------|----------|
| Build system | 1 | Ant → Maven multi-module |
| Java version | 1 | 8 → 11 |
| jpf-core | 1 | fork → official |
| Source roots | 5 | 6 src roots → 5 Maven modules |
| Dependencies | 5 | 8 Central + 20 local |
| Configuration | 5 | 154 .jpf path updates |
| Cleanup | 2 | Remove build.xml, etc. |

### 1.3 Problemas Identificados no Proposal

**Problema 1.1**: Seções "Capabilities" repetem informação
- As linhas 30-32 replicam o que já está em "What Changes"
- Recomenda-se remover ou condensar

**Problema 1.2**: Risk areas sem mitigação no proposal
- As 4 risk areas são identificadas (linhas 55-57)
- A mitigação está no design.md, o que é aceitável
- Mas o proposal deveria ter um summary das estratégias

---

## 2. Specs - Análise Detalhada

### 2.1 build/spec.md

#### INVariants Presentes

| Invariant | Tipo | Avaliação |
|-----------|------|-----------|
| INV-BLD-01 | MODIFIED | ✅ Correto - Java 11 |
| INV-BLD-02 | MODIFIED | ✅ Correto - main+peers merged |
| INV-BLD-03 | MODIFIED | ✅⚠️ BREAKING CHANGE bem documentado |
| INV-BLD-04 | MODIFIED | ✅ Correto - annotations only |
| INV-BLD-09 | ADDED | ✅ Correto - java.base patch-module |
| INV-BLD-10 | ADDED | ✅ Correto - java.desktop patch-module |
| INV-BLD-11 | ADDED | ✅ Correto - ordem de compilação |
| INV-BLD-12 | ADDED | ❌ ERRADO - ver problema 2.1 |

**Problema 2.1 - INV-BLD-12 com erro tipográfico**:

Linha 21 do spec:
```
INV-BLD-12: Maven reactor MUST resolve module compilation order from <dependency> declarations: 
             annotations → main, classes → tests, examples
```

**Análise**: A seta "annotations → main" está semanticamente incorreta. Annotations não depende de ninguém - é o módulo base. A dependência correta é:

```
jpf-symbc-annotations  (nenhuma dependência)
        ↓
jpf-symbc-main         → annotations
jpf-symbc-classes      → annotations
        ↓
jpf-symbc-tests        → main + classes + annotations
jpf-symbc-examples     → main + classes + annotations
```

O design.md (linhas 117-124) apresenta corretamente, então o spec está com typo.

#### INVariants Removidos

- INV-BLD-07 (debug symbols): Removido com justificativa "Maven enables by default"
- INV-BLD-08 (deprecation warnings): Removido com justificativa "configured via pluginManagement"

**Problema 2.2**: A remoção de INV-BLD-07/08 vai contra o princípio SDD de verificar resultados. Em vez de remover, deveria改为 um cenário verificável:

```
Scenario: Debug Symbols Enabled
- WHEN mvn compile is executed
- THEN javap -g is used for compilation
- AND .class files contain LineNumberTable and LocalVariableTable
```

### 2.2 dependencies/spec.md

#### Pontos Fortes

1. **Detecção do BLOCKER opt4j**: O spec identifica corretamente que opt4j 2.4 bundles Guice 1.0 com ASM 1.5.3 que não consegue parsear Java 11 class files (formato 55.0). Esta é uma dependência indireta crítica: jpf-symbc source não tem imports opt4j, mas coral.jar tem.

2. **INV-DEP-10 (Exact Version Match)**: Garante que não haverá comportamento inesperado por upgrade de versão não intencional.

3. **SHA-256 Verification**: Os cenários 91-102 integram verificação de integridade corretamente.

4. **Native Library Scenarios**: Distingue entre System.loadLibrary() (smoke test) e funcionalidade JNI completa.

#### Problemas Identificados

**Problema 2.3 - INV-DEP-05详细内容 implementação**:

O invariant menciona `jpf.properties` que é um detalhe de implementação, não um comportamento do sistema. O invariant deveria focar no resultado:
```
INV-DEP-05 (recomendado): jpf-symbc native classpath MUST include all JARs required for symbolic execution at runtime
```

**Problema 2.4 - opt4j 3.3 vs 3.4 não é verificável diretamente**:

O spec diz "3.4+ requires Java 21" mas isso deveria ser dois cenários separados:
```
Scenario: opt4j 3.3 on Java 11
- WHEN opt4j 3.3 is used with Java 11
- THEN it MUST compile and run without ClassFormatError

Scenario: opt4j 3.4+ on Java 11
- WHEN opt4j 3.4+ is used with Java 11
- THEN it MUST NOT be used (requires Java 21 minimum)
```

### 2.3 configuration/spec.md

#### Pontos Fortes

1. **INV-CFG-13 (sourcepath)**: Explicita que `jpf-symbc.sourcepath` NÃO existe e não deve ser adicionado. Esta clareza evita Feature Envy.

2. **INV-CFG-10 (Zero build/ references)**: Quantificável e verificável - grep deve retornar vazio.

3. **2 .jpf extras**: TestMain.jpf e Example.jpf são identificados corretamente como needing manual handling.

4. **Non-standard paths scenario**: Antecipa problemas com caminhos absolutos ou não-padrão.

#### Problemas Identificados

**Problema 2.5 - INV-CFG-13 formato estranho**:

```
INV-CFG-13: jpf-symbc.sourcepath does NOT exist in the current jpf.properties and 
            MUST NOT be added during migration
```

A negação dupla "does NOT exist... and MUST NOT be added" é confusa. Recomendação:
```
INV-CFG-13: jpf-symbc.sourcepath is NOT part of jpf.properties configuration
            (source paths are specified per .jpf file, not at extension level)
```

---

## 3. Design.md - Análise Detalhada

### 3.1 Decisions (D1-D6)

| Decisão | Escolha | Alternativa Considerada | Avaliação |
|---------|---------|------------------------|-----------|
| D1 | Maven | Gradle | ✅ Justificativa correta |
| D2 | repo/ local | Nexus/Artifactory/systemPath | ✅ Custo-benefício correto |
| D3 | Merge peers into main | Separate module | ✅ Verificado sem conflitos |
| D4 | 3 compiler executions | - | ✅ Segue jpf-core pattern |
| D5 | Phased (8→11) | Direct to 11 | ✅ Bom isolamento de riscos |
| D6 | publishToMavenLocal | - | ✅ Padrão JPF |

Cada decisão segue o padrão SDD: Choice + Rationale + Alternative considered.

### 3.2 Error Handling

| Error | Strategy | Recovery | Avaliação |
|-------|----------|----------|-----------|
| jpf-core coords mismatch | Verify before POMs | Update POMs | ✅ |
| Native lib fail | Z3 blocker, others optional | Document unsupported | ✅ |
| API incompatibility | Fix source | Case-by-case | ⚠️ Escopo indefinido |
| .jpf paths miss | grep -rL verification | Manual fix | ✅ |
| --patch-module fail | Follow jpf-core | Debug with -X | ✅ |
| Maven reactor order | Declare deps | Reactor resolves | ✅ |

### 3.3 Rollback Plan

O plano de rollback é completo:

1. **git tag pre-migration-java11**: Safety net criado
2. **Critérios por fase**: Triggers claros para abort
3. **Procedimento Recovery**: 3 passos documentados

### 3.4 Quantitative Acceptance Criteria

| Fase | Métrica | Valor Esperado |
|------|---------|----------------|
| Phase 1 | Java files compile | 765, 0 errors |
| Phase 1 | Modules in reactor | 5 |
| Phase 1 | Dependency conflicts | 0 |
| Phase 2 | Model classes patch-module | 4, 3 executions |
| Phase 2 | Runtime module errors | 0 |
| Phase 3 | Tests pass | Same as Ant |

**Avaliação**: Excelente - critérios quantificáveis permitem verificação objetiva.

### 3.5 Open Questions

| # | Questão | Status | Avaliação |
|---|---------|--------|-----------|
| 1 | jpf-core coordinates | Expected | ✅ Task 0.2 resolve |
| 2 | Z3 native compat | Unknown | ⚠️ Phase 0.3 |
| 3 | API divergence scope | Unknown | ⚠️ Phase 0.4 |
| 4 | PathConditionsReliability | ✅ RESOLVED | Dead reference |
| 5 | opt4j upgrade scope | ✅ RESOLVED | Indirect in coral.jar |
| 6 | add-opens completeness | Unknown | ⚠️ Empirical |
| 7 | SAT4J custom | ✅ RESOLVED | Keep in repo/ |
| 8 | SHA-256 baseline | ✅ RESOLVED | Task 0.6 |
| 9 | Extra .jpf placement | ✅ RESOLVED | Task 0.9 |

### 3.6 Problemas no Design

**Problema 3.1 - Fase 0 muito grande**:

10 tasks (0.1-0.10) representa muita análise antes de implementar. SDD prega "fluid over rigid" - Fase 0 pode se tornar análise infinita.

**Recomendação**: Reduzir para 0.1-0.5 (blocos go/no-go críticos):
- 0.1: Safety net + baseline
- 0.2: jpf-core coordinates
- 0.3/0.3b: Z3 E2E (BLOCKER)
- 0.4: API divergence (GO/NO-GO threshold)
- 0.5: opt4j compatibility (BLOCKER for Coral)

0.6-0.10 podem ser executados em paralelo como parte da implementação.

**Problema 3.2 - Task 0.1 Ant baseline**:

`ant test` pode levar ~2 horas. A task não inclui timeout ou opção de fazer apenas compile.

**Recomendação**: Adicionar timeout de 3 horas ou opção de compile-only.

---

## 4. Tasks.md - Análise Detalhada

### 4.1 Estrutura de Grupos

| Grupo | Tasks | Dependências | Avaliação |
|-------|-------|--------------|-----------|
| 0 (Risk Validation) | 0.1-0.10 | N/A (primeiro) | ⚠️ Muito grande |
| 1 (Local Repo) | 1.1-1.4 | 0 completo | ✅ |
| 2 (Maven Structure) | 2.1-2.7 | 0 completo | ✅ |
| 3 (Move Source) | 3.1-3.13 | 2 completo | ✅ |
| 4 (.jpf Paths) | 4.1-4.6 | 3 completo | ✅ |
| 5 (Java 11) | 5.1-5.7 | 3 completo | ✅ |
| 6 (jpf-core compat) | 6.1-6.6 | 5 completo | ✅ |
| 7 (Cleanup) | 7.1-7.6 | 6 completo | ✅ |
| 8 (Verification) | 8.1-8.11 | 7 completo | ✅ |

### 4.2 Subagent Dispatch Hints

As hints (linhas 1-31) são exemplares:

1. **Caminho crítico explícito**: 0 → 2 → 3 → 4 → 5 → 6 → 7 → 8
2. **Paralelismo identificado**: Groups 1+2, dentro de 3, dentro de 4
3. **SDKMAN management**: Java 8 e 11 bem documentados

### 4.3 Tasks Individuais de Destaque

**Tarefas Exemplares**:

- **Task 0.1**: Safety net + baseline + JAR class lists
- **Task 0.3b**: E2E Z3 test (distingue smoke de funcionalidade)
- **Task 0.4**: API divergence threshold (<10, 10-50, >50)
- **Task 0.5/0.5b**: Detecção de dependência indireta opt4j
- **Task 0.8**: PathConditionsReliability dead reference check
- **Task 2.5**: Exclusions incluem Test*$*.class

**Tarefas com Issues**:

- **Task 2.5 line 169**: "Test*$*.class" vs spec "**/Test*$*.class" - inconsistência
- **Task 3.1**: Modificação antes do copy pode perder histórico git
- **Task 3.13**: Verifica count mas não conteúdo
- **Task 8.2**: "within tolerance" é vago - qual tolerância?

### 4.4 Problemas nas Tasks

**Problema 4.1 - Numeração inconsistente**:

Task 0.5b existe mas 0.5a não. Deveria ser 0.5/0.6 ou 0.5a/0.5b.

**Problema 4.2 - Task 5.4 surefire flags**:

A task lista flags --add-opens/--add-exports fixas, mas não há mecanismo para expandir se mais forem necessárias. Task 5.7 diz "expand empirically" mas não há task para implementar os resultados.

**Problema 4.3 - Task 8.2 tolerância**:

"within tolerance for newly-working tests" é muito vago. Recomendação:
```
**Acceptance**: Same pass/fail/skip counts as Ant ant test 
                (≤1% difference in pass rate, any new failures documented)
```

---

## 5. Consistência Inter-Artefatos

### 5.1 rastreabilidade FR/NFR

| FR/NFR | Proposal | Specs | Design | Tasks | Status |
|--------|----------|-------|--------|-------|--------|
| FR01 | ✅ | ✅ (FR01) | ✅ (mvn compile) | ✅ (5.1, 5.6) | Completo |
| FR02 | ✅ | ✅ (FR02) | ✅ (5 modules) | ✅ (2.x, 3.x) | Completo |
| FR03 | ✅ | ✅ (INV-BLD-01) | ✅ (java 11) | ✅ (5.2, 5.6) | Completo |
| FR04 | ✅ | ✅ (INV-BLD-09/10) | ✅ (3 executions) | ✅ (5.3) | Completo |
| FR05 | ✅ | ✅ (INV-DEP-08/09) | ✅ (repo/) | ✅ (1.x) | Completo |
| FR06 | ✅ | ✅ (INV-DEP-10) | ✅ (8 Central) | ✅ (1.4) | Completo |
| FR07 | ✅ | ✅ (INV-CFG-10) | ✅ (.jpf paths) | ✅ (4.x) | Completo |
| FR08 | ✅ | ✅ (INV-CFG-06) | ✅ (jpf.properties) | ✅ (6.2) | Completo |
| FR09 | ✅ | ✅ (scenario test) | ✅ (surefire) | ✅ (2.5, 5.4) | Completo |
| FR10 | ✅ | ✅ (scenario exclusion) | ✅ (exclusions) | ✅ (2.5, 6.4b) | Completo |
| FR11 | ✅ | ✅ (INV-DEP-11) | ✅ (official) | ✅ (0.2, 6.1) | Completo |
| FR12 | ✅ | ✅ | ✅ (cleanup) | ✅ (7.1-7.3) | Completo |
| FR13 | ✅ | ✅ | ✅ (docs) | ✅ (7.5-7.6) | Completo |
| NFR01 | ✅ | ✅ (solver scenarios) | ✅ (smoke tests) | ✅ (6.6, 8.9) | Completo |
| NFR02 | ✅ | ✅ (native lib) | ✅ (lib/ preserved) | ✅ (7.3, 8.6) | Completo |
| NFR03 | ✅ | ✅ (semantics preserved) | ✅ (.jpf paths) | ✅ (4.4-4.5) | Completo |
| NFR04 | ✅ | ✅ (JAR content) | ✅ (SHA baseline) | ✅ (8.5) | Completo |
| NFR05 | ✅ | ✅ (tests pass) | ✅ (surefire) | ✅ (8.2) | Completo |

### 5.2 Inconsistências Identificadas

| Inconsistência | Local | Impacto | Correção |
|----------------|-------|---------|----------|
| INV-BLD-12 typo | build/spec.md:21 | Medium | Corrigir setas de dependência |
| Test*$* vs **/Test*$* | tasks.md:80 vs spec | Low | Padronizar com **/ |
| INV-CFG-13 formato | configuration/spec.md:19 | Low | Simplificar linguagem |

---

## 6. Análise de Riscos

### 6.1 Riscos Identificados

| Risco | Impacto | Prob | Mitigação | Status |
|-------|---------|------|-----------|--------|
| API divergence >50 | Alto | Média | Abort + document | ⚠️ Sem plano B |
| Z3 native lib fail | Alto | Média | Phase 0.3 smoke | ✅ Coberto |
| opt4j BLOCKER | Alto | Alta | Upgrade to 3.3 | ✅ Coberto |
| 154 .jpf miss | Médio | Baixa | grep verification | ✅ Coberto |
| --patch-module fail | Alto | Baixa | Follow jpf-core | ⚠️ Depende |
| ClassLoader + modules | Médio | Média | E2E test Phase 3 | ✅ Coberto |
| Surefire parity | Médio | Baixa | mvn test -X | ✅ Coberto |

### 6.2 Avaliação de Mitigações

**✅ Boas Mitigações**:

1. **opt4j**: Upgrade para 3.3 é direto e verificável
2. **.jpf paths**: grep -rl e grep -rL são verificáveis
3. **Native libs**: Preservação explícita documentada

**⚠️ Mitigação Incompleta**:

1. **API divergence >50**: Apenas "abort" - sem plano B se abort for necessário. Recomendação: se >50, avaliar migração gradual (apenas Java version, manter fork jpf-core)

---

## 7. Conformidade com SDD

### 7.1 Checklist de Artefatos

| Artefato SDD | Presente | Qualidade |
|--------------|----------|-----------|
| ✅ Proposal (Why/What/Capabilities/Impact) | Sim | Excelente |
| ✅ 3 Specs (build/dependencies/configuration) | Sim | Boa (com issues) |
| ✅ Design (arquitetura + decisões) | Sim | Muito Boa |
| ✅ Tasks (com verificação) | Sim | Excelente |

### 7.2 Checklist de Estrutura

| Estrutura SDD | Presente | Qualidade |
|---------------|----------|-----------|
| ✅ RFC 2119 (MUST/SHALL) | Sim | Presente em specs |
| ✅ WHEN/THEN/AND cenários | Sim | Presente em specs |
| ✅ INVariants (INV-*) | Sim | 14 (4 com issues) |
| ✅ Critérios quantificáveis | Sim | Excelente |
| ✅ Rollback plan | Sim | Completo |
| ✅ Error handling | Sim | Excelente |

### 7.3 Score SDD Final

| Dimensão | Score |
|----------|-------|
| Completude de Artefatos | 10/10 |
| Qualidade de Specs | 8/10 |
| Qualidade de Design | 9/10 |
| Qualidade de Tasks | 9/10 |
| Consistência | 9/10 |
| Risco Mitigação | 8/10 |

**Overall: 9/10**

---

## 8. Recomendações

### 8.1 Correções Obrigatórias

1. **INV-BLD-12 typo**: Corrigir dependências do módulo
   ```
   INV-BLD-12: Maven reactor MUST resolve module compilation order:
                jpf-symbc-annotations (no deps) → 
                jpf-symbc-main + jpf-symbc-classes (depends on annotations) →
                jpf-symbc-tests + jpf-symbc-examples (depends on main+classes+annotations)
   ```

2. **Task 2.5 padrão**: Usar `**/Test*$*.class` para consistência com spec

### 8.2 Melhorias Recomendadas

1. **Simplificar Fase 0**:
   - Reduzir para tasks 0.1-0.5
   - 0.6-0.10 executar em paralelo com implementação

2. **Adicionar Task 0.0 (Pre-flight)**:
   ```bash
   # Verificar SDKMAN instalado
   # Verificar Java 8 e 11 disponíveis
   # Verificar espaço em disco >2GB
   ```

3. **Task 8.2 tolerância explícita**:
   ```
   **Acceptance**: ≤1% difference in pass rate from Ant baseline
   ```

4. **Adicionar SHA-256 para repo/ JARs**: Task 1.3 verifica estrutura mas não conteúdo

### 8.3 Considerações de Implementação

1. **Ordem de execução sugerida**:
   ```
   1. Task 0.0 (pre-flight)
   2. Task 0.1 (baseline - ~2 horas)
   3. Tasks 0.2-0.5 (go/no-go)
   4. Se GO: executar Groups 1-2 em paralelo
   5. Groups 3-4 (file moves + .jpf updates)
   6. Groups 5-6 (Java 11 + testing)
   7. Group 7-8 (cleanup + verification)
   ```

2. **Critical path**: 0 → 2 → 3 → 4 → 5 → 6 → 7 → 8

---

## 9. Veredito Final

### 9.1 Aprovação

**APROVADO COM RESSALVAS**

A mudança está bem preparada e segue os princípios SDD adequadamente. Os artefatos são completos, consistentes entre si, e incluem verificação quantitativa.

### 9.2 Condições para Prosseguir

| Condição | Prioridade | Status |
|----------|------------|--------|
| Corrigir INV-BLD-12 typo | 🔴 Alta | Pendente |
| Simplificar Fase 0 | 🟡 Média | Recomendado |
| Definir tolerância em 8.2 | 🟡 Média | Recomendado |

### 9.3 Risk Assessment Final por Fase

| Fase | Risco Principal | Blocker? | Mitigação |
|------|-----------------|----------|-----------|
| 0 | API divergence >50 | ⚠️ Sim (abort) | Threshold <50 |
| 1 | Maven structure fail | Não | Safe to debug |
| 2 | Module system fail | Não | Follow jpf-core |
| 3 | API adaptation scope | ⚠️ Sim | Depends on 0.4 |
| 4 | Test parity fail | Não | Parity verification |

### 9.4 Recomendação Final

**PROCEED** com a implementação seguindo a ordem recomendada:

1. Execute task 0.0 (pre-flight)
2. Execute task 0.1 (baseline) - pode levar ~2 horas
3. Valide rapidamente resultados de 0.2-0.5
4. Se 0.4 (API divergence) mostrar >50 breaking changes, **ABORT** e reavalie escopo
5. Execute groups 1-4 em paralelo onde possível (após Fase 0)
6. Use /sdd-verify ao final de cada fase

---

## Anexo A: Métricas de Qualidade

| Métrica | Valor |
|---------|-------|
| Total de tasks | 59 |
| Total de grupos | 9 |
| Tasks em path crítico | 59 |
| Tasks paralelizáveis | ~15 |
| INVariants definidos | 14 |
| INVariants com issues | 2 |
| Decisões documentadas | 6 |
| Open questions | 9 (4 resolved) |
| Cenários WHEN/THEN/AND | ~25 |
| Riscos identificados | 7 |
| Riscos com mitigação | 6 |

## Anexo B: Fontes Consultadas

- docs/SDD.md - Seções 1-10 (Overview, Origins, Definition, Principles, Spectrum, Specifications, Comparisons, Workflow, Tool Landscape, Criticisms)
- docs/skills-agents-architecture.md - Seções 1-9 (Problem Statement, Claude Code definitions, Empirical validation, Industry consensus)
- .sdd/docs/SDD-WORKFLOW.md - Seções 1-11 (Prerequisites, Getting Started, Track Selection, Full/FF/Quick walkthroughs, Skill reference, Writing specs)

---

*Relatório gerado em 2026-03-03 por Minimax M2.5 (opencode/minimax-m2.5-free)*
