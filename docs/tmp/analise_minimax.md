# Análise Rigorosa da Change: migration-maven-java11

**Data da Análise:** 02 de Março de 2026  
**Analista:** Minimax  
**Change:** `/openspec/changes/migration-maven-java11`

---

## Sumário Executivo

Esta análise avalia a change de migração do sistema de build do JPF-SymBC de Apache Ant para Maven multi-module, com atualização do Java 8 para Java 11. A change é fundamentalmente uma migration de infraestrutura sem adição de features, o que reduz o risco de introdução de novos bugs, mas aumenta o impacto caso a migração falhe completamente.

**Veredicto:** Change bem preparada com documentação exemplar, mas apresenta 2 inconsistências nos invariants de teste e 7 riscos não identificados que merecem atenção antes da execução.

---

## 1. PONTOS FORTES

### 1.1 Documentação Exemplar

A change demonstra um nível de documentação raro em projetos de migração:

- **Proposal completo** (60 linhas): Descrição clara das motivações incluindo:
  - Java 8 obsoleto desde 2019 (fim de atualizações públicas)
  - Fork jpf-core (yannicnoller) está stale e diverge do oficial
  - Ant build sem gerência de dependências (28 JARs flat em lib/)
  - Atrito para pesquisadores e isolamento da comunidade JPF ativa

- **Design detalhado** (294 linhas) incluindo:
  - Diagramas ASCII do estado atual vs. estado alvo
  - Tabelas de componentes com responsabilidade
  - Rastreabilidade FR → Implementation → Test
  - Decisões de design com alternativas consideradas

- **Specs bem estruturadas**: Separação clara em build, dependencies, configuration com invariants próprios

- **Tasks.md completo** (109 linhas): 8 grupos de tasks com dependências explícitas e caminho crítico definido

### 1.2 Fases Bem Definidas

| Phase | Objetivo | Validação |
|-------|----------|-----------|
| Phase 0 | Risk Validation (go/no-go) | Native libs, jpf-core coords, API divergence, opt4j |
| Phase 1 | Maven Structure (Java 8) | Estrutura Maven validada antes de mudar Java |
| Phase 2 | Java 11 Migration | Upgrade versão, --patch-module, --add-opens |
| Phase 3 | jpf-core Compatibility | API adaptation, testes end-to-end |
| Phase 4 | Cleanup | Remoção artefatos, docs |

Esta abordagem em fases é excelente porque:
- Isola problemas de build system vs. Java version
- Permite go/no-go antes de investir esforço significativo
- Validação incremental: mvn compile Java 8 → mvn compile Java 11

### 1.3 Mitigações de Riscos Identificadas

| Risco Identificado | Probabilidade | Impacto | Mitigation |
|--------------------|---------------|---------|------------|
| API jpf-core fork vs oficial | Média | Alto | Phase 0.4 git diff quantifies divergence |
| Native libs JDK 11 compatibility | Média | Médio | NativeLibSmokeTest.java com JDK 11 |
| --patch-module compilation | Baixa | Alto | Follow jpf-core Gradle pattern |
| ClassLoader + module system | Média | Médio | End-to-end testing em Phase 3 |
| **opt4j Guice/ASM Java 11** | **Alta** | **BLOCKER** | Upgrade opt4j 2.4 → 3.3 |

A identificação do opt4j como BLOCKER é particularmente importante - o projeto reconhece que opt4j 2.4 bundled Guice 1.0 com ASM 1.5.3 e CGLIB 2.1_3 que não conseguem parsear Java 11 class files (formato 55.0).

### 1.4 Rastreabilidade Excelente

O design.md contém uma tabela de rastreabilidade exemplar:

| Requirement | Implementation | Verification |
|-------------|---------------|--------------|
| FR01: Maven multi-module | pom.xml (parent) + 5 module POMs | mvn compile succeeds |
| FR02: 5 Maven modules | Directory structure + module declarations | All modules in reactor |
| FR03: Java 11 compilation | `<java.version>11</java.version>` | mvn compile with JDK 11 |
| FR04: --patch-module | 3 compiler executions | Model classes compile |
| ... | ... | ... |

Cada task em tasks.md referencia FRs específicos, permitindo tracking completo.

---

## 2. PONTOS FRACOS

### 2.1 Inconsistência Crítica: INV-BLD-03

| Aspecto | Spec Antiga (openspec/specs/build/spec.md) | Spec Nova (specs/build/spec.md da change) |
|---------|-------------------------------------------|-------------------------------------------|
| jpf-symbc-classes.jar | "MUST contain classes from both src/classes and src/annotations" | "Annotations available at compile time but NOT physically included" |

**Problema Identificado:** A mudança quebra a compatibilidade binária. O JAR original (build/jpf-symbc-classes.jar) incluía as annotations dentro do mesmo JAR. O novo design coloca annotations em JAR separado (jpf-symbc-annotations.jar).

Isso pode quebrar código que:
- Depende de annotations no classpath simples (sem dependency management)
- Faz referência a classes via classpath único
- Scripts existentes que esperam JAR único

**Recomendação:** Documentar esta mudança semanticamente de forma proeminente e garantir que jpf.properties inclua ambos os JARs no classpath.

### 2.2 Inconsistência nas Exclusões de Teste

| Pattern de Exclusão | Spec Antiga (build/spec.md:107-119) | Spec Nova (specs/build/spec.md da change:67-79) |
|---------------------|-------------------------------------|------------------------------------------------|
| `**/TestBitwise*` | EXCLUÍDO | **FALTA** - NÃO está na lista |
| `**/TestLazy*` | EXCLUÍDO | **FALTA** - NÃO está na lista |
| `**/JPF_*.java` | - | ADICIONADO (correto) |

**Problema:** As exclusões não foram transferidas completamente. Estes testes podem rodar durante `mvn test` e falhar, causando regressão.

**Recomendação:** Adicionar as exclusões faltantes à task 5.4 e specs/build/spec.md.

### 2.3 Falta de Plano de Rollback Explícito

A task 0.1 menciona criar tag `git tag pre-migration-java11` como "safety net", mas não há steps explícitos de:

- Como reverter se Phase 2 (Java 11) falhar permanentemente
- Como restaurar estado se testes não passarem após múltiplas tentativas
- Critérios para decidir "abortar migration" vs "continuar consertando"

### 2.4 Task 6.3 Ambígua

> "Resolve PathConditionsReliability-0.0.1.jar reference in jpf.properties — determine if dead reference (remove) or missing file (add to repo/)"

Esta task não foi investigada previamente:
- O JAR existe em algum lugar?
- É realmente usado pelo código?
- Se for usado, onde está a dependência?

**Recomendação:** Auditoria de referências a PathConditionsReliability antes de executar a migration.

### 2.5 Verificação de Import Morto Incompleta

A task 3.1 menciona:
> "Remove dead import in src/classes/java/awt/image/BufferedImage.java (import gov.nasa.jpf.symbc.Debug;)"

Mas não há verificação de que este é o ÚNICO import morto no codebase. Pode haver outros.

---

## 3. RISCOS IDENTIFICADOS

### 3.1 Riscos com Mitigação Adequada

| Risco | Probabilidade | Impacto | Status |
|-------|---------------|---------|--------|
| API jpf-core fork vs oficial | Média | Alto | ✓ Mitigado (Phase 0.4) |
| Native libs JDK 11 | Média | Médio | ✓ Mitigado (SmokeTest) |
| --patch-module compilation | Baixa | Alto | ✓ Mitigado (jpf-core pattern) |
| ClassLoader + module system | Média | Médio | ✓ Mitigado (end-to-end test) |
| opt4j Guice/ASM Java 11 | Alta | BLOCKER | ✓ Mitigado (upgrade to 3.3) |

### 3.2 Riscos NÃO Identificados

#### R1: JAR Checksum Incompatibilidade

**Descrição:** A change menciona "exact version match" para Maven Central, mas os JARs existentes em `lib/` podem ter sido modificados localmente (patches, custom builds).

**Risco:** Maven Central pode retornar versão semanticamente equivalente mas com bytes diferentes, causando comportamento sutilmente diferente.

**Recomendação:** Comparar SHA-256 de todos os 28 JARs pré-migração:
```bash
sha256sum lib/*.jar > /tmp/jar-checksums-pre.txt
```

#### R2: Custom sat4j Builds Sem Fonte

**Descrição:** A change menciona "CUSTOM v20100705" para sat4j.core e sat4j.pb, mas não há código fonte disponível.

**Risco:** Se o build Maven do sat4j não produzir JAR idêntico, solvers podem ter comportamento diferente.

**Recomendação:** Documentar origem do JAR custom e verificar se é reprodutível.

#### R3: --add-opens/--add-exports Incompletos

**Descrição:** tasks.md lista apenas 3 flags:
- `--add-opens java.base/java.lang=ALL-UNNAMED`
- `--add-opens java.base/java.util=ALL-UNNAMED`
- `--add-exports java.base/jdk.internal.misc=ALL-UNNAMED`

**Risco:** JPF usa reflection intensivamente e pode precisar de mais flags, causando `IllegalAccessError` em runtime.

**Recomendação:** Começar com lista expansiva e reducir empiricamente após ver erros.

#### R4: 154 .jpf Files - Padrões Não-Uniformes

**Descrição:** Task 4.6 menciona "non-standard paths" mas não quantifica quantos arquivos têm caminhos absolutos ou não-padrão.

**Risco:** .jpf files com caminhos absolutos quebrarão em outras máquinas.

**Recomendação:** Auditoria prévia:
```bash
grep -rE 'native_classpath=.*/[a-z]+/[a-z]+' src/tests/ src/examples/
grep -rE '^classpath=/' src/tests/ src/examples/
```

#### R5: Dependências Transitivas do jpf-core

**Descrição:** jpf-core tem suas próprias dependências (BCEL, etc.) que serão resolvidas via Maven.

**Risco:** Conflitos de versão entre dependências do jpf-core e jpf-symbc.

**Recomendação:** Executar `mvn dependency:tree` após Phase 1 para identificar conflitos.

#### R6: opt4j 3.3 API Changes

**Descrição:** Task 0.5 menciona auditoria de compatibilidade opt4j 3.3, mas não detalha escopo.

**Risco:** Coral solver pode ter código incompatível com opt4j 3.3 API, causando falhas de compilação ou runtime.

**Recomendação:** Compilar classes específicas do Coral (ProblemCoral, etc.) com opt4j 3.3 ANTES de commitar a migration.

#### R7: Perda de Conhecimento Tácito

**Descrição:** Ant build.xml pode conter comentários/documentação de decisões de build que serão perdidas.

**Risco:** Decisões de configuração não documentadas podem ser revertidas acidentalmente.

**Recomendação:** Preservar build.xml em docs/build-archive/ em vez de excluir permanentemente.

---

## 4. SUGESTÕES

### 4.1 Correções Imediatas (S1-S5)

| # | Sugestão | Arquivo | Impacto |
|---|----------|---------|---------|
| S1 | Adicionar `**/TestBitwise*` e `**/TestLazy*` às exclusões do Surefire | specs/build/spec.md | Alto - evita testes quebrando |
| S2 | Documentar que INV-BLD-03 mudou semanticamente | specs/build/spec.md | Médio - documentação |
| S3 | Adicionar SHA-256 comparison dos 28 JARs pré-migração | tasks.md | Alto - previne surpresas |
| S4 | Incluir `mvn dependency:tree` como task de verificação | tasks.md | Médio - identifica conflitos |
| S5 | Documentar rollback steps específicos | design.md ou tasks.md | Alto - recuperação |

### 4.2 Melhorias de Process

| # | Sugestão | Justificativa |
|---|----------|---------------|
| S6 | Executar `mvn enforcer:enforce` | Checar dependências conflitadas |
| S7 | Criar "mini-migration" com 1-2 arquivos | Validar script de automação |
| S8 | Testar com JDK 8, 11, 17 | Forward-compat guarantee |
| S9 | Adicionar `mvn jdeps` | Detectar APIs JDK removidas |

### 4.3 Preocupação Arquitetural

**A change é INFRAESTRUTURAL. Isso é bom?**

**Prós:**
- Baixa probabilidade de quebrar funcionalidade de symbolic execution
- Usuários finais não percebem mudança (se funcionar)
- Mantém comportamento existente

**Contras:**
- Se falhar, não há como usar jpf-symbc
- Testes existentes são a única verificação de correção

**Recomendação:** Considerar manter capacidade dual-build (Ant + Maven) temporariamente durante transição.

---

## 5. RESUMO DE AVALIAÇÃO

| Dimensão | Avaliação | Notas |
|----------|-----------|-------|
| **Documentação** | ★★★★★ | Proposal, design, specs, tasks excepcionais |
| **Rastreabilidade** | ★★★★★ | FR → Impl → Test completa |
| **Riscos Identificados** | ★★★★☆ | Bons, mas faltam 7 |
| **Mitigações** | ★★★★☆ | Fortes, especialmente opt4j |
| **Invariants** | ★★★☆☆ | 2 inconsistências críticas |
| **Test Coverage** | ★★★☆☆ | Fraco para mudança tão crítica |

**Veredicto Final:** Change bem preparada que demonstra excelente prática de documentação e gestão de riscos. As principais preocupações são as inconsistências nas exclusões de teste (S1) e a falta de verificação de checksum de JARs (S3). Recomenda-se aplicar correções S1-S5 antes de executar as tasks.

---

## 6. CHECKLIST PRÉ-EXECUÇÃO

- [ ] Aplicar correção S1 (exclusões de teste)
- [ ] Aplicar correção S2 (documentar mudança INV-BLD-03)
- [ ] Executar SHA-256 dos JARs (S3)
- [ ] Adicionar task dependency:tree (S4)
- [ ] Documentar rollback steps (S5)
- [ ] Executar auditoria de .jpf files (R4)
- [ ] Testar opt4j 3.3 com Coral ANTES de migrar (R6)
- [ ] Verificar PathConditionsReliability (task 6.3)

---

*Relatório gerado em 02 de Março de 2026*
