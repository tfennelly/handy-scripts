#!/bin/bash

if [ "$CATALINA_HOME" == "" ]; then
  echo "*** CATALINA_HOME env variable not set."
  exit 1
fi

pushd $CATALINA_HOME/bin

# Try stopping catalina properly first
./catalina.sh stop

# Give the process a few seconds to  stop
sleep 5

# Now look for any zombie processes and kill them
procIds=$(jps -l | grep org.apache.catalina.startup.Bootstrap | sed 's/\([0-9]*\) org\.apache\.catalina\.startup\.Bootstrap/\1/g')
read -a procIdArray <<< $procIds

for procId in "${procIdArray[@]}"
do
  echo "Killing $procId"
  kill -9 $procId
done

# Restart catalina
./catalina.sh start

popd
