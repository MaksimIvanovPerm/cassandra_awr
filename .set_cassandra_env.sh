#!/bin/bash

export JAVA_HOME=/home/cassandra/java-se-8u40-ri/
export PATH=$JAVA_HOME/bin:$PATH
export CASSANDRA_HOME=/home/cassandra/apache-cassandra-3.11.4
export PATH=$CASSANDRA_HOME/bin:$PATH
export CASSANDRA_PORT=7842
export CASSANDRA_HOST="127.0.0.1"
export SQLITEDB="sqlite3 $CASSANDRA_HOME/metrics/scripts/metricdb"

