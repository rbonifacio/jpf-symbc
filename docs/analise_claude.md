# Validacao Rigorosa: Change gh1-migration-maven-java11

**Avaliacao detalhada de conformidade, completude e riscos**

Data: 2026-03-03
Revisor: Claude Opus 4.6
Artefatos analisados: proposal.md, 3 delta specs, design.md, tasks.md
Documentos de referencia: PRD, SDD.md, SDD-WORKFLOW.md, skills-agents-architecture.md, specs existentes (build, dependencies, configuration), verification-findings.md

---

## Sumario Executivo

A change `gh1-migration-maven-java11` e um trabalho de alta qualidade que demonstra rigor excepcional na preparacao de uma migracao complexa. Os 4 artefatos estao completos, internamente consistentes, e refletem multiplas rodadas de revisao (incluindo cross-LLM review). A Phase 0 expandida com 10 subtasks de validacao de risco e o plano de rollback por fase sao particularmente fortes.

No entanto, a analise profunda revela **12 pontos de atencao** (3 riscos altos, 5 medios, 4 baixos) que merecem consideracao antes da implementacao.

**Nota geral: 8.5/10** — Excelente para artefatos de planejamento; as lacunas identificadas sao tipicas de pre-implementacao e podem ser resolvidas durante Phase 0.

---

## 1. Analise de Conformidade SDD

### 1.1 Conformidade com o Workflow SDD Full

| Criterio | Status | Evidencia |
|----------|--------|-----------|
| Schema correto (`sdd-full`) | OK | `.openspec.yaml: schema: sdd-full` |
| Proposal completo (Why/What/Impact) | OK | Secoes Why, What Changes, Capabilities, Impact presentes |
| Delta specs por dominio | OK | 3 specs (build, dependencies, configuration) — mesmos dominios das specs existentes |
| Design com decisoes justificadas | OK | 6 decisoes (D1-D6) com rationale e alternativas consideradas |
| Tasks ordenado com verificacoes | OK | 9 grupos (0-8), 50+ subtasks com comandos concretos e criterios de aceitacao |
| Subagent dispatch hints | OK | Comentario HTML no topo de tasks.md com critical path e parallelismo |
| Vinculo com GitHub Issue | OK | `gh1-` prefix vinculado ao Issue #1 |

**Conformidade com principios SDD:**

| Principio | Avaliacao |
|-----------|-----------|
| P1: Specification as Foundation | Forte — specs delta documentam MODIFIED/ADDED/REMOVED com rastreabilidade INV-XX-NN |
| P2: Intent over Implementation | Balanceado — comandos concretos em tasks sao necessarios para esta migracao |
| P3: Human-in-the-Loop | Task 0.10 (go/no-go) e checkpoints por fase |
| P4: Proportional Ceremony | Adequado — Full SDD justificado para migracao multi-modulo com decisoes arquiteturais |

### 1.2 Rastreabilidade PRD → Specs → Design → Tasks

| FR/NFR | Delta Spec | Design Section | Task(s) | Veredicto |
|--------|-----------|----------------|---------|-----------|
| FR01 (Maven multi-module) | build/spec INV-BLD-12 | Architecture, D1 | 2.1, 5.1, 8.1 | Completo |
| FR02 (5 modulos) | build/spec INV-BLD-01..04 | Architecture | 2.2-2.7, 3.1-3.13 | Completo |
| FR03 (Java 11) | build/spec INV-BLD-01 | D5 | 5.2, 5.6 | Completo |
| FR04 (--patch-module) | build/spec INV-BLD-09..11 | D4 | 5.3, 5.6 | Completo |
| FR05 (repo/ local) | deps/spec INV-DEP-08..09 | D2 | 1.1-1.3 | Completo |
| FR06 (Maven Central deps) | deps/spec INV-DEP-10 | Mapping table | 1.4 | Completo |
| FR07 (.jpf paths) | config/spec INV-CFG-10 | Data Flow | 4.1-4.6 | Completo |
| FR08 (jpf.properties) | config/spec INV-CFG-06..07 | Data Flow | 6.2 | Completo |
| FR09 (Surefire config) | build/spec Test Execution | Testing Strategy | 2.5, 5.4 | Completo |
| FR10 (exclusions) | build/spec exclusion list | Testing Strategy | 2.5, 6.4b | Completo |
| FR11 (official jpf-core) | deps/spec INV-DEP-11 | D6 | 0.2, 6.1 | Completo |
| FR12 (remove build artifacts) | build/spec REMOVED | Cleanup | 7.1-7.3 | Completo |
| FR13 (update docs) | - | Goals | 7.5-7.6 | Completo |
| NFR01 (solvers functional) | deps/spec Solver Availability | Per-Solver Smoke Table | 6.6, 8.9 | Completo |
| NFR02 (native libs) | deps/spec Native Loading | - | 0.3, 8.6 | Completo |
| NFR03 (.jpf semantics) | config/spec Purpose | - | 4.4-4.5 | Completo |
| NFR04 (same classes) | - | Testing Strategy | 8.5 | Completo |
| NFR05 (tests pass) | build/spec Test Execution | Quantitative Criteria | 6.4, 8.2 | Completo |
| NFR06 (mvn commands) | - | Goals | 8.1-8.3 | Completo |
| NFR07 (phased) | - | D5, Data Flow | Phase structure | Completo |

**Resultado**: 13/13 FRs e 7/7 NFRs com rastreabilidade completa. Nenhum requisito orfao.

---

## 2. Pontos Fortes

### 2.1 Phase 0 Expandida (Validacao de Risco)

A Phase 0 com 10 subtasks e o aspecto mais forte da change. Ela aborda sistematicamente os riscos antes de qualquer investimento de implementacao:

- **0.3 + 0.3b**: Smoke test + E2E Z3 (nao apenas `loadLibrary`, mas execucao real via JPF)
- **0.4**: Audit compreensivo de divergencia de API (2275+ imports, nao apenas 3 classes)
- **0.5 + 0.5b**: Investigacao indireta de opt4j via coral.jar (cadeia de dependencia correta)
- **0.6 + 0.7**: SHA-256 baseline e verificacao SAT4J (rigor na rastreabilidade de JARs)
- **0.8**: PathConditionsReliability como dead reference (investigacao antes de acao)
- **0.10**: Documentacao go/no-go explicita com criterios quantitativos

Isso demonstra maturidade no planejamento — erros descobertos na Phase 0 custam ordens de magnitude menos que na Phase 3.

### 2.2 Decisoes Arquiteturais Bem Justificadas

Cada decisao (D1-D6) inclui:
- Choice explicito
- Rationale fundamentado
- Alternativas consideradas e rejeitadas com motivo

Destaque para D2 (repo/ local) que evita tanto `<systemPath>` (deprecated) quanto infraestrutura externa (Nexus/Artifactory), escolhendo a opcao mais pragmatica para um projeto de pesquisa.

### 2.3 Tratamento do opt4j BLOCKER

A cadeia de dependencia indireta (`ProblemCoral → coral.jar → opt4j → Guice → ASM 1.5.3`) foi identificada corretamente como BLOCKER. O design:
- Documenta a cadeia completa
- Especifica version bounds (3.3 sim, 3.4+ nao — requer Java 21)
- Define criteria de go/no-go (se coral.jar for incompativel, Coral fica unsupported)
- Tasks 0.5/0.5b verificam contra coral.jar, nao apenas jpf-symbc source

### 2.4 Invariantes Precisos com Rastreabilidade

Os delta specs usam nomenclatura sistematica (INV-BLD-xx, INV-DEP-xx, INV-CFG-xx) com classificacao MODIFIED/ADDED/REMOVED. Isso permite:
- Verificacao automatizada pos-implementacao
- Diff claro entre estado anterior e posterior
- Referencia cruzada entre specs, design, e tasks

### 2.5 Rollback Plan por Fase

O rollback plan nao e generico — tem triggers e acoes especificas por fase:
- Phase 0: abort com criterios quantitativos (>50 breaking changes)
- Phase 1: debug seguro (sem mudancas de codigo ainda)
- Phase 2: checkpoint de Phase 1
- Phase 3: threshold de 20% test failures

### 2.6 Rigor nas Correcoes Pre-Implementacao

O `verification-findings.md` documenta correcoes ja aplicadas:
- `jpf-symbc.sourcepath` fabricado → removido
- .jpf count ajustado (152→154)
- commons-lang/commons-math groupIds corrigidos
- SAT4J classificado como CUSTOM build
- Task 7.3 explicitamente preserva native libs

---

## 3. Riscos e Pontos Fracos

### 3.1 RISCO ALTO: Task 5.7 — Comando de Runtime Test Provavelmente Incorreto

**Severidade**: Alta
**Impacto**: Task 5.7 pode falhar por razoes irrelevantes, desperdicando tempo de debugging

O comando em 5.7 usa `-jar jpf-symbc-main/target/jpf-symbc-main-1.0.0-SNAPSHOT.jar` para executar JPF. Isso tem problemas:

1. **JPF nao e executado assim** — JPF e executado via `gov.nasa.jpf.tool.RunJPF` com o classpath completo. O `-jar` flag ignora o `-cp` flag e usa apenas o `Main-Class` do MANIFEST.MF, que nao existe no JAR do jpf-symbc-main.

2. **Classpath incompleto** — Apos a migracao Maven, o classpath precisa incluir: jpf-core (de `~/.m2`), jpf-symbc-main, jpf-symbc-classes, jpf-symbc-annotations, solver JARs (de `repo/`), native libs. O comando nao monta esse classpath.

3. **O .jpf file referenciado (`src/examples/demo/NumericExample.jpf`)** ja tera sido movido para `jpf-symbc-examples/src/main/resources/` pelo task 3.11, entao o path esta incorreto.

**Sugestao**: O comando deve ser algo como:
```bash
mvn exec:java -pl jpf-symbc-tests \
  -Dexec.mainClass=gov.nasa.jpf.tool.RunJPF \
  -Dexec.args="jpf-symbc-examples/src/main/resources/demo/NumericExample.jpf" \
  -Djava.library.path=lib:lib/64bit
```
Ou montar o classpath manualmente com `mvn dependency:build-classpath`.

### 3.2 RISCO ALTO: jpf.properties native_classpath com Paths repo/

**Severidade**: Alta
**Impacto**: JPF pode nao encontrar solver JARs em runtime

O design (Data Flow section) indica que `jpf-symbc.native_classpath` deve incluir `repo/**/*.jar`. Porem:

1. **JPF nao suporta wildcards `**`** — `jpf.properties` usa `;` como separador de paths e cada JAR precisa ser listado individualmente com path completo relativo a `${jpf-symbc}`.

2. **20 JARs no repo/ = 20 entradas manuais** no `jpf.properties`. O design menciona isso mas nao especifica o formato exato. Task 6.2 diz "Maven artifact paths" mas o repo/ segue layout Maven (e.g., `repo/com/microsoft/z3/4.8.14/z3-4.8.14.jar`), cada um com path diferente.

3. **Risk de drift** — Se um JAR for adicionado/removido do repo/, `jpf.properties` precisa ser atualizado manualmente.

**Sugestao**: Adicionar sub-task em 6.2 que gera as entradas de `native_classpath` automaticamente via:
```bash
find repo/ -name "*.jar" | sort | sed 's|^|${jpf-symbc}/|' | paste -sd';'
```
E documentar que qualquer mudanca no repo/ requer atualizacao do `jpf.properties`.

### 3.3 RISCO ALTO: Ausencia de Teste de Regressao do Ant Baseline

**Severidade**: Alta
**Impacto**: Sem baseline quantitativo confiavel para comparacao pos-migracao

Task 0.1 captura o output do `ant test` em `docs/ant-test-baseline.txt`. Porem:

1. **`ant test` requer `JUNIT_HOME`** e `../jpf-core` ja construido. Se alguma dessas pre-condicoes falhar, o baseline ficara incompleto ou vazio.

2. **Muitos testes do jpf-symbc falham HOJE** (pre-migracao) por dependencias de solvers nao instalados, native libs ausentes, etc. O baseline precisa distinguir entre "testes que falham por design/exclusao" e "testes que realmente passam".

3. **Task 8.2 compara com o baseline** ("same pass/fail/skip counts as Ant `ant test`"), mas se o baseline tiver testes que falham por ambiente, a comparacao sera enganosa.

**Sugestao**: Task 0.1 deve:
- Parsear o output do ant test para extrair counts exatos (pass/fail/skip/error)
- Salvar em formato estruturado (e.g., `docs/ant-test-baseline-counts.txt`)
- Documentar quais testes falham e por que (solver ausente, native lib, etc.)
- Definir o set exato de testes que DEVEM passar pos-migracao

### 3.4 RISCO MEDIO: Ausencia de Tratamento para `JPF_*.java` Peers

**Severidade**: Media
**Impacto**: Peers podem ter conflitos de classpath com jpf-core peers

Task 3.4 faz merge de `src/peers/*` → `jpf-symbc-main/src/main/java/`. O design diz "no namespace conflicts verified". Porem:

1. **Peers no JPF tem convencao de naming**: `JPF_<classname>.java` mapeia para `<classname>` via reflection. Quando jpf-core e jpf-symbc estao no mesmo classpath, ambos podem ter peers para a mesma classe.

2. **O merge para jpf-symbc-main e correto** (e o que o Ant ja faz — `build/jpf-symbc.jar` inclui peers). Mas a transicao para official jpf-core pode introduzir novos conflitos se o jpf-core oficial adicionou peers que nao existiam no fork.

3. **Task 0.4 (API divergence) nao menciona peers explicitamente** — apenas imports gerais.

**Sugestao**: Em task 0.4, alem da analise de imports, verificar:
```bash
# Listar peers em jpf-symbc
ls src/peers/
# Listar peers em jpf-core oficial
ls /tmp/jpf-core-official/src/peers/ | diff - <(ls src/peers/)
```

### 3.5 RISCO MEDIO: .jpf Files com `sourcepath` Incorreto Apos Migracao

**Severidade**: Media
**Impacto**: Debugging de symbolic execution pode quebrar (sourcepath e usado para exibir codigo-fonte)

Tasks 4.1-4.2 atualizam `build/tests` → `jpf-symbc-tests/target/test-classes` e similares. Porem `sourcepath` tambem precisa ser atualizado:

- `sourcepath=${jpf-symbc}/src/tests` → `sourcepath=${jpf-symbc}/jpf-symbc-tests/src/test/java`
- `sourcepath=${jpf-symbc}/src/examples` → `sourcepath=${jpf-symbc}/jpf-symbc-examples/src/main/java`

Tasks 4.1-4.2 mencionam ambos os patterns (`build/tests` e `src/tests`), o que esta correto. Mas o `sed` script nao esta especificado em detalhe, e ha risco de patterns parciais.

Alem disso, **nenhum task verifica que `sourcepath` foi atualizado corretamente**. Tasks 4.4-4.5 verificam apenas `build/tests` e `build/examples` (output dirs), nao `src/tests` e `src/examples` (source dirs).

**Sugestao**: Adicionar verificacao em 4.4:
```bash
# Verificar que NENHUM .jpf ainda referencia src/tests ou src/examples
grep -rl 'src/tests\|src/examples' jpf-symbc-tests/ jpf-symbc-examples/
```

### 3.6 RISCO MEDIO: Design Constraint Incorreta — "Third-party repository — local-only changes, no remote push"

**Severidade**: Media (ja corrigida parcialmente)
**Impacto**: Confusao sobre permissoes de acesso

O `design.md` abre com "Key constraints: Third-party repository — local-only changes, no remote push". Porem, o MEMORY.md indica que o repo agora e um fork com full write access:

> "Fork with full write access (no longer LOCAL-ONLY constrained)"

A proposal.md tambem nao tem essa restricao. Essa inconsistencia pode causar confusao durante a implementacao — o agente pode hesitar em fazer push/PR quando deveria.

**Sugestao**: Remover a constraint "local-only" do design.md. Substituir por:
```
Key constraint: Fork repository with write access (github.com/phtcosta/jpf-symbc). Changes are committed in feature branches and merged via PR.
```

### 3.7 RISCO MEDIO: Ordem de Execucao de Compiler Executions no maven-compiler-plugin

**Severidade**: Media
**Impacto**: Se default-compile nao rodar primeiro, `Debug.class` nao estara disponivel para `Scanner.java`

Design D4 e INV-BLD-11 especificam que default-compile deve rodar antes das patch-module executions. Isso e correto — Maven executa executions na ordem em que aparecem no POM.

Porem, ha um detalhe tecnico nao coberto: **as 3 executions compartilham o mesmo output directory** (`target/classes`). A execution `compile-patch-java-base` precisa que `target/classes/gov/nasa/jpf/symbc/Debug.class` ja exista (compilado por default-compile). Isso funciona se:
- default-compile tem `<includes>` que incluem `gov/**,org/**` e `<excludes>` que excluem `java/**`
- patch-module executions tem `<includes>` para seus respectivos packages

**O POM template nao esta especificado no design**. O design menciona "3 compiler executions" mas nao mostra o XML. Isso deixa a implementacao ambigua.

**Sugestao**: Adicionar snippet de POM no design ou criar um sub-artifact `pom-templates/jpf-symbc-classes-pom.xml` com a configuracao exata. Alternativamente, task 5.3 pode ser expandida com o XML esperado.

### 3.8 RISCO MEDIO: 737 Deprecated Warnings Podem Obscurecer Erros Reais

**Severidade**: Media
**Impacto**: Mensagens de erro genuinas podem ser perdidas em meio a 737 warnings

O design documenta 737 deprecated boxed-type constructor calls (`new Integer()`, etc.) como "warnings-only". Embora nao bloqueiem compilacao, eles vao gerar **centenas de linhas de output** durante `mvn compile`. Isso pode:

1. Obscurecer warnings/errors reais (e.g., API changes do jpf-core)
2. Tornar o output do Maven dificil de analisar
3. Fazer `mvn compile` parecer estar falhando para quem nao conhece o projeto

**Sugestao**: Considerar adicionar ao parent POM durante Phase 2:
```xml
<compilerArgs>
  <arg>-Xlint:-deprecation</arg>
</compilerArgs>
```
Ou manter `-Xlint:deprecation` mas filtrar com `mvn compile 2>&1 | grep -v "new Integer\|new Double\|new Long\|new Float\|new Boolean"`.

### 3.9 RISCO BAIXO: Ausencia de `.gitignore` para Artefatos Maven

**Severidade**: Baixa
**Impacto**: Artefatos `target/` podem ser commitados acidentalmente

O design nao menciona atualizacao do `.gitignore`. Apos migracao, os 5 diretorios `target/` (um por modulo) precisam ser ignorados. O `.gitignore` atual provavelmente ignora `build/` mas nao `target/`.

**Sugestao**: Adicionar sub-task em 7.1:
```
- Atualizar .gitignore: adicionar `target/`, `*.class` patterns, `repo/` (se nao versionado)
```

Nota: `repo/` provavelmente DEVE ser versionado (contem os 20 JARs locais que nao estao no Maven Central). O design nao explicita isso.

### 3.10 RISCO BAIXO: Task 0.3b Usa JDK 11 com Artefatos Compilados por Java 8

**Severidade**: Baixa
**Impacto**: Resultado ambiguo — um sucesso nao garante que o Maven build funcione

Task 0.3b executa `java` (JDK 11) com JARs compilados pelo Ant (Java 8 bytecode). Isso e intencional ("If it fails here, the native libs or module system are the issue, not Maven"). No entanto:

1. Bytecode Java 8 (class format 52) e forward-compatible com JDK 11 (runtime 55), entao esse teste NAO valida compilacao Java 11.
2. O teste valida JNI + module system runtime behavior, que e o objetivo.
3. O comentario no task esta correto mas poderia ser mais explicito sobre o que exatamente esta sendo testado.

**Sugestao**: Nenhuma acao necessaria — esta correto. Apenas adicionar ao criterio de aceitacao: "SUCCESS here means: native libs and JPF ClassLoader are compatible with JDK 11 runtime. It does NOT mean Maven compilation with Java 11 source level works."

### 3.11 RISCO BAIXO: Exclusao de `**/JPF_*.java` nos Testes

**Severidade**: Baixa
**Impacto**: Peers poderiam ser executados como testes erroneamente

A lista de exclusoes do Surefire (build/spec delta, task 2.5) inclui `**/JPF_*.java`. Isso e correto para o Ant build (build.xml:265). No Maven, os peers estao em `jpf-symbc-main`, nao em `jpf-symbc-tests`, entao essa exclusao seria irrelevante para o modulo de testes.

Porem, manter a exclusao nao causa dano (apenas redundancia). E a presenca no spec garante paridade com o Ant build.

**Sugestao**: Manter como esta (defesa em profundidade). Adicionar comentario no POM: `<!-- Redundant in Maven (peers are in jpf-symbc-main), kept for parity with Ant build.xml -->`.

### 3.12 RISCO BAIXO: Versao `1.0.0-SNAPSHOT` para Todos os Modulos

**Severidade**: Baixa
**Impacto**: Semanticamente impreciso — nao e uma versao 1.0 greenfield

O design usa `1.0.0-SNAPSHOT` para todos os modulos. Semanticamente, jpf-symbc nao e um projeto versao 1.0 — e um projeto maduro sendo migrado. Uma versao como `0.1.0-SNAPSHOT` (pre-release) ou `11.0.0-SNAPSHOT` (alinhada com o Java target) poderia ser mais precisa.

**Sugestao**: Decisao do mantenedor. Ambas as opcoes sao validas. O importante e que o version string nao conflite com versoes futuras ou releases existentes.

---

## 4. Analise de Completude

### 4.1 Artefatos Completos

| Artefato | Status | Observacao |
|----------|--------|------------|
| proposal.md | Completo | Why/What/Capabilities/Impact bem estruturados |
| specs/build/spec.md | Completo | 4 INV MODIFIED, 4 INV ADDED, 2 INV REMOVED, 3 req MODIFIED, 1 req REMOVED |
| specs/dependencies/spec.md | Completo | 3 INV MODIFIED, 5 INV ADDED, 4 req MODIFIED, 2 req REMOVED |
| specs/configuration/spec.md | Completo | 3 INV MODIFIED, 3 INV ADDED, 3 req MODIFIED |
| design.md | Completo | Context, Architecture, 6 Decisions, Data Flow, Error Handling, Risks, Rollback, Testing |
| tasks.md | Completo | 9 grupos, 50+ subtasks com comandos e criterios |

### 4.2 Cobertura de Invariantes

| Dominio | Main Spec INVs | Delta Spec INVs | Cobertura |
|---------|---------------|-----------------|-----------|
| Build | INV-BLD-01..08 | MODIFIED 01-04, ADDED 09-12, REMOVED 07-08 | 100% |
| Dependencies | INV-DEP-01..07 | MODIFIED 01-02,05, ADDED 08-12 | 100% |
| Configuration | INV-CFG-01..09 | MODIFIED 03-04,06-07, ADDED 10,12-13 | 100% |

Total: 24 invariantes base, 14 deltas — todos com mapeamento claro.

### 4.3 Gaps Identificados

| Gap | Gravidade | Onde Falta |
|-----|-----------|-----------|
| POM XML template para jpf-symbc-classes (3 compiler executions) | Media | design.md ou tasks.md 5.3 |
| `.gitignore` update | Baixa | tasks.md grupo 7 |
| `sourcepath` verification em .jpf files | Media | tasks.md 4.4-4.5 |
| `repo/` versionamento decision (git tracked ou nao?) | Media | design.md Decisions |
| jpf.properties native_classpath generation script | Media | tasks.md 6.2 |
| Comando correto para runtime test (task 5.7) | Alta | tasks.md 5.7 |

---

## 5. Analise de Consistencia Interna

### 5.1 Consistencia entre Artefatos

| Par | Status | Inconsistencias |
|-----|--------|-----------------|
| proposal ↔ specs | Consistente | Todas as mudancas da proposal estao refletidas nos delta specs |
| proposal ↔ design | Consistente | Modulos, decisoes, e fases alinham |
| specs ↔ design | Consistente | INVs referenciados corretamente no design |
| design ↔ tasks | **1 inconsistencia** | design diz "local-only, no remote push"; tasks nao tem essa restricao. MEMORY.md contradiz |
| tasks ↔ specs | Consistente | Tasks cobrem todos os INVs e requisitos |
| specs delta ↔ specs base | Consistente | MODIFIED/ADDED/REMOVED sao complementares ao estado base |

### 5.2 Consistencia de Numeros

| Metrica | proposal | design | tasks | Consistente? |
|---------|----------|--------|-------|-------------|
| Java source files | 765 | 765 | 765 | Sim |
| .jpf files | 154 (34+118+1+1) | 154 | 154 (implicitly) | Sim |
| Maven modules | 5 | 5 | 5 | Sim |
| JARs Maven Central | 8 | 8 | 8 | Sim |
| JARs local repo | 20 | 20 | 20 | Sim |
| Source roots → modules merge | 6→5 (peers→main) | 6→5 | 6→5 | Sim |
| Model classes | 4 (Math, Scanner, BufferedImage, Kernel) | 4 | 4 | Sim |
| Native lib files | 34+ | 34+ | 34+ | Sim |
| Deprecated warnings | - | 737 | - | Sim (design-only) |

### 5.3 Consistencia Temporal (Fases)

O critical path declarado no subagent dispatch hint:
```
0 → 2 → 3 → 4 → 5 → 6 → 7 → 8
(1 e 2 em paralelo apos 0)
```

Verificacao: Task 2 (POMs) nao depende de Task 1 (repo/), porque os POMs referenciam repo/ mas nao precisam que ele exista para serem escritos. Correto.

Task 3 (mover arquivos) depende de Task 2 (diretorios existem). Correto.

Task 4 (.jpf paths) depende de Task 3 (arquivos no lugar). Correto.

Task 5 (Java 11) depende de Task 3 (validacao Java 8 precisa dos arquivos movidos). Correto.

**Nota**: Task 5.1 (mvn compile Java 8) acontece antes de 5.2 (Java 11 upgrade). Isso implica que Task 1 (repo/ com JARs) JA deve estar pronto quando Task 5.1 roda. Portanto, a timeline real e:

```
0 → [1 || 2] → 3 → 4 → 1 (se nao pronto) → 5.1 (Java 8) → 5.2-5.7 (Java 11) → 6 → 7 → 8
```

Task 1 DEVE completar antes de Task 5.1, nao apenas antes de Task 5.6. Esse constraint nao esta explicito no dispatch hint.

**Sugestao**: Atualizar o dispatch hint para clarificar que Task 1 e pre-requisito de Task 5.1 (nao apenas de 5.6).

---

## 6. Avaliacao contra SDD Best Practices

### 6.1 Conformidade com SDD.md Principios

| Principio | Avaliacao | Nota |
|-----------|-----------|------|
| Spec como Foundation (Sec 4.1) | Forte | Delta specs sao o artefato primario, tasks derivam delas |
| Intent over Implementation (Sec 4.2) | Adequado | Comandos bash em tasks sao "how" mas necessarios para migracao |
| Human-in-the-Loop (Sec 4.3) | Forte | Go/no-go checkpoint, verificacoes manuais |
| Living Documentation (Sec 4.4) | Adequado | Specs serao atualizadas via archive, mas design.md tem constraint obsoleta |
| Iterative Refinement (Sec 4.5) | Forte | Cross-LLM review ja incorporada |
| Proportional Ceremony (Sec 4.6) | Adequado | Full SDD e justificado para esta escala |

### 6.2 Conformidade com SDD-WORKFLOW.md

| Fase | Status | Nota |
|------|--------|------|
| Explore | Feito | PRD e pre-plan.md documentam exploracao |
| Create Change + Proposal | Feito | proposal.md completo |
| Specs | Feito | 3 delta specs completas |
| Design | Feito | design.md com decisoes e rationale |
| Tasks | Feito | tasks.md com 50+ subtasks |
| Implement | **Proximo** | `/opsx:apply` |
| Verify | Pendente | `/opsx:verify` |
| Archive | Pendente | `/opsx:archive` |

### 6.3 Conformidade com skills-agents-architecture.md

Os dispatch hints em tasks.md seguem as recomendacoes:
- Grupos independentes identificados para paralelismo
- Task tool (Agent) para bulk file operations (grupos 3-4)
- Component skills (nao orchestrators) durante apply

**Ponto de atencao**: O hint diz "Use subagent orchestration for Groups 3-4 (bulk file operations, ~920 files)". Isso e valido, mas subagents operam no mesmo filesystem e podem colidir se moverem/editarem os mesmos arquivos. Groups 3-4 sao escritas independentes (diferentes source roots para diferentes modulos), entao a paralelizacao e segura.

---

## 7. Comparacao com Cross-LLM Review (MEMORY.md)

O MEMORY.md indica que revisoes de Codex, Gemini, Minimax, e Qwen foram incorporadas. Baseado nos artefatos, as seguintes melhorias sao visiveis:

| Melhoria | Fonte Provavel | Evidencia |
|----------|---------------|-----------|
| Phase 0 expandida (0.3b E2E Z3) | Cross-LLM review | Mencionado explicitamente no MEMORY.md |
| Module system runtime test (5.7) | Cross-LLM review | Mencionado explicitamente |
| Surefire parity validation (6.4b) | Cross-LLM review | Mencionado explicitamente |
| Per-solver smoke table | Cross-LLM review | Mencionado explicitamente |
| Quantitative acceptance criteria | Cross-LLM review | Mencionado explicitamente |
| SHA-256 baseline | Cross-LLM review | Mencionado explicitamente |
| Rollback plan | Cross-LLM review | Mencionado explicitamente |
| INV-BLD-03 breaking change | Cross-LLM review | Mencionado explicitamente |
| build.xml archive (nao delete) | Cross-LLM review | Mencionado explicitamente |
| Test*$* exclusion | Cross-LLM review | Mencionado explicitamente |

Todas as sugestoes visiveis da cross-LLM review foram incorporadas. O nivel de incorporacao e forte.

---

## 8. Recomendacoes Prioritizadas

### 8.1 Antes de `/opsx:apply` (Correcoes Necessarias)

| # | Acao | Risco Mitigado | Esforco |
|---|------|----------------|---------|
| 1 | **Corrigir comando em task 5.7** — substituir `-jar` por classpath correto via `mvn exec:java` ou classpath manual | 3.1 | 15 min |
| 2 | **Remover constraint "local-only" do design.md** | 3.6 | 5 min |
| 3 | **Adicionar verificacao de `sourcepath` em tasks 4.4-4.5** — grep para `src/tests` e `src/examples` | 3.5 | 5 min |
| 4 | **Clarificar dependencia Task 1 → Task 5.1 no dispatch hint** | 5.3 | 5 min |

### 8.2 Durante Phase 0 (Investigar)

| # | Acao | Risco Mitigado | Esforco |
|---|------|----------------|---------|
| 5 | **Verificar peers em jpf-core oficial vs fork** (task 0.4 extension) | 3.4 | 30 min |
| 6 | **Definir baseline quantitativo de testes** (pass/fail/skip counts) | 3.3 | 1 hora |
| 7 | **Decidir se `repo/` e git-tracked** e documentar em design.md | 4.3 Gap | 15 min |

### 8.3 Durante Phase 1-2 (Implementar)

| # | Acao | Risco Mitigado | Esforco |
|---|------|----------------|---------|
| 8 | **Criar POM template para jpf-symbc-classes** com 3 compiler executions | 3.7 | 1 hora |
| 9 | **Adicionar `.gitignore` update em task group 7** | 3.9 | 5 min |
| 10 | **Criar script para gerar native_classpath de jpf.properties** | 3.2 | 30 min |
| 11 | **Considerar suprimir deprecation warnings** em Phase 2 | 3.8 | 10 min |

---

## 9. Matriz de Avaliacao Final

| Dimensao | Nota (1-10) | Justificativa |
|----------|-------------|---------------|
| **Completude** | 9/10 | Todos os artefatos presentes; gaps sao menores |
| **Consistencia interna** | 8/10 | 1 inconsistencia (local-only constraint) e 1 dependencia temporal nao explicita |
| **Rastreabilidade** | 10/10 | 13 FRs + 7 NFRs → specs → design → tasks sem orfaos |
| **Cobertura de riscos** | 9/10 | Phase 0 expandida e excepcional; falta baseline quantitativo de testes |
| **Qualidade tecnica** | 8/10 | Decisoes solidas; task 5.7 incorreto; falta POM template |
| **Conformidade SDD** | 9/10 | Segue SDD Full corretamente; proportional ceremony adequado |
| **Actionability** | 8/10 | Tasks tem comandos concretos; 3 precisam correcao |
| **Rollback safety** | 9/10 | Plan por fase com triggers quantitativos; git tag de seguranca |
| **Cross-LLM review integration** | 10/10 | Todas as sugestoes visiveis foram incorporadas |
| **Documentation quality** | 9/10 | Clara, bem estruturada; design.md tem constraint obsoleta |
| **MEDIA** | **8.9/10** | |

---

## 10. Conclusao

A change `gh1-migration-maven-java11` esta **pronta para implementacao** apos as 4 correcoes da secao 8.1 (estimativa: 30 minutos de trabalho). Os riscos identificados sao gerenciaveis e, em sua maioria, podem ser resolvidos durante a Phase 0.

O nivel de rigor no planejamento — particularmente a Phase 0 expandida, o tratamento do opt4j BLOCKER, e a integracao de cross-LLM review — e significativamente acima do padrao para projetos de pesquisa. O trabalho demonstra dominio do SDD methodology e aplicacao eficaz dos principios de proportional ceremony.

A principal area de melhoria e a especificacao de comandos de runtime (tasks 5.7, 6.2, 6.5) que precisam ser mais precisos quanto ao classpath Maven pos-migracao. Isso e esperado nesta fase — os comandos exatos so podem ser finalizados depois que a Phase 1 produz os primeiros artefatos Maven.
