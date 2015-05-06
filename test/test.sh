#!/bin/bash

currDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
srcDIR=$(dirname $currDIR)'/src'
echo 'srcDIR = '$srcDIR

[[ $PYTHONPATH == *"${srcDIR}"* ]] || {
echo 'adding srcDIR = ' $srcDIR ' to $PYTHONPATH'
export PYTHONPATH=$PYTHONPATH:$srcDIR
}
echo "PYTHONPATH="$PYTHONPATH

python "$currDIR/sample/pyiptdocker_template_test.py"