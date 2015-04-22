#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
SRC_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/../src/"

TEMPLATE_FILE="${DIR}/template_sample.sh"

[ -d $SRC_DIR ] || {
echo '[FATAL] source dir not found : '$SRC_DIR
exit 1
}

[ -f $TEMPLATE_FILE ] || {
echo '[FATAL] template file not found : '$TEMPLATE_FILE
exit 1
}

/bin/bash "${SRC_DIR}/ipth-executor.sh" "${SRC_DIR}/ipth.sh"  "${TEMPLATE_FILE}" "enable"

iptables -L -v -n

echo "\n now disable.. "

/bin/bash "${SRC_DIR}/ipth-executor.sh" "${SRC_DIR}/ipth.sh"  "${TEMPLATE_FILE}" "disable"
iptables -L -v -n




