# Análise Técnica Rigorosa — Change `gh1-migration-maven-java11`

## 1. Escopo e método

Esta análise cobre, com foco de revisão técnica profunda, os artefatos da change:

- `openspec/changes/gh1-migration-maven-java11/proposal.md`
- `openspec/changes/gh1-migration-maven-java11/design.md`
- `openspec/changes/gh1-migration-maven-java11/tasks.md`
- `openspec/changes/gh1-migration-maven-java11/specs/build/spec.md`
- `openspec/changes/gh1-migration-maven-java11/specs/configuration/spec.md`
- `openspec/changes/gh1-migration-maven-java11/specs/dependencies/spec.md`

Referências normativas usadas para validação:

- `docs/SDD.md`
- `docs/skills-agents-architecture.md`
- `.sdd/docs/SDD-WORKFLOW.md`
- `docs/PRD.md`
- specs atuais em `openspec/specs/{build,configuration,dependencies}/spec.md`

Também foi feita validação factual contra o estado real do repositório (contagens de arquivos, padrões de teste no `build.xml`, conteúdo do `jpf.properties`, etc.).

---

## 2. Resultado executivo

A change é **tecnicamente forte e madura em planejamento**, com boa rastreabilidade e mitigação explícita de riscos críticos (JNI, opt4j/Coral, divergência de API, patch-module).

Entretanto, há **inconsistências importantes** que, se não corrigidas antes da execução, podem comprometer os critérios de aceite e gerar falsos sinais de sucesso/falha.

Classificação geral:

- Qualidade de estrutura SDD: **Alta**
- Coerência interna: **Média**
- Executabilidade segura sem ajustes: **Média-Baixa**

---

## 3. Pontos fortes

### 3.1 Planejamento por fases com gates reais de risco

A divisão em fases (0→4) com go/no-go explícito é um dos melhores aspectos do pacote. Isso reduz risco de custo afundado.

- Evidências: `design.md` (seções de fases), `tasks.md` Grupo 0.

### 3.2 Cobertura de riscos técnicos realmente relevantes

A change não ignora riscos difíceis: JNI em JDK 11, incompatibilidade de API com jpf-core oficial, integração ClassLoader+modules, dependência indireta Coral→opt4j.

- Evidências: `proposal.md` (risk areas), `design.md` (Risks/Trade-offs), `tasks.md` 0.3b, 0.4, 0.5/0.5b, 5.7, 6.6.

### 3.3 Rastreabilidade requisito→implementação→verificação

A tabela de mapeamento em `design.md` é sólida e útil para auditoria e execução incremental.

- Evidência: `design.md` seção “Mapping: Spec → Implementation → Test”.

### 3.4 Profundidade operacional acima da média

O nível de detalhamento em tarefas (incluindo verificação de exclusões do Ant, contagem de classes, smoke tests por solver) é alto e pragmaticamente valioso.

---

## 4. Achados críticos e altos (com evidências)

## 4.1 [CRÍTICO] Comando de teste runtime (5.7) inconsistente com o modelo de execução do JPF

**Problema**
A tarefa 5.7 propõe:

```bash
java ... -jar jpf-symbc-main/target/jpf-symbc-main-1.0.0-SNAPSHOT.jar src/examples/demo/NumericExample.jpf
```

Esse comando pressupõe que o JAR `jpf-symbc-main` seja um launcher executável para JPF, o que não está comprovado na especificação nem no histórico de execução (que normalmente passa por `RunJPF`/classpath do jpf-core).

**Risco**
Gate crítico (ClassLoader + module system) pode falhar por comando errado, não por defeito real da migração.

**Evidências**

- `tasks.md` item 5.7
- `docs/pre-plan.md` mostra referência separada a RunJPF em comentário

**Recomendação**
Definir comando canônico de runtime com `gov.nasa.jpf.tool.RunJPF` (ou launcher oficial equivalente do jpf-core publicado localmente), e explicitar o classpath correto.

---

## 4.2 [CRÍTICO] Conflito entre NFR04 (equivalência de artefatos) e breaking change INV-BLD-03

**Problema**
O PRD exige que os 3 JARs tenham “as mesmas classes” após migração (NFR04). A própria change introduz separação de anotações (classes JAR deixa de conter annotations), assumida como breaking change.

**Risco**
Critério de aceite fica logicamente contraditório: ao mesmo tempo “deve ser igual” e “intencionalmente não será igual”.

**Evidências**

- `docs/PRD.md` NFR04
- `openspec/changes/.../specs/build/spec.md` INV-BLD-03
- `design.md` seção Breaking Change INV-BLD-03

**Recomendação**
Reescrever NFR04 para “equivalência funcional de capacidade de execução”, com regra explícita para separação de annotations em artefato dedicado.

---

## 4.3 [ALTO] Baseline de bibliotecas nativas está incorretamente conectado

**Problema**
A tarefa 8.6 manda validar preservação de nativos comparando com “baseline da 0.6”, porém 0.6 gera apenas SHA-256 de JARs (`lib/*.jar`).

**Risco**
Não existe baseline real para `.so/.dll/.dylib`; validação 8.6 fica inválida.

**Evidências**

- `tasks.md` 0.6
- `tasks.md` 8.6

**Recomendação**
Adicionar tarefa de baseline para nativos (ex.: `find lib -type f \( -name '*.so' -o -name '*.dll' -o -name '*.dylib' \) | sort > docs/native-libs-pre-migration.txt`).

---

## 4.4 [ALTO] Método de validação opt4j 3.3 vs Coral não prova integração real

**Problema**
O plano de 0.5 usa compilação pontual de `ProblemCoral.java` com classpath ad hoc. Isso não valida comportamento runtime real de `coral.jar` + opt4j (especialmente proxies/reflection).

**Risco**
Falso positivo de compatibilidade; quebra tardia em execução real.

**Evidências**

- `tasks.md` 0.5 e 0.5b
- `design.md` risco opt4j/Coral (bem descrito, mitigação de teste ainda frágil)

**Recomendação**
Trocar critério principal por smoke test E2E coral com `.jpf` representativo e aceitação observável (solver retorna solução sem `ClassFormatError`/`NoSuchMethodError`/`ClassNotFoundException`).

---

## 4.5 [ALTO] Inconsistência de semântica de outputs (3 JARs legados vs 5 módulos/JARs)

**Problema**
Partes da documentação base e PRD ainda ancoram em 3 JARs; a change opera com 5 módulos e validações de packaging mais amplas.

**Risco**
Ambiguidade no “done”: o que exatamente precisa existir no final e com qual compatibilidade?

**Evidências**

- `docs/PRD.md` (3 JARs legados / módulos de teste+example sem foco de artefato)
- `change specs build` (5 JARs por módulo)
- `tasks.md` 8.3

**Recomendação**
Fixar contrato final único (artefatos produzidos, quais são runtime-critical, quais são apenas auxiliares).

---

## 5. Achados médios

## 5.1 [MÉDIO] Ambiguidade `repo/` vs `lib/` na configuração final

Há trechos afirmando solver jars em `repo/` e outros aceitando `repo/` ou `lib/`. A fase final também exige ausência de solver jars em `lib/`.

- Evidências: `specs/configuration/spec.md` INV-CFG-06, `tasks.md` 8.8.
- Recomendação: consolidar uma regra única: solver jars exclusivamente `repo/`/Maven; `lib/` somente nativos.

## 5.2 [MÉDIO] Uso de wildcard recursivo (`repo/**/*.jar`) sem validação de suporte

Sem prova de expansão no contexto de resolução de classpath do JPF/propriedades.

- Evidência: `design.md` Runtime Classpath Flow.
- Recomendação: enumerar caminhos explícitos ou validar parser alvo com teste dedicado.

## 5.3 [MÉDIO] Decisão de mover `doc/Example.jpf` não está bem fechada

Arquivo aparenta ser material de documentação (classpath comentado), mas tasks tratam como candidato à realocação funcional.

- Evidências: `doc/Example.jpf`, `tasks.md` 3.12/4.3.
- Recomendação: classificar formalmente como “doc-only” (manter no `doc/`) ou “executável” (mover + atualizar).

## 5.4 [MÉDIO] Acoplamento forte à máquina local nas tarefas

Há paths absolutos e versões exatas de SDKMAN hardcoded, o que reduz portabilidade operacional.

- Evidências: `tasks.md` 0.1, `design.md` seção de ambiente.
- Recomendação: usar variáveis e placeholders (`$WORKSPACE`, `$JPF_CORE_PATH`) + script de bootstrap.

---

## 6. Validação factual contra repositório atual

Checagens executadas localmente confirmaram a maior parte das premissas quantitativas:

- Java files: **765**
- `.jpf` files totais: **154**
  - tests: **34**
  - examples: **118**
  - src/main: **1**
  - doc: **1**
- `lib/*.jar`: **28**

Também confirmado:

- `jpf.properties` contém referência a `PathConditionsReliability-0.0.1.jar` ausente.
- `build.xml` possui exclusão `**/Test*$*.class` (classe interna), importante para paridade Surefire.
- Existem usos reais de `symbolic.dp=coral` em testes/exemplos, aumentando criticidade de resolver opt4j/Coral corretamente.

Observação de consistência:

- A documentação da change menciona “34+ nativos em `lib/` root”; no estado atual observado há 28 nativos na raiz + 6 em `lib/64bit` (34 no total).

---

## 7. Riscos residuais relevantes

1. **Runtime falso-negativo/falso-positivo** por comando de execução incorreto no gate de módulos.
2. **Aceite travado por conflito de requisitos** (equivalência rígida vs breaking change de empacotamento).
3. **Compatibilidade Coral não comprovada** com método de teste atual.
4. **Regressão silenciosa de configuração** caso wildcard/path rule não funcione conforme assumido.
5. **Perda de rastreabilidade de nativos** sem baseline dedicado.

---

## 8. Recomendações priorizadas (ação imediata)

## P0 (antes de iniciar implementação)

1. Corrigir 5.7 com comando canônico de execução JPF (launcher/classpath corretos).
2. Resolver formalmente o conflito NFR04 × INV-BLD-03.
3. Adicionar baseline de nativos separado do baseline de JARs.

## P1 (durante fase 0)

4. Substituir validação principal de opt4j por smoke E2E coral real.
5. Fechar decisão sobre `doc/Example.jpf` (doc-only vs executável).

## P2 (antes da verificação final)

6. Eliminar ambiguidade `repo/` vs `lib/` no estado final.
7. Remover dependência de wildcard recursivo sem prova de suporte.
8. Reduzir acoplamento de paths absolutos para facilitar reexecução.

---

## 9. Conclusão

A change demonstra **alto nível de preparo técnico** e é, no geral, uma base forte para uma migração complexa. O principal risco não está em falta de análise, mas em **alguns pontos de inconsistência de contrato e validação operacional**.

Com os ajustes P0/P1 acima, a execução tende a ficar significativamente mais segura, auditável e reprodutível.

