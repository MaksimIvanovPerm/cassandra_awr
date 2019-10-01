#!/bin/bash
LOG_FILE="/tmp/logfile.log"
LOCK_FILE="/tmp/lock_file.log"
export LC_NUMERIC=C

#### Subroutines ####
logger() {
 local v_timestamp=`date +%s`
 local v_msg="$1"
 echo "${v_timestamp}:${v_id} ${v_msg}" >> $LOG_FILE
}

parse_file() {
local v_metric_id v_rc v_sep v_name v_value v_unit i v_line
local v_source="$1"

cat /dev/null > /tmp/temp.sql
v_metric_id=""
echo "delete from temp_data;" | $SQLITEDB
while read line
do
 v_string=`echo -n $line | cut -d ":" -f 2`
 v_rc=`echo "select count(*) from metric_name where name='${v_string}';" | $SQLITEDB`
 if [ "$v_rc" -eq "1" ]
 then
  # metric
  v_metric_id=`echo "select id from metric_name where name='${v_string}';" | $SQLITEDB`
  v_attr_count=`echo "select count(*) from metric_description where metric_id=${v_metric_id};" | $SQLITEDB`
  echo "$v_string ($v_metric_id) ($v_attr_count)"
  for ((i=1; i<=$v_attr_count; i++))
  do
   read v_line
   v_string=`echo -n $v_line | cut -d ":" -f 2`
   #echo "$v_string"
   v_sep=" = "
   v_name=""
   v_value=""
   v_unit=""
   echo -n "$v_string" | grep -q "$v_sep"
   if [ "$?" -ne "0" ]
   then
    v_sep=" <= "
   fi
   v_name=${v_string%%$v_sep*}
   v_name=`echo -n $v_name | sed -r "s/[ \.]/_/g" | sed -r "s/\%//g"`
   v_value=${v_string##*$v_sep}
   v_unit=`echo -n $v_value | awk '{printf "%s", $2}'`
   v_value=`echo -n $v_value | awk '{printf "%s", $1}'`

   [ "$v_value" == "{}" ] && v_value="null"
   [ "$v_name" == "75" ] && v_name="p75"
   [ "$v_name" == "95" ] && v_name="p95"
   [ "$v_name" == "98" ] && v_name="p98"
   [ "$v_name" == "99" ] && v_name="p99"
   [ "$v_name" == "99_9" ] && v_name="p99_9"
   [ "$v_name" == "1-minute_rate" ] && v_name="I_minute_rate"
   [ "$v_name" == "5-minute_rate" ] && v_name="V_minute_rate"
   [ "$v_name" == "15-minute_rate" ] && v_name="IV_minute_rate"

   #echo "$v_string -> $v_name $v_value $v_unit" 
   echo "$v_string -> $v_metric_id $v_name $v_value $v_unit" | tee -a /tmp/temp.txt
   if [ ! -z "$v_name" -a ! -z "$v_value" ]
   then
    echo "insert into temp_data (name,value,metric_id) values('$v_name','$v_value',$v_metric_id);" >> /tmp/temp.sql
   fi
  done
 fi 
done < "$v_source"
}

prepare_sqlfile() {
local v_string v_rc v_metric_id v_statement v_name v_value v_tmp
local v_source="$1"

cat /dev/null > /tmp/temp.sql
v_metric_id=""
while read line
do
 v_string=`echo -n $line | cut -d ":" -f 2`
 v_rc=`echo "select count(*) from metric_name where name='${v_string}';" | $SQLITEDB`
 if [ "$v_rc" -eq "1" ]
 then
  # metric
  v_metric_id=`echo "select id from metric_name where name='${v_string}';" | $SQLITEDB`
  v_statement=""
  v_name="timestamp,metric_id"
  v_value=${v_timestamp}","${v_metric_id}
  for i in $(echo "select name from metric_description where metric_id=${v_metric_id};" | $SQLITEDB)
  do
    v_name=${v_name}","$i
    v_tmp=""
    v_tmp=`echo "select value from temp_data where metric_id=${v_metric_id} and name='$i';" | $SQLITEDB`
    [ -z "$v_tmp" ] && v_tmp="null"
    v_value=${v_value}","${v_tmp}
  done
  echo "insert into sysstat (node, ${v_name}) values('${v_node}',${v_value});" | tee -a /tmp/temp.sql
 fi
done < "$v_source"
}
###########################################################
if [ -f /home/cassandra/.set_cassandra_env.sh ]
then
 . /home/cassandra/.set_cassandra_env.sh
else
 exit 0
fi

if [ -f "$LOCK_FILE" ] 
then
 #logger "Lock-file $LOCK_FILE exist, with data `cat $LOCK_FILE`"
 exit 0
else
 echo -n "${v_id}" > $LOCK_FILE
fi

IN_QUEUE="$CASSANDRA_HOME/metrics/in/"
ERR_QUEUE="$CASSANDRA_HOME/metrics/err/"
v_node=`hostname -I | tr -d [:space:]`
v_keyspace="awr"
DB_USER="..."
DB_USER_PWD="..."

for z in $(find $IN_QUEUE -type f -regextype posix-extended -regex '.*[0-9]+$')
do
 v_datfile="$z"
 logger "Processing $v_datfile"
 v_timestamp=`head -n 1 $v_datfile | cut -d ":" -f 1`
 parse_file "$v_datfile" 1>/dev/null
 logger "loading parsed data to sqlite temp-table" 
$SQLITEDB << __EOFF__
BEGIN TRANSACTION;
.read /tmp/temp.sql
commit;
.exit
__EOFF__

 logger "Making sql-script for cqlsh"
 prepare_sqlfile "$v_datfile" 2>/dev/null
 v_time1="$(date -u +%s.%N)"
 $CASSANDRA_HOME/bin/cqlsh -u "$DB_USER" -p "$DB_USER_PWD" -k ${v_keyspace} -f /tmp/temp.sql $CASSANDRA_HOST $CASSANDRA_PORT 1>>$LOG_FILE 2>&1
 v_rc="$?"
 v_time2="$(date -u +%s.%N)"
 v_time1=`echo "$v_time2-$v_time1" | bc -l`
 v_timestamp=`date +%s`
 if [ "$v_rc" -eq "0" ]
 then
  logger "OK: ${v_datfile} processed in ${v_time1} sec, at ${v_timestamp}"
  echo "insert into loader_stat(node,timestamp,elatime) values('${v_node}',${v_timestamp},${v_time1});" | $CASSANDRA_HOME/bin/cqlsh -u "$DB_USER" -p "$DB_USER_PWD" -k ${v_keyspace} $CASSANDRA_HOST  $CASSANDRA_PORT
  rm -f "$v_datfile"
 else
  logger "ERR: ${v_datfile}"
  cat /tmp/temp.sql >> $LOG_FILE
  mv -v "$v_datfile" $ERR_QUEUE
 fi
 
 logger "Done with $z"
done

logger "Done"
[ -f "$LOCK_FILE" ] && rm -f $LOCK_FILE
exit 0
