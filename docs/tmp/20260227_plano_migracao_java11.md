# Plano de Migração: jpf-symbc → Maven Multi-Module + Java 11

## Contexto

O jpf-symbc atualmente depende de um fork específico do jpf-core (yannicnoller/jpf-core) que usa Java 8. O jpf-core oficial (javapathfinder/jpf-core) já migrou para Java 11 com build Gradle. O objetivo é migrar o jpf-symbc para funcionar com o jpf-core atual, começando pela migração de Ant para Maven multi-module e de Java 8 para Java 11.

**Estado atual do jpf-symbc:**
- Build: Apache Ant (`build.xml`)
- Java: 8
- jpf-core: fork yannicnoller (Java 8, Ant)
- 6 source roots: `src/main`, `src/peers`, `src/annotations`, `src/classes`, `src/tests`, `src/examples`
- 28 JARs em `lib/`, maioria sem artefato Maven Central
- 3 JARs produzidos: `jpf-symbc.jar`, `jpf-symbc-classes.jar`, `jpf-symbc-annotations.jar`

**Estado atual do jpf-core oficial:**
- Build: Gradle (`build.gradle`)
- Java: 11
- Model classes `java.*` usam `--patch-module` para compilar (ver `gradle/source-sets.gradle`)
- Publica artefatos via `./gradlew publishToMavenLocal` (groupId `gov.nasa`)
- Testes usam `--add-opens` e `--add-exports` para módulos Java 11

**Análise de compatibilidade Java 8 → 11:**
- Nenhum uso de APIs internas `sun.*` ou `com.sun.*` no código-fonte
- Nenhum uso de APIs removidas no Java 11 (javax.xml.bind, java.activation, CORBA)
- Nenhum uso de reflection problemático (setAccessible, etc.)
- Lambdas e Streams usados em ~45 arquivos — totalmente compatíveis
- Principal desafio: compilação das model classes `java.*` com module system

**Model classes e seus módulos Java (verificado):**

| Classe | Módulo Java | --patch-module necessário |
|--------|-------------|--------------------------|
| `java.lang.Math` | `java.base` | `--patch-module java.base=...` |
| `java.util.Scanner` | `java.base` | `--patch-module java.base=...` |
| `java.awt.image.BufferedImage` | `java.desktop` | `--patch-module java.desktop=...` |
| `java.awt.image.Kernel` | `java.desktop` | `--patch-module java.desktop=...` |

**Dependências cruzadas entre model classes (verificado):**

| Classe | Importa | Impacto |
|--------|---------|---------|
| `java.util.Scanner` | `gov.nasa.jpf.symbc.Debug` | Requer `--add-reads java.base=ALL-UNNAMED` |
| `java.awt.image.BufferedImage` | `gov.nasa.jpf.symbc.Debug` (import presente mas **uso comentado**) | Remover import morto; sem impacto funcional |
| `java.lang.Math` | (nenhuma dependência cruzada) | Limpo |
| `java.awt.image.Kernel` | (nenhuma dependência cruzada) | Limpo |
| `gov.nasa.jpf.symbc.Debug` | `gov.nasa.jpf.vm.Verify` (do jpf-core) | jpf-symbc-classes depende de jpf-core |

**Dependências entre source roots (verificado empiricamente):**

| Source root | Importa de | NÃO importa de |
|-------------|-----------|-----------------|
| `src/annotations` | (nenhum) | — |
| `src/main` | jpf-core, annotations | `src/classes` (confirmado: 0 imports) |
| `src/peers` | jpf-core | `src/classes` (confirmado: 0 imports) |
| `src/classes/gov/**` | jpf-core (`Verify`), próprio módulo (`Debug`) | `src/main` (confirmado: 0 imports) |
| `src/classes/java/**` | `Debug` (mesmo módulo classes) | `src/main` |
| `src/tests` | todos acima + junit | — |
| `src/examples` | main, classes, annotations | — |

> Implicação: `jpf-symbc-classes` **não** depende de `jpf-symbc-main`. A dependência é apenas: `annotations` + `jpf-core`.

---

## Decisões Arquiteturais

| Decisão | Escolha | Justificativa |
|---------|---------|---------------|
| Estrutura Maven | Multi-module | Separação clara de concerns, um JAR por módulo |
| JARs sem Maven Central | Repositório local (`repo/`) | Portável, limpo, sem deprecated system scope |
| Solvers | Manter todos (incluindo CVC3) | Preservar compatibilidade total |
| jpf-core | `./gradlew publishToMavenLocal` | Sem artefatos no Maven Central; build local é prática padrão no ecossistema JPF |

---

## Fase 0: Validação de Riscos Bloqueadores

> Objetivo: Antes de investir na migração, validar os 3 riscos que podem bloquear o projeto inteiro. Esforço estimado: 1-2h.

### 0.1 Criar safety net

```bash
git tag pre-migration-java11
```

### 0.2 Instalar e verificar coordenadas Maven do jpf-core

```bash
# Clonar o jpf-core oficial (Java 11)
git clone https://github.com/javapathfinder/jpf-core.git
cd jpf-core
# Publicar no Maven local (~/.m2/repository)
./gradlew publishToMavenLocal
```

**Verificação obrigatória** — antes de escrever qualquer POM:

```bash
# Listar artefatos reais publicados
find ~/.m2/repository/gov/nasa -name "*.pom" | head -20
# Anotar groupId, artifactId e version EXATOS
```

Artefatos esperados (confirmar após execução):
- `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` (jpf.jar — main + peers + annotations)
- `gov.nasa:jpf-annotations:DEVELOPMENT-SNAPSHOT`
- `gov.nasa:jpf-classes:DEVELOPMENT-SNAPSHOT`

> **Critério de sucesso:** Coordenadas Maven confirmadas. Se forem diferentes do esperado, atualizar todas as referências no plano antes de prosseguir.

### 0.3 Smoke test de bibliotecas nativas (JNI) com Java 11

As bibliotecas nativas (.so/.dll/.dylib) em `lib/` foram compiladas há anos contra JDKs e glibc específicos. Este teste valida se elas carregam em JDK 11.

```java
// NativeLibSmokeTest.java — compilar e executar com JDK 11
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
```

```bash
# Executar com java.library.path apontando para lib/64bit/
javac NativeLibSmokeTest.java
java -Djava.library.path=lib/64bit NativeLibSmokeTest
```

> **Critério de sucesso:** Z3 deve carregar (solver principal). Falhas em CVC3/STP/Yices não bloqueiam a migração — esses solvers são opcionais e raramente usados. Documentar resultados para decisão go/no-go.

### 0.4 Quantificar divergência do fork jpf-core

Analisar as diferenças entre o fork yannicnoller (usado atualmente) e o jpf-core oficial (alvo da migração), focando nas APIs que jpf-symbc realmente usa.

```bash
# 1. Listar classes jpf-core importadas pelo jpf-symbc
grep -rh "^import gov.nasa.jpf" src/main src/peers src/classes src/tests \
  | sort -u | sed 's/import //' | sed 's/;$//' > /tmp/jpf-symbc-imports.txt

# 2. No diretório do jpf-core oficial, comparar com o fork
cd /path/to/jpf-core
git remote add fork https://github.com/yannicnoller/jpf-core.git
git fetch fork
# Diff entre fork e oficial nos arquivos que jpf-symbc usa
git diff fork/master..HEAD -- src/main/gov/nasa/jpf/ | diffstat
```

> **Critério de sucesso:** Entender escopo das mudanças. Se houver mudanças em `InstructionFactory`, `ClassInfo` ou `MethodInfo`, estimar esforço de adaptação antes de prosseguir.

---

## Fase 1: Estrutura Maven Multi-Module (compilando com Java 8)

> Objetivo: Validar a estrutura Maven sem mudar versão Java. `mvn compile` deve funcionar com Java 8.

### 1.1 Pré-requisito: jpf-core instalado localmente

> Já executado na Fase 0.2. Confirmar que `~/.m2/repository/gov/nasa/` contém os artefatos.

### 1.2 Criar repositório local para JARs de pesquisa (`repo/`)

Para cada JAR sem Maven Central, instalar no repo local do projeto:

```bash
# Exemplo para cada JAR:
mvn deploy:deploy-file \
  -DgroupId=gov.nasa.jpf.symbc -DartifactId=coral -Dversion=1.0.0 \
  -Dfile=lib/coral.jar -Dpackaging=jar \
  -Durl=file://$(pwd)/repo -DrepositoryId=project-local
```

**JARs para repositório local do projeto (`repo/`):**

Inclui todos os JARs sem artefato verificado no Maven Central:

| JAR | groupId | artifactId | version |
|-----|---------|------------|---------|
| coral.jar | gov.nasa.jpf.symbc | coral | 1.0.0 |
| green.jar | za.ac.sun.cs | green | 1.0.0 |
| hampi.jar | edu.stanford | hampi | 1.0.0 |
| iasolver.jar | gov.nasa.jpf.symbc | iasolver | 1.0.0 |
| string.jar | gov.nasa.jpf.symbc | string-solver | 1.0.0 |
| solver.jar | gov.nasa.jpf.symbc | solver | 1.0.0 |
| scale.jar | gov.nasa.jpf.symbc | scale | 1.0.0 |
| proteus.jar | gov.nasa.jpf.symbc | proteus | 1.0.0 |
| Statemachines.jar | gov.nasa.jpf.symbc | statemachines | 1.0.0 |
| STPJNI.jar | gov.nasa.jpf.symbc | stp-jni | 1.0.0 |
| yicesapijava.jar | gov.nasa.jpf.symbc | yices-api | 1.0.0 |
| libcvc3.jar | gov.nasa.jpf.symbc | cvc3-legacy | 1.0.0 |
| libcvc3-5.0.0.jar | gov.nasa.jpf.symbc | cvc3 | 5.0.0 |
| PathConditionsReliability-0.0.1.jar | gov.nasa.jpf.symbc | pc-reliability | 0.0.1 |
| grappa.jar | att.grappa | grappa | 1.0.0 |
| com.microsoft.z3.jar | com.microsoft | z3 | 4.8.14 |
| opt4j-2.4.jar | org.opt4j | opt4j | 2.4 |
| choco-1_2_04.jar | choco | choco-solver | 1.2.04 |
| choco-solver-2.1.1-*.jar | choco | choco-solver | 2.1.1 |

> **Nota:** Z3, Choco 1.2/2.1.1, e opt4j 2.4 **não foram encontrados no Maven Central** com as coordenadas originalmente planejadas. Todos devem ir para o `repo/` local.

**JARs COM equivalente verificado no Maven Central:**

| JAR atual | Maven Central (verificado) |
|-----------|---------------------------|
| commons-lang-2.4.jar | `org.apache.commons:commons-lang:2.4` |
| commons-math-1.2.jar | `org.apache.commons:commons-math:1.2` |
| bcel.jar | `org.apache.bcel:bcel:6.0` |
| automaton.jar | `dk.brics.automaton:automaton:1.11-8` |
| jaxen.jar | `jaxen:jaxen:1.2.0` |
| JSAP-2.1.jar | `com.martiansoftware:jsap:2.1` |
| aima-core.jar | `com.googlecode.aima-java:aima-core:0.10.5` |
| org.sat4j.core.jar | `org.ow2.sat4j:org.ow2.sat4j.core:2.3.6` |
| org.sat4j.pb.jar | `org.ow2.sat4j:org.ow2.sat4j.pb:2.3.6` |
| jedis-2.0.0.jar | `redis.clients:jedis:2.0.0` (verificar versão exata disponível) |

### 1.3 Pré-limpeza: remover import morto

Antes de mover arquivos, remover o import não utilizado em `BufferedImage.java`:

```java
// src/classes/java/awt/image/BufferedImage.java — linha 28
// REMOVER: import gov.nasa.jpf.symbc.Debug;  (código que usava está comentado)
```

### 1.4 Criar estrutura de diretórios

```
jpf-symbc/
├── pom.xml                                  ← Parent POM
├── repo/                                    ← Repositório Maven local do projeto
├── jpf.properties                           ← Atualizado para novos caminhos
├── lib/                                     ← Mantido (native libs .so/.dll/.dylib)
│
├── jpf-symbc-annotations/
│   ├── pom.xml
│   └── src/main/java/
│       └── gov/nasa/jpf/symbc/
│           ├── Concrete.java
│           ├── Partition.java
│           ├── Preconditions.java
│           └── Symbolic.java
│
├── jpf-symbc-main/
│   ├── pom.xml
│   └── src/main/java/
│       ├── gov/nasa/jpf/symbc/              ← src/main/ + src/peers/ (merged, sem conflitos verificados)
│       │   ├── SymbolicListener.java
│       │   ├── SymbolicInstructionFactory.java
│       │   ├── JPF_java_lang_Math.java      ← (vindo de src/peers/)
│       │   ├── JPF_gov_nasa_jpf_symbc_Debug.java  ← (vindo de src/peers/)
│       │   ├── bytecode/
│       │   ├── numeric/
│       │   ├── string/
│       │   ├── heap/
│       │   ├── arrays/
│       │   ├── concolic/
│       │   └── ...
│       ├── edu/ucsb/cs/vlab/
│       └── vlab/cs/ucsb/edu/
│
├── jpf-symbc-classes/
│   ├── pom.xml
│   ├── src/main/java/                       ← Classes regulares (compilação normal)
│   │   ├── gov/nasa/jpf/symbc/              (Debug, DNN, TestPC, TestUtils)
│   │   └── org/sosy_lab/sv_benchmarks/      (Verifier)
│   └── src/main/modules/                    ← Classes que overridam JDK (--patch-module)
│       ├── java.base/                       ← Módulo java.base
│       │   └── java/
│       │       ├── lang/Math.java
│       │       └── util/Scanner.java
│       └── java.desktop/                    ← Módulo java.desktop
│           └── java/
│               └── awt/image/
│                   ├── BufferedImage.java
│                   └── Kernel.java
│
├── jpf-symbc-tests/
│   ├── pom.xml
│   ├── src/test/java/                       ← src/tests/*.java (incluindo InvokeTest.java e ExSymExe*)
│   └── src/test/resources/                  ← src/tests/*.jpf (paths atualizados)
│
└── jpf-symbc-examples/
    ├── pom.xml
    ├── src/main/java/                       ← src/examples/*.java
    └── src/main/resources/                  ← src/examples/*.jpf (paths atualizados)
```

### 1.5 Parent POM (`pom.xml`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>gov.nasa.jpf</groupId>
    <artifactId>jpf-symbc-parent</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>pom</packaging>
    <name>JPF Symbolic PathFinder</name>

    <modules>
        <module>jpf-symbc-annotations</module>
        <module>jpf-symbc-main</module>
        <module>jpf-symbc-classes</module>
        <module>jpf-symbc-tests</module>
        <module>jpf-symbc-examples</module>
    </modules>

    <properties>
        <java.version>8</java.version>  <!-- Fase 1: Java 8; mudar para 11 na Fase 2 -->
        <maven.compiler.source>${java.version}</maven.compiler.source>
        <maven.compiler.target>${java.version}</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.build.resourceEncoding>UTF-8</project.build.resourceEncoding>
        <jpf-core.version>DEVELOPMENT-SNAPSHOT</jpf-core.version>
    </properties>

    <!--
        Usa ${maven.multiModuleProjectDirectory} para resolver o repo/ local
        corretamente a partir de qualquer submódulo (Maven 3.3.1+).
    -->
    <repositories>
        <repository>
            <id>project-local</id>
            <url>file://${maven.multiModuleProjectDirectory}/repo</url>
        </repository>
    </repositories>

    <dependencyManagement>
        <!-- Todas as dependências com versões centralizadas -->
    </dependencyManagement>

    <build>
        <pluginManagement>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-compiler-plugin</artifactId>
                    <version>3.11.0</version>
                    <configuration>
                        <source>${java.version}</source>
                        <target>${java.version}</target>
                        <debug>true</debug>
                        <showDeprecation>true</showDeprecation>
                    </configuration>
                </plugin>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-surefire-plugin</artifactId>
                    <version>3.2.5</version>
                </plugin>
            </plugins>
        </pluginManagement>
    </build>
</project>
```

### 1.6 Módulos — dependências

**jpf-symbc-annotations:** sem dependências externas

**jpf-symbc-main:**
- `gov.nasa.jpf:jpf-symbc-annotations` (módulo interno)
- `gov.nasa:jpf-core` (jpf-core oficial)
- Todos os solver JARs como `<optional>true</optional>`

**jpf-symbc-classes:**
- `gov.nasa.jpf:jpf-symbc-annotations`
- `gov.nasa:jpf-core` (necessário: Debug.java importa `gov.nasa.jpf.vm.Verify`)
- ~~`gov.nasa.jpf:jpf-symbc-main`~~ — **NÃO necessário** (verificado: nenhum import de src/main em src/classes)

**jpf-symbc-tests:**
- `gov.nasa.jpf:jpf-symbc-main`
- `gov.nasa.jpf:jpf-symbc-classes`
- `gov.nasa.jpf:jpf-symbc-annotations`
- `gov.nasa:jpf-core`
- `junit:junit:4.13.1` (test scope)

**jpf-symbc-examples:**
- `gov.nasa.jpf:jpf-symbc-main`
- `gov.nasa.jpf:jpf-symbc-classes`
- `gov.nasa.jpf:jpf-symbc-annotations`

### 1.7 Mover arquivos fonte

```bash
# Annotations
mkdir -p jpf-symbc-annotations/src/main/java
cp -r src/annotations/* jpf-symbc-annotations/src/main/java/

# Main + Peers (merge — verificado: sem conflitos de nomes entre os 7 peers e src/main)
mkdir -p jpf-symbc-main/src/main/java
cp -r src/main/* jpf-symbc-main/src/main/java/
cp -r src/peers/* jpf-symbc-main/src/main/java/

# Classes — separar por módulo Java
# 1) Classes regulares (gov.*, org.*)
mkdir -p jpf-symbc-classes/src/main/java
cp -r src/classes/gov jpf-symbc-classes/src/main/java/
cp -r src/classes/org jpf-symbc-classes/src/main/java/
# 2) Módulo java.base (Math, Scanner)
mkdir -p jpf-symbc-classes/src/main/modules/java.base/java/lang
mkdir -p jpf-symbc-classes/src/main/modules/java.base/java/util
cp src/classes/java/lang/Math.java jpf-symbc-classes/src/main/modules/java.base/java/lang/
cp src/classes/java/util/Scanner.java jpf-symbc-classes/src/main/modules/java.base/java/util/
# 3) Módulo java.desktop (BufferedImage, Kernel)
mkdir -p jpf-symbc-classes/src/main/modules/java.desktop/java/awt/image
cp src/classes/java/awt/image/BufferedImage.java jpf-symbc-classes/src/main/modules/java.desktop/java/awt/image/
cp src/classes/java/awt/image/Kernel.java jpf-symbc-classes/src/main/modules/java.desktop/java/awt/image/

# Tests (incluindo ExSymExe* e InvokeTest)
mkdir -p jpf-symbc-tests/src/test/java
mkdir -p jpf-symbc-tests/src/test/resources
find src/tests -name "*.java" | while read f; do
    rel="${f#src/tests/}"
    mkdir -p "jpf-symbc-tests/src/test/java/$(dirname "$rel")"
    cp "$f" "jpf-symbc-tests/src/test/java/$rel"
done
find src/tests -name "*.jpf" -exec cp {} jpf-symbc-tests/src/test/resources/ \;

# Examples
mkdir -p jpf-symbc-examples/src/main/java
mkdir -p jpf-symbc-examples/src/main/resources
find src/examples -name "*.java" | while read f; do
    rel="${f#src/examples/}"
    mkdir -p "jpf-symbc-examples/src/main/java/$(dirname "$rel")"
    cp "$f" "jpf-symbc-examples/src/main/java/$rel"
done
find src/examples -name "*.jpf" -exec cp {} jpf-symbc-examples/src/main/resources/ \;
```

### 1.8 Atualizar paths nos 152 arquivos .jpf

Todos os 152 arquivos `.jpf` (34 em tests, 118 em examples) referenciam `${jpf-symbc}/build/tests` ou `${jpf-symbc}/build/examples`. Esses paths devem ser atualizados para os diretórios Maven:

```bash
# Nos .jpf de tests:
# build/tests → jpf-symbc-tests/target/test-classes
# src/tests   → jpf-symbc-tests/src/test/java
find jpf-symbc-tests/src/test/resources -name "*.jpf" -exec sed -i \
    -e 's|build/tests|jpf-symbc-tests/target/test-classes|g' \
    -e 's|src/tests|jpf-symbc-tests/src/test/java|g' {} \;

# Nos .jpf de examples:
# build/examples → jpf-symbc-examples/target/classes
# src/examples   → jpf-symbc-examples/src/main/java
find jpf-symbc-examples/src/main/resources -name "*.jpf" -exec sed -i \
    -e 's|build/examples|jpf-symbc-examples/target/classes|g' \
    -e 's|src/examples|jpf-symbc-examples/src/main/java|g' {} \;
```

> **Verificação pós-sed (obrigatória):**

```bash
# 1. Listar .jpf que NÃO foram atualizados (possíveis exceções ao padrão)
grep -rL 'target/' jpf-symbc-tests/src/test/resources/*.jpf || echo "Todos atualizados"
grep -rL 'target/' jpf-symbc-examples/src/main/resources/*.jpf || echo "Todos atualizados"

# 2. Listar .jpf que ainda referenciam paths antigos (deveria retornar vazio)
grep -rl 'build/tests\|build/examples' jpf-symbc-tests/ jpf-symbc-examples/ || echo "OK: nenhum path antigo"

# 3. Verificar .jpf com referências a native_classpath ou paths absolutos (tratar manualmente)
grep -rl 'native_classpath=.*git\|native_classpath=.*home' jpf-symbc-tests/ jpf-symbc-examples/
```

> **Nota:** Alguns .jpf podem ter referências adicionais como `native_classpath=../../git/...` que precisam atenção individual.

### 1.9 Tratar arquivos ExSymExe* (129 arquivos)

Existem **129 arquivos `ExSymExe*.java`** em `src/tests/` (incluindo sub-pacotes como `strings/`). Eles NÃO são testes JUnit — são programas de demonstração com `main()` executáveis via JPF. Opções:

**Decisão: manter em jpf-symbc-tests mas excluir do surefire.** Eles compilam como parte dos testes (para validar que o código compila) mas não são executados automaticamente. A exclusão é implícita pois o surefire usa `<include>**/Test*.java</include>` e `ExSymExe*` não segue esse padrão.

### 1.10 Validação

```bash
mvn clean compile
```

Critério de sucesso: todos os 5 módulos compilam sem erro.

---

## Fase 2: Migração Java 8 → Java 11

> Objetivo: Compilar e testar com Java 11. Requer configuração de --patch-module, --add-reads, e --add-opens.

### 2.1 Atualizar versão Java no parent POM

```xml
<java.version>11</java.version>
```

### 2.2 Compilar model classes com --patch-module (3 execuções)

No `jpf-symbc-classes/pom.xml`, o `maven-compiler-plugin` precisa de **3 execuções** em ordem:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <executions>
        <!--
            Execução 1 (default-compile): Compila classes regulares (gov/, org/)
            Isso inclui Debug.java que é importado por Scanner.java na execução 2.
            Usa a configuração padrão do pluginManagement (source/target 11).
        -->

        <!--
            Execução 2: Compila classes do módulo java.base (Math, Scanner)
            Scanner.java importa gov.nasa.jpf.symbc.Debug → precisa --add-reads
            Deve rodar DEPOIS da execução default para que Debug.class esteja disponível.
        -->
        <execution>
            <id>compile-patch-java-base</id>
            <phase>compile</phase>
            <goals><goal>compile</goal></goals>
            <configuration>
                <compileSourceRoots>
                    <compileSourceRoot>${project.basedir}/src/main/modules/java.base</compileSourceRoot>
                </compileSourceRoots>
                <compilerArgs>
                    <arg>--patch-module</arg>
                    <arg>java.base=${project.basedir}/src/main/modules/java.base</arg>
                    <arg>--add-reads</arg>
                    <arg>java.base=ALL-UNNAMED</arg>
                </compilerArgs>
            </configuration>
        </execution>

        <!--
            Execução 3: Compila classes do módulo java.desktop (BufferedImage, Kernel)
            Kernel.java não tem dependências cruzadas.
            BufferedImage.java teve import de Debug REMOVIDO (era código morto).
        -->
        <execution>
            <id>compile-patch-java-desktop</id>
            <phase>compile</phase>
            <goals><goal>compile</goal></goals>
            <configuration>
                <compileSourceRoots>
                    <compileSourceRoot>${project.basedir}/src/main/modules/java.desktop</compileSourceRoot>
                </compileSourceRoots>
                <compilerArgs>
                    <arg>--patch-module</arg>
                    <arg>java.desktop=${project.basedir}/src/main/modules/java.desktop</arg>
                </compilerArgs>
            </configuration>
        </execution>
    </executions>
</plugin>
```

**Referência:** jpf-core usa este padrão em `gradle/source-sets.gradle` linhas 42-60 e `build.gradle` task `compileModules`.

### 2.3 Configurar --add-exports para peers (se necessário)

Verificar se os peers em `jpf-symbc-main` usam APIs internas do JDK. Se sim, no `jpf-symbc-main/pom.xml`:

```xml
<compilerArgs>
    <arg>--add-exports</arg>
    <arg>java.base/jdk.internal.misc=ALL-UNNAMED</arg>
</compilerArgs>
```

### 2.4 Configurar testes com --add-opens

No `jpf-symbc-tests/pom.xml`, plugin surefire:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <argLine>
            -Xmx1024m
            --add-opens java.base/java.lang=ALL-UNNAMED
            --add-opens java.base/java.util=ALL-UNNAMED
            --add-exports java.base/jdk.internal.misc=ALL-UNNAMED
            --add-opens java.base/jdk.internal.misc=ALL-UNNAMED
        </argLine>
    </configuration>
</plugin>
```

**Referência:** jpf-core `build.gradle` parallelTest/singleThreadTest jvmArgs.

### 2.5 Verificar compatibilidade de bibliotecas

> Resultados do smoke test da Fase 0.3 devem guiar esta etapa.

Testar compilação e runtime de cada solver com Java 11:
- **Z3**: Versões recentes (4.8+) suportam Java 11. O JAR em `lib/` pode funcionar; se não, atualizar para versão recente.
- **Choco, SAT4J**: JARs pure-Java — geralmente funcionam com Java 11 sem problemas.
- **Native libs (.so/.dll)**: Resultados do smoke test (Fase 0.3) determinam quais solvers JNI funcionam. Libs compiladas há anos contra JDK/glibc antigos podem falhar com `UnsatisfiedLinkError`. Para solvers que falharam no smoke test, avaliar: (a) atualizar para versão mais recente, (b) recompilar a partir do fonte, ou (c) desabilitar o solver.

### 2.6 Validação

```bash
# Com Java 11 no JAVA_HOME
mvn clean compile
mvn test   # Pode ter falhas de runtime — tratar na Fase 3
```

---

## Fase 3: Testes e Compatibilidade com jpf-core oficial

> Objetivo: Garantir que os testes passam e que a integração com JPF funciona.

### 3.1 Corrigir erros de API entre fork e jpf-core oficial

Compilar contra `gov.nasa:jpf-core:DEVELOPMENT-SNAPSHOT` e corrigir erros. Áreas de risco:

| Classe JPF | Uso no jpf-symbc | Risco |
|------------|------------------|-------|
| `InstructionFactory` | Base de `SymbolicInstructionFactory` | ALTO — mudanças de assinatura possíveis |
| `ClassInfoFilter` | Filtro de classes no `SymbolicInstructionFactory` | MÉDIO |
| `PropertyListenerAdapter` | Base de `SymbolicListener` | BAIXO — interface estável |
| `VM`, `ThreadInfo`, `StackFrame` | Usado em 46+ imports | MÉDIO — core API |
| `MJIEnv`, `NativePeer` | Base dos peers | BAIXO |

### 3.2 Configurar exclusões de testes no surefire

Migrar exclusões do `build.xml` (linhas 251-269):

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <forkCount>1</forkCount>
        <reuseForks>false</reuseForks>
        <argLine>
            -Xmx1024m
            --add-opens java.base/java.lang=ALL-UNNAMED
            --add-opens java.base/java.util=ALL-UNNAMED
            --add-exports java.base/jdk.internal.misc=ALL-UNNAMED
            --add-opens java.base/jdk.internal.misc=ALL-UNNAMED
        </argLine>
        <includes>
            <include>**/Test*.java</include>
        </includes>
        <excludes>
            <exclude>**/JPF_*.java</exclude>
            <exclude>**/TestBitwise*.java</exclude>
            <exclude>**/TestCoverage.java</exclude>
            <exclude>**/TestDIV.java</exclude>
            <exclude>**/TestExJPF.java</exclude>
            <exclude>**/TestLazy*.java</exclude>
            <exclude>**/TestPathCondition.java</exclude>
            <exclude>**/TestStringBuilder.java</exclude>
            <exclude>**/strings/**</exclude>
            <exclude>**/TestSymbolicListener.java</exclude>
            <exclude>**/TestSymbolicOutput.java</exclude>
            <exclude>**/TestSymbolicJPF.java</exclude>
        </excludes>
    </configuration>
</plugin>
```

> **Nota:** Os 129 arquivos `ExSymExe*.java` não precisam de exclusão explícita pois não seguem o padrão `Test*`.

### 3.3 Atualizar jpf.properties e arquivos .jpf

**jpf.properties (raiz):**

```properties
jpf-symbc = ${config_path}

jpf-symbc.native_classpath=\
  ${jpf-symbc}/jpf-symbc-main/target/jpf-symbc-main-1.0.0-SNAPSHOT.jar;\
  ${jpf-symbc}/jpf-symbc-annotations/target/jpf-symbc-annotations-1.0.0-SNAPSHOT.jar;\
  ... (solver JARs — manter referências ao repo/ ou lib/)

jpf-symbc.classpath=\
  ${jpf-symbc}/jpf-symbc-classes/target/jpf-symbc-classes-1.0.0-SNAPSHOT.jar

jpf-symbc.test_classpath=\
  ${jpf-symbc}/jpf-symbc-tests/target/test-classes

jpf-symbc.peer_packages = gov.nasa.jpf.symbc
jvm.insn_factory.class=gov.nasa.jpf.symbc.SymbolicInstructionFactory
vm.storage.class=nil
```

**Alternativa (recomendada):** Usar `maven-dependency-plugin` para copiar os JARs produzidos para `build/`, mantendo backward compatibility com jpf.properties e .jpf files:

```xml
<!-- No parent POM, após mvn package: -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-dependency-plugin</artifactId>
    <executions>
        <execution>
            <id>copy-module-jars</id>
            <phase>package</phase>
            <goals><goal>copy</goal></goals>
            <configuration>
                <artifactItems>
                    <!-- Copiar JARs dos módulos para build/ na raiz -->
                </artifactItems>
                <outputDirectory>${maven.multiModuleProjectDirectory}/build</outputDirectory>
            </configuration>
        </execution>
    </executions>
</plugin>
```

### 3.4 Validação

```bash
mvn clean test
# Executar um exemplo simples para validar integração:
# java -jar path/to/RunJPF.jar src/examples/demo/NumericExample.jpf
```

---

## Fase 4: Cleanup e Documentação

### 4.1 Remover artefatos obsoletos

| Arquivo/Diretório | Ação |
|-------------------|------|
| `build.xml` | Remover |
| `.classpath` | Remover |
| `.project` | Remover |
| `nbproject/` | Remover |
| `.externalToolBuilders/` | Remover |
| `src/` (original) | Remover após confirmar migração completa |

### 4.2 Manter

| Arquivo/Diretório | Razão |
|-------------------|-------|
| `lib/` | Bibliotecas nativas (.so, .dll, .dylib) necessárias em runtime |
| `jpf.properties` | Integração JPF |
| `LICENSE-2.0.txt` | Licença |

### 4.3 Atualizar documentação

- **README.md** — Novos pré-requisitos (Java 11, jpf-core local), novos comandos Maven
- **CLAUDE.md** — Comandos atualizados (`mvn compile`, `mvn test`, `mvn package`)

---

## Arquivos Críticos

| Arquivo | Ação | Notas |
|---------|------|-------|
| `NativeLibSmokeTest.java` | Criar (temporário) | Fase 0.3 — smoke test JNI; remover após validação |
| `pom.xml` (raiz) | Criar | Parent POM com modules e dependencyManagement |
| `jpf-symbc-annotations/pom.xml` | Criar | Sem dependências externas |
| `jpf-symbc-main/pom.xml` | Criar | Dependências de todos os solvers (optional) |
| `jpf-symbc-classes/pom.xml` | Criar | 3 execuções compiler: regular + java.base + java.desktop |
| `jpf-symbc-tests/pom.xml` | Criar | Surefire com exclusões e --add-opens |
| `jpf-symbc-examples/pom.xml` | Criar | Dependências dos módulos internos |
| `repo/` | Criar | ~19 JARs instalados localmente |
| `jpf.properties` | Editar | Novos caminhos de JARs Maven |
| `152 arquivos .jpf` | Editar | Atualizar paths build/tests → target/test-classes etc. |
| `BufferedImage.java` | Editar | Remover import morto de Debug |
| `README.md` | Editar | Instruções de build atualizadas |
| `CLAUDE.md` | Editar | Comandos Maven |
| `build.xml` | Remover | Fase 4 |
| `.classpath`, `.project` | Remover | Fase 4 |
| `nbproject/` | Remover | Fase 4 |

---

## Riscos e Mitigações

| Risco | Impacto | Probabilidade | Mitigação |
|-------|---------|---------------|-----------|
| Model classes `java.*` não compilam com `--patch-module` | ALTO | Baixa | Seguir padrão exato do jpf-core; separar java.base e java.desktop |
| API incompatível entre fork yannicnoller e jpf-core oficial | **ALTO** | Média | **Fase 0.4:** quantificar divergência com git diff antes de começar; foco em `InstructionFactory`, `ClassInfo`, `MethodInfo` |
| Ordem de compilação no maven-compiler-plugin | MÉDIO | Média | Garantir que default-compile roda antes das execuções patch-module |
| JARs antigos de solvers incompatíveis com Java 11 | MÉDIO | Média | **Fase 0.3:** smoke test JNI com JDK 11 antes de investir na migração |
| 152 arquivos .jpf com paths desatualizados | MÉDIO | Alta | Script sed automatizado + **verificação pós-sed obrigatória** (grep -rL) |
| Native libs (.so) incompatíveis com JDK 11 / glibc moderno | **MÉDIO** | **Média** | **Fase 0.3:** smoke test System.loadLibrary com JDK 11; libs foram compiladas há anos contra JDK/glibc específicos |
| Testes falham por mudança de comportamento do jpf-core | MÉDIO | Média | Analisar falhas caso a caso; atualizar testes se necessário |
| ClassLoader JPF + module system Java 11 (novo) | **MÉDIO** | Média | JPF usa class loaders customizados; interação com module path pode causar `ClassNotFoundException` em runtime. Testar end-to-end na Fase 3 |

---

## Verificação End-to-End

1. **Compilação:** `mvn clean compile` — todos os 5 módulos compilam sem erro
2. **Testes:** `mvn test` — testes não-excluídos passam
3. **Packaging:** `mvn package` — 5 JARs produzidos corretamente
4. **Integração JPF:** Executar exemplo `.jpf` simples via JPF com jpf-symbc migrado
5. **Solver:** Executar teste que usa Z3 como decision procedure para validar integração

---

## Ordem de Execução Recomendada

```
Fase 0.1   git tag pre-migration-java11 (safety net)
Fase 0.2   Instalar jpf-core + VERIFICAR coordenadas Maven exatas
Fase 0.3   Smoke test JNI: Z3/CVC3/STP/Yices com JDK 11 → decisão go/no-go
Fase 0.4   git diff fork↔oficial nas APIs usadas por jpf-symbc → estimar esforço Fase 3
    ↓ (go/no-go: se Z3 falhar no smoke test, investigar antes de prosseguir)
Fase 1.1   Criar repo/ com JARs de pesquisa (~19 JARs)
Fase 1.2   Remover import morto em BufferedImage.java
Fase 1.3   Criar estrutura de diretórios Maven
Fase 1.4   Criar POMs (parent + 5 módulos)
Fase 1.5   Mover arquivos fonte
Fase 1.6   Atualizar 152 arquivos .jpf (paths) + verificação pós-sed
Fase 1.7   Validar: mvn compile (Java 8)
    ↓
Fase 2.1   Mudar java.version para 11
Fase 2.2   Configurar 3 execuções compiler em jpf-symbc-classes
Fase 2.3   Configurar --add-exports/--add-opens
Fase 2.4   Verificar compatibilidade de libs
Fase 2.5   Validar: mvn compile (Java 11)
    ↓
Fase 3.1   Corrigir erros de API jpf-core (escopo estimado na Fase 0.4)
Fase 3.2   Configurar exclusões de testes (surefire)
Fase 3.3   Atualizar jpf.properties
Fase 3.4   Validar: mvn test + exemplo JPF
    ↓
Fase 4.1   Remover artefatos obsoletos
Fase 4.2   Atualizar documentação
Fase 4.3   Validar: build limpo completo
```

---

## Changelog

### Revisão 2 (27/02/2026) — Incorporação de feedback externo

Análises de Gemini e Qwen foram avaliadas. Mudanças aplicadas:

| Mudança | Origem | Justificativa |
|---------|--------|---------------|
| **Nova Fase 0** com validação de riscos bloqueadores | Gemini (Fase 0), Qwen (#1, #6, #28) | Detectar bloqueadores (JNI, coordenadas Maven, divergência fork) antes de investir na migração |
| **Fix dependências jpf-symbc-classes**: removida dependência em jpf-symbc-main | Verificação empírica (0 imports de src/main em src/classes) | Simplifica grafo de dependências; classes só depende de annotations + jpf-core |
| **Tabela de riscos atualizada**: native libs BAIXO→MÉDIO, fork divergência MÉDIO→ALTO, novo risco ClassLoader+modules | Gemini (3.1), Qwen (3.1) | Ratings originais eram otimistas demais |
| **ExSymExe count**: 60→129 | Qwen (#20), verificado empiricamente | Correção factual |
| **Verificação pós-sed obrigatória** nos 152 .jpf | Gemini (recomendação 5), Qwen (#17) | grep -rL para pegar arquivos não atualizados |
| **libcvc3 artifactIds distintos**: cvc3-legacy (1.0.0) e cvc3 (5.0.0) | Qwen (#3) | São dois JARs diferentes, precisam artifactIds únicos |
| **resourceEncoding UTF-8** no parent POM | Qwen (#11) | Boa prática para arquivos .jpf |
| **git tag** como safety net antes da migração | Qwen (#38) | Barato e comunicativo |

**Sugestões descartadas** (over-engineering para este projeto):
maven-enforcer-plugin, maven-failsafe-plugin, jacoco, source/javadoc JARs, documentação de proveniência dos JARs, versão específica em vez de DEVELOPMENT-SNAPSHOT, validação formal de IDE, CI/CD (não existe).
