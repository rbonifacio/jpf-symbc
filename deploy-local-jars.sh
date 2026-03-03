#!/bin/bash
# Script to deploy 20 non-Central JARs into repo/ local Maven repository
# and verify all 28 JARs (20 local + 8 Central) are resolvable.
#
# Tasks 1.2, 1.3, 1.4 of the Maven migration (Group 1)
#
# Usage:
#   bash deploy-local-jars.sh          # Full deploy + verify
#   bash deploy-local-jars.sh verify   # Only verify (skip deploy)
#
# NOTE: The repo/ directory structure has already been created manually
# (mkdir + cp + POM/metadata XML files). Running this script with
# mvn deploy:deploy-file will add hash files (.md5, .sha1) for completeness,
# but they are NOT required for file:// repository resolution.

set -e

export JAVA_HOME=/home/pedro/.sdkman/candidates/java/8.0.302-open
export PATH=$JAVA_HOME/bin:$PATH

BASEDIR=/pedro/desenvolvimento/workspaces/workspaces-doutorado/workspace-rv/jpf-symbc
REPO_URL="file://${BASEDIR}/repo"
cd "$BASEDIR"

echo "=== Java version ==="
java -version 2>&1

echo ""
echo "=== Maven version ==="
mvn --version 2>&1 | head -3

VERIFY_ONLY=false
if [ "${1}" = "verify" ]; then
  VERIFY_ONLY=true
  echo ""
  echo "=== VERIFY-ONLY MODE (skipping deploy) ==="
fi

# ============================================================
# Task 1.2: Deploy 20 JARs (skip if verify-only)
# ============================================================
if [ "$VERIFY_ONLY" = false ]; then
  echo ""
  echo "=== Task 1.2: Deploying 20 JARs to local repo ==="

  deploy_jar() {
    local file="$1" groupId="$2" artifactId="$3" version="$4"
    echo "  Deploying: ${groupId}:${artifactId}:${version} from lib/${file}"
    mvn -q deploy:deploy-file \
      -Durl="${REPO_URL}" \
      -DrepositoryId=local-repo \
      -Dfile="lib/${file}" \
      -DgroupId="${groupId}" \
      -DartifactId="${artifactId}" \
      -Dversion="${version}" \
      -Dpackaging=jar \
      -DgeneratePom=true
  }

  deploy_jar "coral.jar"                                  "com.ufpe"     "coral"          "0.7"
  deploy_jar "green.jar"                                  "za.ac.sun"    "green"          "1.0"
  deploy_jar "hampi.jar"                                  "edu.stanford" "hampi"          "1.0"
  deploy_jar "iasolver.jar"                               "com.iastate"  "iasolver"       "1.0"
  deploy_jar "libcvc3.jar"                                "edu.nyu"      "libcvc3"        "2.3.0"
  deploy_jar "libcvc3-5.0.0.jar"                          "edu.nyu"      "libcvc3"        "5.0.0"
  deploy_jar "com.microsoft.z3.jar"                       "com.microsoft" "z3"            "4.8.14"
  deploy_jar "choco-1_2_04.jar"                           "choco"        "choco"          "1.2.04"
  deploy_jar "choco-solver-2.1.1-20100709.142532-2.jar"   "choco"        "choco-solver"   "2.1.1"
  deploy_jar "opt4j-2.4.jar"                              "org.opt4j"    "opt4j"          "2.4"
  deploy_jar "grappa.jar"                                 "att.research" "grappa"         "1.0"
  deploy_jar "org.sat4j.core.jar"                         "org.sat4j"    "org.sat4j.core" "CUSTOM-20100705"
  deploy_jar "org.sat4j.pb.jar"                           "org.sat4j"    "org.sat4j.pb"   "CUSTOM-20100705"
  deploy_jar "scale.jar"                                  "edu.ucsb"     "scale"          "1.0"
  deploy_jar "solver.jar"                                 "edu.ucsb"     "solver"         "1.0"
  deploy_jar "string.jar"                                 "edu.ucsb"     "string"         "1.0"
  deploy_jar "proteus.jar"                                "edu.ucsb"     "proteus"        "1.0"
  deploy_jar "Statemachines.jar"                          "edu.ucsb"     "statemachines"  "1.0"
  deploy_jar "STPJNI.jar"                                 "org.stp"      "stpjni"         "1.0"
  deploy_jar "yicesapijava.jar"                           "edu.sri"      "yicesapijava"   "1.0"

  echo ""
  echo "=== All 20 JARs deployed successfully ==="
fi

# ============================================================
# Task 1.3: Verify repo/ structure
# ============================================================
echo ""
echo "=== Task 1.3: Verifying repo/ directory structure ==="
echo ""
echo "--- JARs in repo/ ---"
find repo -type f -name "*.jar" | sort
JAR_COUNT=$(find repo -type f -name "*.jar" | wc -l)
echo ""
echo "JAR count: ${JAR_COUNT} (expected: 20)"
POM_COUNT=$(find repo -type f -name "*.pom" | wc -l)
echo "POM count: ${POM_COUNT} (expected: 20)"

if [ "$JAR_COUNT" -eq 20 ] && [ "$POM_COUNT" -ge 20 ]; then
  echo "PASS: repo/ structure is correct"
else
  echo "FAIL: repo/ structure is incomplete"
  exit 1
fi

# ============================================================
# Task 1.3 continued: Verify local repo JARs resolve
# ============================================================
echo ""
echo "=== Task 1.3 (resolve): Verifying 20 local repo JARs resolve ==="
mvn -f verify-local-repo-deps.xml dependency:resolve 2>&1 | tail -5
if [ ${PIPESTATUS[0]} -eq 0 ]; then
  echo "PASS: All local repo JARs resolve"
else
  echo "FAIL: Some local repo JARs did not resolve"
  exit 1
fi

# ============================================================
# Task 1.4: Verify 8 Maven Central coordinates resolve
# ============================================================
echo ""
echo "=== Task 1.4: Verifying 8 Maven Central coordinates resolve ==="
mvn -f verify-central-deps.xml dependency:resolve 2>&1 | tail -10
if [ ${PIPESTATUS[0]} -eq 0 ]; then
  echo "PASS: All 8 Maven Central JARs resolve"
else
  echo "FAIL: Some Maven Central JARs did not resolve"
  exit 1
fi

echo ""
echo "=========================================="
echo "  GROUP 1 COMPLETE - ALL TASKS PASSED"
echo "=========================================="
