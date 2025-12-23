#!/bin/bash
#
# Test the JMeter Docker image using a trivial test plan.

# =============== ENV VARIABLES ===============
export TARGET_PROTOCOL="https"
export TARGET_HOST="appcrm.datacrm.la"
export TARGET_PORT="443"
export TARGET_PATH="/datacrm/cpuniminuto/index.php"
export TARGET_KEYWORD="DataCRM"
export JM_USERNAME="ahurtado"
export JM_PASSWORD="12345678"

T_DIR=tests/trivial

# =============== FIX: REMOVE OLD JMETER CONTAINER ===============
# Avoid "Conflict. The container name jmeter is already in use"
docker rm -f jmeter 2>/dev/null || true

# =============== CLEAN REPORT DIR ===============
R_DIR=${T_DIR}/report
rm -rf ${R_DIR} > /dev/null 2>&1
mkdir -p ${R_DIR}

/bin/rm -f ${T_DIR}/test-plan.jtl ${T_DIR}/jmeter.log > /dev/null 2>&1

# =============== EXECUTE JMETER THROUGH run.sh ===============
./run.sh -Dlog_level.jmeter=DEBUG \
  -JTARGET_HOST=${TARGET_HOST} \
  -JTARGET_PORT=${TARGET_PORT} \
  -JTARGET_PATH=${TARGET_PATH} \
  -JTARGET_KEYWORD=${TARGET_KEYWORD} \
  -n -t ${T_DIR}/test-plan.jmx \
  -l ${T_DIR}/test-plan.jtl \
  -j ${T_DIR}/jmeter.log \
  -e -o ${R_DIR}

# =============== REPORT OUTPUT ===============
echo "==== jmeter.log ===="
cat ${T_DIR}/jmeter.log

echo "==== Raw Test Report ===="
cat ${T_DIR}/test-plan.jtl

echo "==== HTML Test Report ===="
echo "See HTML test report in ${R_DIR}/index.html"
