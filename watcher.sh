#!/bin/bash

SET_ENV_SCRIPT="/home/cassandra/.set_cassandra_env.sh"
#PIDFILE=`dirname $0`/watcher.pid

if [ ! -f "$SET_ENV_SCRIPT" ]
then
 exit 1
else
 . "$SET_ENV_SCRIPT"
fi

cd /
DELTA="60"
tail -n 1 -f $CASSANDRA_HOME/metrics/data/metrics.dat | awk -v dt=$DELTA -f $CASSANDRA_HOME/metrics/scripts/watcher.awk | egrep -E "^[[:digit:]]+:[[:alnum:][:space:]]" | awk -v label="MDg5YWQ2YWFlNGFmYz12" -v dir="$CASSANDRA_HOME/metrics/in" -F ":" '{filename=dir"/"$1; printf "%s\n", $0; printf "%s\n", $0 > filename;}'
