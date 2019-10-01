#!/bin/bash


# Source function library.
#. /etc/init.d/functions

BASE_DIR="/home/cassandra/apache-cassandra-3.11.4/metrics/scripts"
PIDFILE=$BASE_DIR/watcher.pid
SET_ENV_SCRIPT="/home/cassandra/.set_cassandra_env.sh"
EXEFILE=$BASE_DIR/watcher.sh

if [ ! -f "$EXEFILE" ]
then
 echo "ERR: $EXEFILE is absent or not a file"
 exit 1
fi

if [ -f "$SET_ENV_SCRIPT" ]
then
 . "$SET_ENV_SCRIPT"
else
 echo "ERR: ${SET_ENV_SCRIPT} is absent or not a file"
 exit 2
fi

################################################################################
### Sub routine  ###############################################################
start() {
local v_pid v_ppid

if [ -f "$PIDFILE" ]
then
 echo "ERR: by pidfile (${PIDFILE}) watcher is already running, proces-pids list:"
 cat $PIDFILE
 exit 3
else
 (nohup "$EXEFILE" &>/dev/null & ) &>/dev/null
 v_pid=""
 v_ppid=""
 v_pid=`ps aux | grep "[M]Dg5YWQ2YWFlNGFmYz12" | awk '{printf "%d", $2}'`
 if [ ! -z "$v_pid" ]
 then
  v_ppid=`cat /proc/${v_pid}/status | grep -i "ppid" | awk '{printf "%d", $2}'`
  echo $v_ppid > "$PIDFILE"
  pgrep -P $v_ppid >> "$PIDFILE"
 fi
fi
return 0
}

status() {
# 0 - means absence
# 1 - means presence
local v_pidfile_is="0"
local v_processes_are="0"
local v_pid v_ppid 

 [ -f "$PIDFILE" ] && v_pidfile_is="1"

 v_pid=""
 v_ppid=""
 v_pid=`ps aux | grep "[M]Dg5YWQ2YWFlNGFmYz12" | awk '{printf "%d", $2}'`
 if [ ! -z "$v_pid" ]
 then
  v_processes_are="1"
  v_ppid=`cat /proc/${v_pid}/status | grep -i "ppid" | awk '{printf "%d", $2}'`
  [ -z "$v_ppid" ] && v_ppid="v_pid"
 fi
 
 if [ "$v_pidfile_is" == "0" -a "$v_processes_are" == "0" ]
 then
  echo "OK: not started and no pidfile (${PIDFILE})"
  return 0
 fi

 if [ "$v_pidfile_is" == "0" -a "$v_processes_are" == "1" ]
 then
  echo "ERR: PIDFILE (${PIDFILE}) is absent, but processes are started"
  pgrep -a -P "$v_ppid"
  return 1
 fi

 if [ "$v_pidfile_is" == "1" -a "$v_processes_are" == "0" ]
 then
  echo "ERR: PIDFILE (${PIDFILE}) exists, but processes are not started"
  return 1
 fi

 if [ "$v_pidfile_is" == "1" -a "$v_processes_are" == "1" ]
 then
  echo "PIDFILE (${PIDFILE}) exists, and processes are started"
  v_spid=`cat ${PIDFILE} | head -n 1`
  if [ "$v_spid" != "$v_ppid" ]
  then
   echo "ERR: but they are about different proceses"
   echo "PIDFILE (${PIDFILE}):"
   cat "$PIDFILE"
   echo "processes stack are:"
   pgrep -a -P "$v_ppid"
   return 1
  else
   echo "OK: and they say about the same proceses"
   return 0
  fi
 fi

}

stop() {
local v_pid v_ppid 
v_pid=""
v_ppid=""
v_pid=`ps aux | grep "[M]Dg5YWQ2YWFlNGFmYz12" | awk '{printf "%d", $2}'`
if [ ! -z "$v_pid" ]
then
 v_ppid=`cat /proc/${v_pid}/status | grep -i "ppid" | awk '{printf "%d", $2}'`
 echo $v_ppid > /tmp/temp.dat
 pgrep -P $v_ppid >> /tmp/temp.dat
 cat /tmp/temp.dat | xargs kill -9 &>/dev/null
fi
[ -f "$PIDFILE" ] && rm -f "$PIDFILE"
}
### Main routine ###############################################################

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Usage: `basename $0` {start|stop|status|restart}"
        exit 1
        ;;
esac
exit $?
