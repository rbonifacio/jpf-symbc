# Relatório de Validação Rigorosa da Change `migration-maven-java11`

## Escopo e abordagem

Este relatório valida, de forma minuciosa, a change em:

- `openspec/changes/migration-maven-java11/`

Arquivos analisados:

- `proposal.md`
- `design.md`
- `tasks.md`
- `specs/build/spec.md`
- `specs/dependencies/spec.md`
- `specs/configuration/spec.md`

Validação cruzada realizada contra:

- `docs/PRD.md`
- `openspec/specs/build/spec.md`
- `openspec/specs/dependencies/spec.md`
- `openspec/specs/configuration/spec.md`
- `build.xml`
- `jpf.properties`
- estado real de `src/` e `lib/`

## Resultado executivo

A change está tecnicamente ambiciosa, bem estruturada e com boa cobertura de riscos reais (Java 11/module system, jpf-core oficial, opt4j). Entretanto, **há inconsistências internas relevantes** (contagens, critérios de aceite, links, e invariantes) que reduzem confiabilidade operacional da execução.

Conclusão: **aprovável com ressalvas**, desde que os itens de severidade alta sejam corrigidos antes da implementação.

## Pontos fortes

- Estrutura de migração por fases (0→4) coerente e pragmaticamente defensável.
- Boa identificação de riscos críticos reais:
  - incompatibilidade com jpf-core oficial
  - `--patch-module` para classes em `java.*`
  - bloqueio do Coral por `opt4j-2.4`
- Excelente preocupação com verificação pós-migração:
  - validação de paths `.jpf`
  - comparação de conteúdo de JARs
  - smoke test de bibliotecas nativas
- Preserva semântica funcional (foco em infraestrutura/build, não em engine simbólica).

## Achados (priorizados por severidade)

## Alta severidade

1. Inconsistência numérica de dependências (8/20 vs 10/18)
- Evidência:
  - `proposal.md` define 8 Central + 20 local (`openspec/changes/migration-maven-java11/proposal.md:13-14`)
  - o mesmo arquivo depois afirma 10 Central + 18 local (`openspec/changes/migration-maven-java11/proposal.md:47-48`)
  - `design.md` também alterna entre 18 e 20 locais (`openspec/changes/migration-maven-java11/design.md:40`, `:82`, `:105`, `:158`, `:202`)
- Risco:
  - planejamento de POM/repositório local inconsistente
  - possível quebra de rastreabilidade FR05/FR06
- Recomendação:
  - fixar uma única verdade (ideal: tabela canônica única de 28 artefatos com origem Central/local e coordenadas finais)

2. Critérios de build/teste potencialmente incorretos para módulos Maven
- Evidência:
  - requirement afirma que todos os módulos compilam para `target/classes` (`specs/build/spec.md:38`), mas módulo de testes naturalmente usa `target/test-classes`
  - requirement afirma 5 JARs “um por módulo” (`specs/build/spec.md:44`), conflitando com PRD que descreve testes/exemplos como classes e não artefatos (`docs/PRD.md:95-102`)
- Risco:
  - falso negativo/falso positivo em aceitação
  - expectativas erradas no pipeline de validação
- Recomendação:
  - explicitar artefatos por módulo (quais geram JAR e quais não geram/geram opcionalmente)
  - separar critérios de `compile` e `package` por tipo de módulo

3. Links de referência quebrados no design
- Evidência:
  - `design.md` referencia `[PRD](../../docs/PRD.md)` e specs em `../../openspec/specs/...` (`openspec/changes/migration-maven-java11/design.md:13`)
  - esses caminhos não resolvem para os arquivos reais no workspace
- Risco:
  - quebra de auditabilidade e revisão colaborativa
- Recomendação:
  - corrigir para caminhos relativos válidos a partir de `openspec/changes/migration-maven-java11/`

## Média severidade

4. Contagem de bibliotecas nativas está superestimada no texto
- Evidência:
  - docs afirmam “34+” nativas em `lib/` root + `64bit/` (`design.md:41`, `specs/dependencies/spec.md:7`, `:95`, `tasks.md:93`, `:105`)
  - estado real: 30 arquivos nativos no total (`find lib -type f \( -name '*.so' -o -name '*.dll' -o -name '*.dylib' \)`)
- Risco:
  - verificação final baseada em threshold incorreto
- Recomendação:
  - capturar baseline automaticamente na fase 0 (antes/depois) em vez de número hardcoded

5. Invariante INV-CFG-11 semanticamente inválido/ambíguo
- Evidência:
  - aparece em “ADDED Invariants”, mas com texto “~~REMOVED~~” (`specs/configuration/spec.md:19`)
- Risco:
  - ambiguidade normativa no processo de aprovação
- Recomendação:
  - remover INV-CFG-11 da seção “ADDED” e registrar apenas em “REMOVED” (ou criar novo ID afirmativo claro)

6. Estratégia de classpath de runtime contraditória
- Evidência:
  - `design.md` runtime inclui solver jars em `repo/**/*.jar` e também `lib/*.jar` (`design.md:239-240`)
  - `tasks.md` manda remover `.jar` de `lib/` (`tasks.md:93`)
- Risco:
  - configuração final pode referenciar caminhos inexistentes
- Recomendação:
  - definir política única: runtime vai consumir solver JARs de `repo/` exclusivamente (ou política híbrida explicitada por fase)

7. Regras de exclusão de testes não preservam 100% do legado Ant
- Evidência:
  - Ant exclui `**/Test*$*.class` (`build.xml:265`)
  - spec de build não inclui equivalente explícito (`specs/build/spec.md:67-79`)
- Risco:
  - possível execução de classes internas/auxiliares em surefire dependendo da convenção de includes/excludes
- Recomendação:
  - adicionar exclusão equivalente no requirement FR10

## Baixa severidade

8. Não-goal conflita com exceção do opt4j
- Evidência:
  - “não atualizar versões de solver” (`design.md:136`)
  - porém opt4j deve subir para 3.3 (`design.md:270`, `specs/dependencies/spec.md:19-20`)
- Risco:
  - ruído de governança/review
- Recomendação:
  - ajustar non-goal para: “sem upgrades, exceto opt4j por blocker Java 11”

9. Comandos de verificação podem gerar interpretação errada
- Evidência:
  - checks com `grep -rL 'target/' .../*.jpf` em texto de spec (`specs/configuration/spec.md:59-60`) são frágeis quando usados literalmente
- Risco:
  - falsas falhas operacionais por comando mal-formado em shell/CI
- Recomendação:
  - substituir por comandos robustos (ex.: `find ... -name '*.jpf' -print0 | xargs -0 grep -L 'target/'`)

## Riscos técnicos principais (validados)

1. API drift com jpf-core oficial
- Severidade: alta
- Situação: corretamente identificado e com mitigação em fases 0/3.

2. `--patch-module` em Java 11
- Severidade: alta
- Situação: desenho técnico sólido; precisa apenas critérios de aceite mais precisos por módulo.

3. Coral/opt4j
- Severidade: alta
- Situação: blocker corretamente identificado; decisão de upgrade está coerente com risco.

4. Migração massiva de paths `.jpf`
- Severidade: média-alta
- Situação: abordagem automática + pós-verificação é adequada; faltam pequenos ajustes de robustez nos comandos.

## Sugestões objetivas de melhoria (ordem recomendada)

1. Criar uma única tabela canônica de dependências (28 itens)
- Campos: jar atual, destino (Central/local), coordenadas, motivo.

2. Corrigir critérios de aceite de build por módulo
- Distinguir `target/classes` vs `target/test-classes`.
- Definir explicitamente quais módulos devem gerar JAR.

3. Corrigir links quebrados do `design.md`
- Garantir navegação para PRD e specs base.

4. Normalizar números e métricas
- Substituir “34+” por baseline capturado automaticamente na fase 0.

5. Limpar inconsistências normativas
- Resolver INV-CFG-11.
- Ajustar non-goal para exceção explícita do opt4j.

6. Fechar lacuna de exclusões de teste
- Incluir regra equivalente a `Test*$*` no surefire.

## Julgamento final

A change demonstra maturidade de engenharia e cobre riscos reais de migração. O material está próximo de um padrão muito alto, mas ainda há inconsistências documentais e de critérios de aceite que podem induzir erro de execução.

Status recomendado:

- **Go condicional** para implementação após correções dos 3 itens de alta severidade.
- Sem essas correções, risco de retrabalho e validação inconclusiva permanece significativo.

