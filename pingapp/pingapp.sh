#!/bin/bash

#determine script location
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-in/179231#179231
SCRIPT_PATH="${BASH_SOURCE[0]}";
if([ -h "${SCRIPT_PATH}" ]) then
  while([ -h "${SCRIPT_PATH}" ]) do SCRIPT_PATH=`readlink "${SCRIPT_PATH}"`; done
fi
pushd . > /dev/null
cd `dirname ${SCRIPT_PATH}` > /dev/null
SCRIPT_PATH=`pwd`;
popd  > /dev/null
#

export PYTHONPATH=

# Serial connection library
export PYTHONPATH=$PYTHONPATH:"connection library location placeholder ... TODO"

# argconfparse and logging setup
export PYTHONPATH=$PYTHONPATH:$SCRIPT_PATH/../python-stuff

python pingapp.py $@
