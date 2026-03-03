# Análise Rigorosa: migration-maven-java11

**Autor:** Qwen Code  
**Data:** 2026-03-02  
**Change analisada:** `/openspec/changes/migration-maven-java11/`  
**Escopo:** Validação extremamente rigorosa da proposta de migração Ant→Maven + Java 8→Java 11

---

## Resumo Executivo

A proposta de migração é **tecnicamente sólida e bem fundamentada**, com documentação excepcionalmente detalhada. No entanto, identifica-se **riscos críticos não mitigados completamente** e **omissões importantes** que podem comprometer o sucesso da migração.

### Veredito: **APROVAR COM CONDICIONANTES**

**Condições obrigatórias antes de prosseguir:**
1. Fase 0 (validação de riscos) deve ser executada **antes** de Fase 1
2. Coordenadas Maven do jpf-core devem ser confirmadas (tarefa 0.2)
3. Smoke test Z3 deve passar (tarefa 0.3)
4. Decisão sobre Coral/opt4j deve ser documentada (suportado ou unsupported)
5. SAT4J deve ser verificado (custom build vs Maven Central)

**Risco Residual:**
| Risco | Nível | Mitigação |
|-------|-------|-----------|
| API divergence do jpf-core | Alto | Fase 0.4 quantifica antes de investir |
| Module System + ClassLoader JPF | Médio | Teste de runtime na Fase 5.7 |
| opt4j 3.3 compatibilidade | Médio | Fase 0.5 valida; Coral pode virar unsupported |
| Native libs JNI com Java 11 | Médio | Fase 0.3 + 0.3b end-to-end |

**Benefício Esperado:**
- Build moderno com Maven multi-module
- Java 11 (security updates, language features)
- Dependency management adequado (8 Central + 20 repo/)
- Integração com jpf-core oficial (javapathfinder/jpf-core)

**Recomendação:** Prosseguir com Fase 0 imediatamente. Se Fase 0 passar, migração é **viável e recomendada**.

---

## 1. Pontos Fortes

### 1.1 Documentação Excepcional

**proposal.md:**
- Estrutura clara: "Why/What/Capabilities/Impact"
- Quantificação precisa: 765 arquivos Java, 154 .jpf, 28 JARs
- Lista explícita de breaking changes
- Capabilities modificadas detalhadas (build, dependencies, configuration)
- Impacto categorizado (source files, config files, dependencies, build artifacts, risk areas)

**design.md:**
- Arquitetura detalhada com diagramas ASCII
- Matriz de rastreabilidade completa (Spec → Implementation → Test)
- 6 decisões arquiteturais com alternativas consideradas
- Data flows de build e runtime
- Error handling com estratégias de recuperação
- Testing strategy em camadas

**tasks.md:**
- 69 tarefas agrupadas em 9 grupos
- Dependências explícitas entre grupos
- Critérios de aceitação claros (✓ checkmarks)
- Subagent dispatch hints para otimização

**Qualidade:** Documentação nível enterprise — rara em projetos de pesquisa.

### 1.2 Análise de Riscos Proativa

**Riscos identificados na proposal.md (Seção 5):**
| Risco | Impacto | Probabilidade | Mitigação |
|-------|---------|---------------|-----------|
| API incompatibility jpf-core | HIGH | medium | git diff fork↔official (0.4) |
| Native library JDK 11 | MEDIUM | medium | Smoke test (0.3) |
| --patch-module compilation | HIGH | low | Padrão jpf-core |
| ClassLoader + module system | MEDIUM | medium | End-to-end testing |
| 154 .jpf files variados | MEDIUM | medium | sed + grep -rL verification |
| opt4j-2.4 BLOCKER | HIGH | certain | Upgrade para 3.3 (0.5) |

**Fase 0 dedicada a validação de blockers:**
- Go/no-go decision antes de investir tempo
- Smoke test de bibliotecas nativas com critério claro (Z3 obrigatório)
- Quantificação de divergência do fork
- Validação de opt4j 3.3

**Qualidade:** Abordagem madura — valida riscos caros antes de investir.

### 1.3 Estratégia de Migração Incremental

**Fase 1 (Java 8) → Fase 2 (Java 11):**
- Isola mudanças de build system de mudanças de versão Java
- Permite diagnóstico preciso: se falhar na Fase 2, é problema de Java 11, não de Maven
- Validação empírica em cada fase (`mvn compile` como critério)

**Fases bem definidas:**
```
Fase 0: Validação de riscos (go/no-go)
Fase 1: Estrutura Maven (Java 8)
Fase 2: Migração Java 11
Fase 3: Compatibilidade jpf-core + testes
Fase 4: Cleanup + documentação
```

**Qualidade:** Estratégia de baixo risco — falha rápido se houver blocker.

### 1.4 Padrão `--patch-module` Validado

**Model classes e módulos Java:**
| Classe | Módulo | --patch-module necessário |
|--------|--------|--------------------------|
| `java.lang.Math` | java.base | `--patch-module java.base=...` |
| `java.util.Scanner` | java.base | `--patch-module java.base=...` + `--add-reads` |
| `java.awt.image.BufferedImage` | java.desktop | `--patch-module java.desktop=...` |
| `java.awt.image.Kernel` | java.desktop | `--patch-module java.desktop=...` |

**3 execuções do compiler plugin (design.md Seção 2.2):**
1. `default-compile`: classes regulares (gov/, org/) — inclui Debug.java
2. `compile-patch-java-base`: Math, Scanner — com `--add-reads java.base=ALL-UNNAMED`
3. `compile-patch-java-desktop`: BufferedImage, Kernel

**Referência:** Segue exatamente o padrão do jpf-core oficial (`gradle/source-sets.gradle` linhas 42-60).

**Qualidade:** Padrão comprovado — jpf-core já usa esta abordagem.

### 1.5 Repositório Local Portátil

**Decisão D2 (design.md):** `repo/` directory com Maven layout

**Vantagens:**
- Usa `${maven.multiModuleProjectDirectory}/repo` (Maven 3.3.1+)
- Evita `<systemPath>` (deprecated, não transitivo, quebra `mvn install`)
- Não requer infraestrutura externa (Nexus/Artifactory)
- Portável: clone + build funciona sem configuração externa

**20 JARs no repo/:**
- coral, green, hampi, iasolver, string, solver, scale, proteus
- Statemachines, STPJNI, yicesapijava, libcvc3, libcvc3-5.0.0
- com.microsoft.z3, choco-1_2_04, choco-solver-2.1.1
- opt4j-2.4 (→ 3.3), grappa
- org.sat4j.core (CUSTOM v20100705), org.sat4j.pb (CUSTOM v20100705)

**Qualidade:** Solução pragmática para JARs sem Maven Central.

### 1.6 Análise de Dependências Cruzadas Empírica

**Verificações realizadas:**
- `src/classes` **não depende** de `src/main` (0 imports verificados)
- `src/annotations` sem dependências externas
- Import morto em `BufferedImage.java` identificado (`import gov.nasa.jpf.symbc.Debug;` — uso comentado)
- Dependências entre model classes mapeadas (Scanner → Debug)

**Invariantes preservadas:**
- INV-BLD-05: `src/classes` NÃO depende de `src/main` ✓
- INV-BLD-06: `src/annotations` sem deps externas ✓
- INV-DEP-06: `jpf-symbc-classes` depende apenas de jpf-core + annotations ✓

**Qualidade:** Análise empírica rigorosa — não assume, verifica.

### 1.7 Mapeamento Completo de Arquivos

**proposal.md "What Changes":**
- 765 source files → 5 módulos Maven
- 154 .jpf files → paths atualizados
- 28 JARs → 8 Maven Central + 20 repo/
- 3 JARs produzidos → 5 JARs (um por módulo)

**tasks.md — Group 3 (Move Source Files):**
- 3.1: Remover import morto (BufferedImage.java)
- 3.2-3.13: Copy com preservação de package structure
- Contagens verificadas: annotations=4, main+peers=342, classes=9, tests=197, examples=213

**Qualidade:** Rastreabilidade completa — nenhum arquivo esquecido.

---

## 2. Pontos Fracos / Lacunas Críticas

### 2.1 ⚠️ BLOCKER: opt4j 2.4 → 3.3 não foi validado empiricamente

**Problema:**
- opt4j 2.4 bundles Guice 1.0 com ASM 1.5.3/CGLIB 2.1_3
- **Não parse Java 11** (class file format 55.0)
- proposal.md: "Coral solver will crash; must upgrade opt4j to 3.3"
- tasks.md 0.5: "download opt4j 3.3, check if ProblemCoral compila"

**Omissão crítica:**
1. Não há verificação de **quais APIs opt4j** o jpf-symbc usa
2. Não há análise de impacto se opt4j 3.3 mudou API
3. Não há plano B se Coral não for migrável

**Análise de impacto:**
- `ProblemCoral.java` e relacionadas podem usar APIs removidas/mudadas
- opt4j 3.3 pode ter mudado pacotes (org.opt4j → ?)
- Se Coral for essencial para pesquisas em andamento, migração pode bloquear

**Risco:**
- **Alto** se Coral for "must-have" para pesquisas ativas
- **Médio** se Coral for "nice-to-have" (pode ser documentado como unsupported)

**Sugestão de mitigação:**
```markdown
Adicionar tarefa 0.5b (crítico):
- [ ] 0.5b Identificar todas as classes que importam org.opt4j.*
      grep -rh "import.*opt4j" src/main src/tests | sort -u
- [ ] 0.5b Listar APIs opt4j usadas (Optimizer, Module, Service, etc.)
- [ ] 0.5b Comparar API opt4j 2.4 vs 3.3 nas classes usadas
- [ ] 0.5b Estimativa de esforço de migração (horas/dias)
- [ ] 0.5b Decisão explícita: Coral é bloqueante ou pode ser unsupported?
```

**Recomendação:** Executar 0.5b **antes** de Fase 1. Se esforço for alto, documentar Coral como unsupported no Java 11.

---

### 2.2 ⚠️ BLOCKER: Coordenadas Maven do jpf-core não verificadas

**Problema:**
- proposal.md assume `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT`
- design.md assume `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT`
- tasks.md 0.2: "verify exact Maven coordinates" — **ainda não executado**
- Se coordenadas forem diferentes, **todos os 5 POMs precisam retrabalho**

**Cenários possíveis:**
1. `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` (assumido) ✓
2. `gov.nasa:jpf:DEVELOPMENT-SNAPSHOT` (sem `-core`) → atualizar 5 POMs
3. `gov.nasa:jpf-core:3.0.0-SNAPSHOT` (versão semântica) → atualizar property
4. `de.fraunhofer.ise:jpf-core:...` (groupId diferente) → impacto maior

**Risco:**
- **Baixo** (provavelmente coordenadas corretas)
- **Impacto médio** (retrabalho em 5 POMs + dependências)

**Sugestão de mitigação:**
```bash
# Executar tarefa 0.2 IMEDIATAMENTE:
git clone https://github.com/javapathfinder/jpf-core.git
cd jpf-core
./gradlew publishToMavenLocal
find ~/.m2/repository/gov/nasa -name "*.pom" | head -20

# Documentar coordenadas exatas no design.md:
# "Verified Coordinates: gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT"
```

**Recomendação:** Executar 0.2 **antes** de escrever qualquer POM.

---

### 2.3 ⚠️ Risco Alto: Divergência de API do jpf-core subestimada

**Problema:**
- tasks.md 0.4: "git diff fork vs official" — foca em `InstructionFactory`, `ClassInfo`, `MethodInfo`
- **Não menciona** outras APIs críticas: `ClassInfo`, `MethodInfo`, `Instruction`, `ThreadInfo`, `VM`, `ElementInfo`, etc.

**Análise preliminar:**
```bash
# 2275 imports de gov.nasa.jpf.* apenas em src/main
grep -rh "^import gov.nasa.jpf" src/main | wc -l  # 2275 matches
```

**Classes jpf-core provavelmente usadas:**
- `gov.nasa.jpf.vm.InstructionFactory` (SymbolicInstructionFactory)
- `gov.nasa.jpf.vm.ClassInfo` (reflection)
- `gov.nasa.jpf.vm.MethodInfo` (reflection)
- `gov.nasa.jpf.vm.ThreadInfo` (thread state)
- `gov.nasa.jpf.vm.VM` (VM state)
- `gov.nasa.jpf.vm.ElementInfo` (object fields)
- `gov.nasa.jpf.jvm.bytecode.*` (bytecode instructions)

**Risco:**
- Se API mudou significativamente, esforço de adaptação pode ser **semanas**, não dias
- `SymbolicInstructionFactory` pode precisar reescrita significativa
- Peers (`JPF_java_lang_Math.java`, etc.) podem quebrar

**Sugestão de mitigação:**
```markdown
Expandir tarefa 0.4 (crítico):
- [ ] 0.4a Listar TODAS as classes jpf-core importadas:
      grep -rh "^import gov.nasa.jpf" src/main src/peers src/classes \
        | sort -u | sed 's/import //' | sed 's/;$//' > /tmp/jpf-imports.txt
- [ ] 0.4b Para cada classe, verificar se existe no jpf-core oficial
- [ ] 0.4c Classificar divergências:
      - Breaking change (método removido/assinatura mudada)
      - Deprecation (método deprecated, ainda funciona)
      - Compatível (sem mudanças)
- [ ] 0.4d Estimativa de esforço:
      - <10 breaking changes: dias
      - 10-50 breaking changes: semanas
      - >50 breaking changes: reconsiderar migração
```

**Recomendação:** Executar 0.4 expandido **antes** de Fase 1. Se >50 breaking changes, reavaliar custo-benefício.

---

### 2.4 ⚠️ Risco Médio: 2 arquivos .jpf fora de tests/examples

**Problema:**
- `src/main/gov/nasa/jpf/symbc/concolic/TestMain.jpf` — em src/main, não em tests/examples
- `doc/Example.jpf` — em doc/, não em tests/examples

**design.md diz:**
> "Handle 2 extra .jpf files: decide placement (likely jpf-symbc-main/src/main/resources/)"

**Omissão:**
- Decisão **não foi tomada** — bloqueia tarefas 3.12 e 4.3
- Se colocados em `jpf-symbc-main/src/main/resources/`, paths atualizados referenciam `target/classes`
- Mas `.jpf` pode referenciar classes de teste → path errado

**Ação necessária:**
```bash
# Inspecionar conteúdo dos 2 arquivos:
cat src/main/gov/nasa/jpf/symbc/concolic/TestMain.jpf
cat doc/Example.jpf

# Verificar target class e classpath referenciado
```

**Sugestão de mitigação:**
```markdown
Adicionar critério de decisão (tasks.md 3.12):
- Se .jpf target = classe em src/main → jpf-symbc-main/src/main/resources/
- Se .jpf target = classe em src/tests → jpf-symbc-tests/src/test/resources/
- Se .jpf target = classe em src/examples → jpf-symbc-examples/src/main/resources/
- Se .jpf é documentação → manter em doc/ e atualizar manualmente

Decisão documentada:
- TestMain.jpf: [a decidir após inspeção]
- Example.jpf: [a decidir após inspeção]
```

**Recomendação:** Inspecionar e decidir **antes** de Fase 1.

---

### 2.5 ⚠️ Risco Médio: PathConditionsReliability-0.0.1.jar ausente

**Problema:**
- `jpf.properties` referencia `${jpf-symbc}/lib/PathConditionsReliability-0.0.1.jar`
- **JAR não existe em `lib/`** (verificado via list_directory)
- tasks.md 6.3: "Resolve — determine if dead reference or missing file"

**Ação necessária:**
```bash
# Verificar se é usado no código:
grep -rh "PathConditionsReliability" src/ || echo "Não encontrado"

# Verificar se há menção em documentação:
grep -rh "PathConditionsReliability" doc/ README.md || echo "Não encontrado"
```

**Cenários:**
1. Dead reference (nenhum import/usado) → remover de jpf.properties
2. Missing file (usado no código) → buscar JAR ou documentar funcionalidade quebrada

**Sugestão de mitigação:**
```markdown
Adicionar tarefa 6.3b:
- [ ] 6.3b grep por "PathConditionsReliability" no código-fonte
- [ ] 6.3b Se nenhum import/usado → remover de jpf.properties
- [ ] 6.3b Se usado → buscar JAR ou documentar como broken feature
```

**Recomendação:** Resolver **antes** de Fase 3 (atualização jpf.properties).

---

### 2.6 ⚠️ Risco Baixo: Deprecated APIs não tratadas

**Problema:**
- design.md menciona: "40+ deprecated constructor calls (new Integer(), new Double(), new Long())"
- open_questions.md: "Deprecated API warnings — compile on Java 11 with warnings"

**Impacto:**
- Compila com warnings, mas **não bloqueia**
- Pode poluir output do build, dificultar diagnóstico de outros warnings
- `Class.newInstance()` deprecated desde Java 9 (usa `getDeclaredConstructor().newInstance()`)
- `finalize()` override deprecated desde Java 9

**Exemplos prováveis:**
```java
// Deprecated em Java 9
Integer i = new Integer(5);  // → Integer.valueOf(5)
Double d = new Double(3.14); // → Double.valueOf(3.14)
Class<?> c = Class.forName("...").newInstance(); // → getDeclaredConstructor().newInstance()
```

**Sugestão de mitigação:**
```markdown
Adicionar tarefa pós-migração:
- [ ] 8.10 Cleanup deprecated APIs:
      - new Integer() → Integer.valueOf()
      - new Double() → Double.valueOf()
      - new Long() → Long.valueOf()
      - Class.newInstance() → getDeclaredConstructor().newInstance()
      - @Override finalize() → remover ou documentar

Ou aceitar warnings como "technical debt conhecida"
```

**Recomendação:** Aceitar warnings na migração, cleanup em fase posterior.

---

## 3. Riscos Adicionais Identificados

### 3.1 ⚠️ Risco Crítico: Module System + ClassLoader JPF

**Problema:**
- JPF usa ClassLoaders customizados para carregar model classes
- Java 11 module system pode conflitar com ClassLoaders customizados
- **Não há teste específico para este risco**

**Cenário de falha:**
```
Fase 2: mvn compile succeeds (Java 11)
Fase 3: mvn test fails com:
  java.lang.IllegalAccessError: class gov.nasa.jpf.vm.VM
    cannot access class jdk.internal.misc.Unsafe
    (module java.base is not accessible)
```

**Por que pode acontecer:**
- JPF carrega classes dinamicamente com ClassLoader customizado
- Module system restringe acesso a membros internos (jdk.internal.*)
- `--add-opens` e `--add-exports` podem não ser suficientes para ClassLoaders customizados

**Mitigação sugerida:**
```markdown
Adicionar tarefa 5.7 (crítico):
- [ ] 5.7 Teste de runtime com module system:
      - Executar um .jpf simples com Java 11 (ex: TestZ3.jpf)
      - Verificar se JPF consegue carregar model classes
      - Verificar se --add-opens/--add-exports são suficientes
      - Verificar se há IllegalAccessError ou InaccessibleObjectError

Critério de sucesso:
- JPF executa symbolic execution sem errors de module access
```

**Recomendação:** Adicionar 5.7 **antes** de Fase 6 (testes completos).

---

### 3.2 ⚠️ Risco Alto: Native Libraries + Java 11

**Problema:**
- tasks.md 0.3: Smoke test com `System.loadLibrary()`
- **Não testa com JPF** — apenas carrega biblioteca
- JNI pode falhar em runtime devido a mudanças no Java 11:
  - Remoção de JNI Invoke API
  - Mudanças em GC que afetam JNI Global References
  - Module system restringe acesso a sun.misc.Unsafe

**Cenário de falha:**
```
Fase 0.3: Smoke test passa (biblioteca carrega)
Fase 3: JPF + Z3 falha com:
  java.lang.UnsatisfiedLinkError: no z3java in java.library.path
  ou
  java.lang.NoClassDefFoundError: Could not initialize class com.microsoft.z3.Native
```

**Mitigação sugerida:**
```markdown
Adicionar tarefa 0.3b (crítico):
- [ ] 0.3b Executar teste end-to-end com JPF:
      - Criar TestZ3EndToEnd.java com @Test
      - Configurar .jpf com symbolic.dp=z3
      - Executar via JPF (não apenas carregar biblioteca)
      - Verificar se Z3 resolve constraints corretamente

Critério de sucesso:
- Z3 retorna solução correta para constraint simples
```

**Recomendação:** Adicionar 0.3b à Fase 0 (go/no-go).

---

### 3.3 ⚠️ Risco Médio: Surefire Exclusions não validadas

**Problema:**
- build.xml tem 12 padrões de exclusão de testes (FR10)
- tasks.md 2.5: "surefire config with exclusions from build.xml"
- **Não há verificação de que exclusões estão corretas**

**Exclusões do build.xml (FR10):**
```
**/TestBitwise*
**/TestCoverage.java
**/TestDIV.java
**/TestExJPF.java
**/TestLazy*
**/TestPathCondition.java
**/TestStringBuilder.java
**/strings/**
**/TestSymbolicListener.java
**/TestSymbolicOutput.java
**/TestSymbolicJPF.java
**/Test$* (inner test classes)
```

**Cenário de falha:**
- Teste que deveria ser excluído é executado → falha
- Teste que deveria ser executado é excluído → falso positivo

**Mitigação sugerida:**
```markdown
Adicionar tarefa 6.4b:
- [ ] 6.4b Comparar lista de testes excluídos no Ant vs Maven
- [ ] 6.4b Verificar que ExSymExe* NÃO são executados (129 arquivos)
      - ExSymExe* não seguem padrão Test*.java → excluídos implicitamente
      - Confirmar com mvn test -X | grep -E "ExSymExe|Running"

Critério de sucesso:
- Mesmos testes excluídos no Ant e Maven
- ExSymExe* compilados mas não executados
```

**Recomendação:** Adicionar 6.4b à Fase 6.

---

### 3.4 ⚠️ Risco Baixo: Encoding de arquivos .jpf

**Problema:**
- proposal.md não menciona encoding de arquivos .jpf
- sed pode corromper arquivos se encoding não for UTF-8
- 154 arquivos .jpf podem ter encoding misto (ISO-8859-1, UTF-8, etc.)

**Cenário de falha:**
```bash
# sed com encoding errado corrompe caracteres especiais
find . -name "*.jpf" -exec sed -i 's|build/tests|...|g' {} \;
# Arquivos ISO-8859-1 podem corromper acentos/comentários
```

**Mitigação sugerida:**
```markdown
Adicionar pré-tarefa 4.0:
- [ ] 4.0 Verificar encoding de arquivos .jpf:
      file -i src/tests/**/*.jpf src/examples/**/*.jpf | sort -u

- [ ] 4.0b Backup automático:
      sed -i.bak 's|build/tests|...|g' *.jpf

- [ ] 4.0c Verificar integridade pós-sed:
      grep -l $'\x80' jpf-symbc-*/src/**/*.jpf || echo "OK: sem corrupção"
```

**Recomendação:** Usar `sed -i.bak` para backup automático.

---

## 4. Erros / Inconsistências Encontradas

### 4.1 Inconsistência: Contagem de arquivos .jpf

| Documento | Contagem | Observação |
|-----------|----------|------------|
| proposal.md | 154 | "154 .jpf configuration files" |
| design.md (Capabilities) | 154 | "154 .jpf files: path property updates" |
| design.md (Context) | 154 | "34 in tests, 118 in examples, 1 in src/main, 1 in doc/" |
| design.md (Data Flow) | 152 | "152 in tests+examples" ← **incorreto** |
| tasks.md | 152 | Múltiplas menções a "152 .jpf files" ← **subestima 2** |

**Correção:**
- Total: 154 (34 tests + 118 examples + 1 TestMain.jpf + 1 Example.jpf)
- tests+examples: 152 (34 + 118)
- tasks.md deve referenciar "152 em tests+examples + 2 extras = 154 total"

**Impacto:** Baixo — mas pode causar confusão na verificação (grep -rL pode retornar 2 arquivos não-atualizados).

---

### 4.2 Inconsistência: JARs Maven Central (8 vs 10)

**proposal.md "What Changes":**
> "Move 8 JARs with verified Maven Central equivalents"

**dependencies/spec.md (JARs disponíveis no Maven Central):**
| JAR | Maven Central | Verificado |
|-----|---------------|------------|
| commons-lang-2.4.jar | commons-lang:commons-lang:2.4 | HTTP 200 ✓ |
| commons-math-1.2.jar | commons-math:commons-math:1.2 | HTTP 200 ✓ |
| bcel.jar | org.apache.bcel:bcel:6.0 | HTTP 200 ✓ |
| automaton.jar | dk.brics.automaton:automaton:1.11-8 | HTTP 200 ✓ |
| jaxen.jar | jaxen:jaxen:1.2.0 | HTTP 200 ✓ |
| JSAP-2.1.jar | com.martiansoftware:jsap:2.1 | HTTP 200 ✓ |
| aima-core.jar | com.googlecode.aima-java:aima-core:0.10.5 | HTTP 200 ✓ |
| jedis-2.0.0.jar | redis.clients:jedis:2.0.0 | HTTP 200 ✓ |

**Total: 8 JARs** ✓

**Mas 20260227_plano_migracao_java11.md (1.2) lista:**
> "org.sat4j.core.jar → org.ow2.sat4j:org.ow2.sat4j.core:2.3.6"
> "org.sat4j.pb.jar → org.ow2.sat4j:org.ow2.sat4j.pb:2.3.6"

**Conflito:**
- dependencies/spec.md diz SAT4J são **CUSTOM builds v20100705** → NÃO Maven Central
- 20260227_plano_migracao_java11.md sugere Maven Central → **pode quebrar**

**Análise:**
```bash
# Verificar se SAT4J custom tem diferenças:
# Maven Central: org.ow2.sat4j:org.sat4j.core:2.3.6 (2013)
# Custom build: v20100705 (2010) — mais antigo!

# Risco: custom build pode ter patches/fixes não presentes no Maven Central
```

**Correção:**
- Se SAT4J custom tem diferenças → manter em repo/ local (8 JARs Central)
- Se SAT4J custom é idêntico → usar Maven Central (10 JARs Central)

**Recomendação:** Verificar diferenças SAT4J antes de Fase 1.

---

### 4.3 Erro: JARs Maven Central na proposal.md vs design.md

**proposal.md "What Changes":**
> "Move 8 JARs with verified Maven Central equivalents to standard <dependency> declarations"
> "Move 20 JARs without Maven Central equivalents [...] to a project-local Maven repository"

**design.md (1.2) lista 20 JARs para repo/:**
1. coral
2. green
3. hampi
4. iasolver
5. string
6. solver
7. scale
8. proteus
9. Statemachines
10. STPJNI
11. yicesapijava
12. libcvc3
13. libcvc3-5.0.0
14. com.microsoft.z3
15. choco-1_2_04
16. choco-solver-2.1.1
17. opt4j (2.4 → 3.3)
18. grappa
19. org.sat4j.core (CUSTOM)
20. org.sat4j.pb (CUSTOM)

**Total: 20 JARs** ✓

**Mas 20260227_plano_migracao_java11.md (1.2) lista 19 JARs para repo/:**
- Inclui PathConditionsReliability-0.0.1.jar (que não existe em lib/)
- **Não conta SAT4J como 2 separados** (conta como 1?)

**Conflito:**
- proposal.md: 20 JARs repo/
- 20260227_plano_migracao_java11.md: 19 JARs repo/ (PathConditionsReliability incluído?)

**Correção:**
- 20 JARs repo/ (proposal.md correto)
- PathConditionsReliability-0.0.1.jar: dead reference ou missing file (resolver em 6.3)

**Recomendação:** Atualizar 20260227_plano_migracao_java11.md para 20 JARs.

---

## 5. Validação de Invariants (Especificações)

### 5.1 build/spec.md — Invariants

| Invariant | Status na Migração | Ação Necessária |
|-----------|-------------------|-----------------|
| INV-BLD-01: Java 8 source/target | **Quebrado** → Java 11 (intencional) | Atualizar spec para Java 11 |
| INV-BLD-02: jpf-symbc.jar = main + peers | **Preservado** → jpf-symbc-main.jar | Nenhuma |
| INV-BLD-03: jpf-symbc-classes.jar = classes + annotations | **Quebrado** → annotations em módulo separado | Atualizar spec |
| INV-BLD-04: jpf-symbc-annotations.jar = annotations only | **Preservado** | Nenhuma |
| INV-BLD-05: classes NÃO dependem de main | **Preservado** (verificado) | Nenhuma |
| INV-BLD-06: annotations sem deps externas | **Preservado** | Nenhuma |
| INV-BLD-07: debug symbols on | **Preservado** (debug=true) | Nenhuma |
| INV-BLD-08: deprecation warnings on | **Preservado** (showDeprecation=true) | Nenhuma |

**Ação:** Atualizar build/spec.md para refletir:
- Java 11 (não 8)
- 5 módulos Maven (não 3 JARs)
- annotations em módulo separado (não em jpf-symbc-classes.jar)

---

### 5.2 dependencies/spec.md — Invariants

| Invariant | Status na Migração | Ação Necessária |
|-----------|-------------------|-----------------|
| INV-DEP-01: jpf-core via site.properties | **Mudado** → Maven local (~/.m2/repository) | Atualizar spec |
| INV-DEP-02: 28 JARs em lib/ | **Mudado** → 8 Central + 20 repo/ | Atualizar spec |
| INV-DEP-03: Z3 native loadable | **A validar** (Fase 0.3) | Executar 0.3 |
| INV-DEP-04: CVC3 native em lib/64bit/ | **Preservado** (lib/ mantido) | Nenhuma |
| INV-DEP-05: native_classpath listado | **Preservado** (paths atualizados) | Nenhuma |
| INV-DEP-06: classes depende jpf-core + annotations | **Preservado** | Nenhuma |
| INV-DEP-07: main NÃO depende de classes | **Preservado** | Nenhuma |

**Ação:** Atualizar dependencies/spec.md para refletir:
- Maven dependency management (não lib/ flat)
- jpf-core via Maven local (não peer directory)
- repo/ para JARs sem Central

---

### 5.3 configuration/spec.md — Invariants

| Invariant | Status na Migração | Ação Necessária |
|-----------|-------------------|-----------------|
| INV-CFG-01: jvm.insn_factory.class | **Preservado** | Nenhuma |
| INV-CFG-02: vm.storage.class=nil | **Preservado** | Nenhuma |
| INV-CFG-03: classpath tests → build/tests | **Mudado** → jpf-symbc-tests/target/test-classes | Atualizar spec |
| INV-CFG-04: classpath examples → build/examples | **Mudado** → jpf-symbc-examples/target/classes | Atualizar spec |
| INV-CFG-05: symbolic.method formato | **Preservado** | Nenhuma |
| INV-CFG-06: native_classpath com JARs | **Preservado** (paths atualizados) | Nenhuma |
| INV-CFG-07: classpath com model classes | **Preservado** | Nenhuma |
| INV-CFG-08: peer_packages | **Preservado** | Nenhuma |
| INV-CFG-09: .jpf usa ${jpf-symbc} | **Preservado** (sed mantém variável) | Nenhuma |

**Ação:** Atualizar configuration/spec.md para refletir:
- Maven output directories (target/classes, target/test-classes)
- Novos paths em jpf.properties

---

## 6. Sugestões de Melhoria

### 6.1 Adicionar Critérios de Aceite Quantitativos

**Atual (vago):**
> "mvn compile succeeds"

**Sugestão (específico):**
```markdown
Critérios de aceite Fase 1 (Java 8):
- [ ] 765 arquivos Java compilam sem erro
- [ ] 0 errors, ≤50 warnings (deprecated APIs)
- [ ] 5 JARs produzidos em */target/*.jar:
      jpf-symbc-annotations-1.0.0-SNAPSHOT.jar
      jpf-symbc-main-1.0.0-SNAPSHOT.jar
      jpf-symbc-classes-1.0.0-SNAPSHOT.jar
      jpf-symbc-tests-1.0.0-SNAPSHOT.jar
      jpf-symbc-examples-1.0.0-SNAPSHOT.jar
- [ ] Tempo de build < 5 minutos (baseline)
```

**Sugestão (específico) Fase 2 (Java 11):**
```markdown
Critérios de aceite Fase 2:
- [ ] 765 arquivos Java compilam com Java 11
- [ ] 4 model classes compilam com --patch-module
- [ ] mvn compile com JDK 11 (JAVA_HOME=/path/to/jdk-11)
- [ ] javac -version → 11.x.x
```

---

### 6.2 Adicionar Rollback Plan

**Omissão:**
- Não há plano de rollback se migração falhar
- Se Fase 3 revelar blockers, como voltar ao estado anterior?

**Sugestão:**
```markdown
Rollback Plan:
1. Manter branch pre-migration-java11 até validação completa (Fase 8)
2. Se blocker insuperável na Fase N:
   - git checkout pre-migration-java11
   - Criar branch migration-java11-failed-phase-N
   - Documentar lições aprendidas em migration-retrospective.md
3. Critérios para rollback:
   - API divergence >50 breaking changes (Fase 0.4)
   - Z3 native lib não carrega em Java 11 (Fase 0.3)
   - Module system + ClassLoader incompatível (Fase 5.7)
   - Coral essencial e opt4j 3.3 incompatível (Fase 0.5)
```

---

### 6.3 Adicionar Smoke Tests por Solver

**Atual (vago):**
> tasks.md 6.6: "Run solver-specific integration tests"

**Sugestão (específico):**
```markdown
Smoke tests por solver (Fase 6.6b):

| Solver | .jpf exemplo | Critério de sucesso | Status |
|--------|--------------|---------------------|--------|
| Z3 | TestZ3.jpf | Retorna solução correta | [ ] |
| Choco | NumberExample.jpf | Retorna solução correta | [ ] |
| Coral | (a definir) | Retorna solução correta | [ ] |
| CVC3 | (a definir) | Retorna solução ou documentar unsupported | [ ] |
| STP | (a definir) | Retorna solução ou documentar unsupported | [ ] |
| Yices | (a definir) | Retorna solução ou documentar unsupported | [ ] |
| Green | (a definir) | Retorna solução correta | [ ] |
| HAMPI | (a definir) | Retorna solução correta | [ ] |
| ABC | (a definir) | Retorna solução ou documentar unsupported | [ ] |

Critério de sucesso geral:
- Z3, Choco, Green, HAMPI: PASS obrigatório
- Coral: PASS se opt4j 3.3 compatível, senão documentar unsupported
- CVC3, STP, Yices, ABC: PASS ou documentar unsupported (native lib issues)
```

---

### 6.4 Melhorar Rastreabilidade de .jpf Files

**Problema:**
- 154 arquivos .jpf, mas proposta menciona "152" em alguns lugares
- Discrepância de 2 arquivos (TestMain.jpf + Example.jpf)
- Sem rastreabilidade individual

**Sugestão:**
```markdown
Adicionar tarefa 4.7:
- [ ] 4.7 Criar spreadsheet .jpf-migration-tracking.csv:

Path original,Path destino,Status,Notas
src/tests/TestZ3.jpf,jpf-symbc-tests/src/test/resources/TestZ3.jpf,atualizado,
src/tests/strings/HelloWorld.jpf,jpf-symbc-tests/src/test/resources/HelloWorld.jpf,atualizado,
src/examples/Test.jpf,jpf-symbc-examples/src/main/resources/Test.jpf,atualizado,
src/main/gov/nasa/jpf/symbc/concolic/TestMain.jpf,jpf-symbc-main/src/main/resources/TestMain.jpf,a decidir,placement depende do target
doc/Example.jpf,doc/Example.jpf,atualizado manualmente,documentação

- [ ] 4.7b Verificação final:
      wc -l .jpf-migration-tracking.csv  # Deve ser 155 (154 + header)
      grep -c "não-atualizado" .jpf-migration-tracking.csv  # Deve ser 0
```

---

### 6.5 Adicionar Validação de Conteúdo JAR

**Atual (vago):**
> tasks.md 8.5: "Verify JAR contents: compare class lists"

**Sugestão (script automático):**
```bash
#!/bin/bash
# validate-jar-contents.sh

echo "=== Validação de Conteúdo JAR ==="

# Build Ant (estado atual)
ant clean build
jar tf build/jpf-symbc.jar | sort > /tmp/ant-main-classes.txt
jar tf build/jpf-symbc-classes.jar | sort > /tmp/ant-classes-classes.txt
jar tf build/jpf-symbc-annotations.jar | sort > /tmp/ant-annotations-classes.txt

# Build Maven (após migração)
mvn clean package
jar tf jpf-symbc-main/target/jpf-symbc-main-1.0.0-SNAPSHOT.jar | sort > /tmp/maven-main-classes.txt
jar tf jpf-symbc-classes/target/jpf-symbc-classes-1.0.0-SNAPSHOT.jar | sort > /tmp/maven-classes-classes.txt
jar tf jpf-symbc-annotations/target/jpf-symbc-annotations-1.0.0-SNAPSHOT.jar | sort > /tmp/maven-annotations-classes.txt

# Comparar
echo "Comparando main classes..."
diff /tmp/ant-main-classes.txt /tmp/maven-main-classes.txt && echo "OK: main classes iguais"

echo "Comparando classes classes..."
diff /tmp/ant-classes-classes.txt /tmp/maven-classes-classes.txt && echo "OK: classes classes iguais"

echo "Comparando annotations classes..."
diff /tmp/ant-annotations-classes.txt /tmp/maven-annotations-classes.txt && echo "OK: annotations classes iguais"

# Nota: annotations agora estão em JAR separado
# jpf-symbc-classes.jar (Ant) = classes + annotations
# jpf-symbc-classes.jar (Maven) = classes apenas
# jpf-symbc-annotations.jar (Maven) = annotations apenas

echo "=== Validação completa ==="
```

---

## 7. Checklist de Validação Final

### Antes de Aprovar (Fase 0 obrigatória)

- [ ] **0.1 Criado**: `git tag pre-migration-java11`
- [ ] **0.2 Executado**: Coordenadas Maven do jpf-core verificadas
      ```bash
      find ~/.m2/repository/gov/nasa -name "*.pom" | head -20
      # Documentar: groupId:artifactId:version = ?
      ```
- [ ] **0.3 Executado**: Smoke test Z3 passou
      ```bash
      java -Djava.library.path=lib:lib/64bit NativeLibSmokeTest
      # Z3: [OK] ou [FAIL]
      ```
- [ ] **0.3b Executado**: End-to-end Z3 com JPF passou
      ```bash
      # Executar TestZ3.jpf via JPF
      # Verificar solução correta
      ```
- [ ] **0.4 Executado**: Divergência jpf-core quantificada
      ```bash
      # Listar breaking changes:
      # <10: dias de esforço
      # 10-50: semanas de esforço
      # >50: reconsiderar migração
      ```
- [ ] **0.5 Executado**: Compatibilidade opt4j 3.3 verificada
      ```bash
      # ProblemCoral compila com opt4j 3.3?
      # Decisão: Coral supported ou unsupported no Java 11?
      ```
- [ ] **SAT4J**: Confirmado se custom ou Maven Central
      ```bash
      # Comparar custom vs Maven Central
      # Decisão: repo/ ou Central?
      ```
- [ ] **PathConditionsReliability**: Confirmado se dead reference ou missing
      ```bash
      grep -rh "PathConditionsReliability" src/ || echo "Dead reference"
      ```
- [ ] **2 .jpf extras**: Decisão de placement tomada
      ```bash
      # TestMain.jpf: placement = ?
      # Example.jpf: placement = ?
      ```
- [ ] **Especificações**: Plano para atualizar build/spec.md, dependencies/spec.md, configuration/spec.md

### Após Aprovação (Fase 1+)

- [ ] **1.8**: Post-sed verification (grep -rL) passou
      ```bash
      grep -rl 'build/tests\|build/examples' jpf-symbc-*/ || echo "OK: nenhum path antigo"
      ```
- [ ] **5.1**: mvn compile com Java 8 succeeded
- [ ] **5.6**: mvn compile com Java 11 succeeded
- [ ] **5.7**: Module system + ClassLoader runtime test passou
- [ ] **6.4**: mvn test passou (exclusões validadas)
- [ ] **6.4b**: Surefire exclusions validadas vs Ant
- [ ] **6.6**: Testes por solver passaram (Z3, Choco, etc.)
- [ ] **8.6**: Native libs preservadas (34+ arquivos)
      ```bash
      find lib/ -name '*.so' -o -name '*.dll' -o -name '*.dylib' | wc -l
      # Deve match pre-migration count
      ```
- [ ] **8.8**: /sdd-verify passou
- [ ] **8.9**: /sdd-code-reviewer aprovou

---

## 8. Veredito Final

### Aprovação: **CONDICIONAL**

**Condições obrigatórias (executar antes de Fase 1):**

| Condição | Tarefa | Critério de Sucesso |
|----------|--------|---------------------|
| Coordenadas Maven jpf-core | 0.2 | `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` confirmado |
| Smoke test Z3 | 0.3 | `[OK] z3` no output |
| End-to-end Z3 | 0.3b | JPF + Z3 resolve constraint simples |
| Divergência jpf-core | 0.4 | <50 breaking changes |
| opt4j 3.3 compatibilidade | 0.5 | Coral compila ou documentar unsupported |
| SAT4J custom vs Central | (nova) | Decisão documentada |
| PathConditionsReliability | 6.3b | Dead reference ou missing file resolvido |
| 2 .jpf extras placement | 3.12 | Decisão documentada |

**Risco Residual:**

| Risco | Nível | Mitigação |
|-------|-------|-----------|
| API divergence >50 breaking changes | Alto | Fase 0.4 quantifica; rollback se >50 |
| Module System + ClassLoader incompatível | Médio | Fase 5.7 valida; rollback se incompatível |
| opt4j 3.3 incompatível (Coral) | Médio | Fase 0.5 valida; documentar unsupported se incompatível |
| Native libs JNI falham em Java 11 | Médio | Fase 0.3 + 0.3b validam; Z3 obrigatório, outros opcionais |

**Benefício Esperado:**

| Benefício | Impacto |
|-----------|---------|
| Build moderno com Maven | Alto — padrão indústria, melhor tooling |
| Java 11 (security updates) | Alto — Java 8 EOL desde 2019 |
| Dependency management adequado | Alto — 8 Central + 20 repo/, version tracking |
| Integração com jpf-core oficial | Alto — sai do fork isolado |
| --patch-module para model classes | Médio — segue padrão jpf-core |

**Recomendação Final:**

> **Prosseguir com Fase 0 imediatamente.**
>
> Se Fase 0 passar (todas as condições acima satisfeitas), migração é **viável e recomendada**.
>
> Se Fase 0 falhar (Z3 não carrega, >50 breaking changes, Coral essencial e incompatível), **reconsiderar migração** ou adotar abordagem alternativa (manter Java 8, atualizar apenas jpf-core fork).

---

## Apêndice A: Comandos de Validação Rápida

```bash
# 0.2 Coordenadas Maven jpf-core
git clone https://github.com/javapathfinder/jpf-core.git
cd jpf-core && ./gradlew publishToMavenLocal
find ~/.m2/repository/gov/nasa -name "*.pom" | head -20

# 0.3 Smoke test Z3
cat > NativeLibSmokeTest.java << 'EOF'
public class NativeLibSmokeTest {
    public static void main(String[] args) {
        String[] libs = {"z3", "cvc3", "stpjni", "yicesapijava"};
        for (String lib : libs) {
            try {
                System.loadLibrary(lib);
                System.out.println("[OK]   " + lib);
            } catch (UnsatisfiedLinkError e) {
                System.out.println("[FAIL] " + lib + " — " + e.getMessage());
            }
        }
    }
}
EOF
javac NativeLibSmokeTest.java
java -Djava.library.path=lib:lib/64bit NativeLibSmokeTest

# 0.4 Divergência jpf-core
cd /path/to/jpf-symbc
grep -rh "^import gov.nasa.jpf" src/main src/peers src/classes \
  | sort -u | sed 's/import //' | sed 's/;$//' > /tmp/jpf-imports.txt
# Comparar com jpf-core oficial

# 0.5 opt4j 3.3 compatibilidade
wget https://github.com/SDARG/opt4j/releases/download/opt4j-3.3/opt4j-3.3.zip
unzip opt4j-3.3.zip
# Tentar compilar ProblemCoral.java contra opt4j-3.3.jar

# SAT4J custom vs Central
jar xf lib/org.sat4j.core.jar
# Comparar com Maven Central org.ow2.sat4j:org.sat4j.core:2.3.6

# PathConditionsReliability
grep -rh "PathConditionsReliability" src/ || echo "Dead reference"
```

---

## Apêndice B: Referências

- [proposal.md](../openspec/changes/migration-maven-java11/proposal.md)
- [design.md](../openspec/changes/migration-maven-java11/design.md)
- [tasks.md](../openspec/changes/migration-maven-java11/tasks.md)
- [build/spec.md](../openspec/specs/build/spec.md)
- [dependencies/spec.md](../openspec/specs/dependencies/spec.md)
- [configuration/spec.md](../openspec/specs/configuration/spec.md)
- [20260227_plano_migracao_java11.md](../20260227_plano_migracao_java11.md)
- [jpf-core oficial](https://github.com/javapathfinder/jpf-core)
- [jpf-core fork (yannicnoller)](https://github.com/yannicnoller/jpf-core)
- [opt4j 3.3](https://github.com/SDARG/opt4j)

---

**Fim da Análise**
