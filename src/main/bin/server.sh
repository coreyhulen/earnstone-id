#!/usr/bin/env bash  

if [ -z "$SERVER_HOME" ] 
then
  SERVER_HOME=`dirname $0`/..
fi

SERVER_LOGS=$SERVER_HOME/eid_service.log
SERVER_PORT=43120

JAVA_OPTIONS=" \
        -server \
        -ea \
        -Xms32M \
        -Xmx128M \
        -XX:+UseParNewGC \
        -XX:+UseConcMarkSweepGC \
        -XX:+CMSParallelRemarkEnabled \
        -XX:SurvivorRatio=8 \
        -XX:MaxTenuringThreshold=1 \
        -XX:+HeapDumpOnOutOfMemoryError"
        #-Dcom.sun.management.jmxremote.port=23120 \
        #-Dcom.sun.management.jmxremote.ssl=false \
        #-Dcom.sun.management.jmxremote.authenticate=false"

##################################################
##################################################
# DONT NOT CHANGE THE BELOW SCRIPT PARTS
##################################################
##################################################

usage()
{
    echo "Usage: ${0##*/} [-d] {start|stop|run|restart|check|supervise} [ CONFIGS ... ] "
    exit 1
}

[ $# -gt 0 ] || usage


##################################################
# Some utility functions
##################################################
findDirectory()
{
  local L OP=$1
  shift
  for L in "$@"; do
    [ "$OP" "$L" ] || continue 
    printf %s "$L"
    break
  done 
}

running()
{
  local PID=$(cat "$1" 2>/dev/null) || return 1
  kill -0 "$PID" 2>/dev/null
}

readConfig()
{
  (( DEBUG )) && echo "Reading $1.."
  source "$1"
}



##################################################
# Get the action & configs
##################################################
CONFIGS=()
NO_START=0
DEBUG=0

while [[ $1 = -* ]]; do
  case $1 in
    -d) DEBUG=1 ;;
  esac
  shift
done
ACTION=$1
shift

##################################################
# Read any configuration files
##################################################
for CONFIG in /etc/default/server{,7} $HOME/.serverrc; do
  if [ -f "$CONFIG" ] ; then 
    readConfig "$CONFIG"
  fi
done


##################################################
# Set tmp if not already set.
##################################################
TMPDIR=${TMPDIR:-/tmp}

##################################################
# No SERVER_HOME yet? We're out of luck!
##################################################
if [ -z "$SERVER_HOME" ]; then
  echo "** ERROR: SERVER_HOME not set, you need to set it or install in a standard location" 
  exit 1
fi

cd "$SERVER_HOME"
SERVER_HOME=$PWD


#####################################################
# Set the classpath
#####################################################
CLASSPATH=$CLASSPATH:$SERVER_HOME/config
for jar in $SERVER_HOME/lib/*.jar; do
    CLASSPATH=$CLASSPATH:$jar
done


#####################################################
# Find a location for the pid file
#####################################################
if [ -z "$SERVER_RUN" ] 
then
  SERVER_RUN=$(findDirectory -w /var/run /usr/var/run /tmp)
fi

#####################################################
# Find a PID for the pid file
#####################################################
if [ -z "$SERVER_PID" ] 
then
  SERVER_PID="$SERVER_RUN/server.pid"
fi

##################################################
# Setup JAVA if unset
##################################################
if [ -z "$JAVA" ]
then
  JAVA=$(which java)
fi

if [ -z "$JAVA" ]
then
  echo "Cannot find a Java JDK. Please set either set JAVA or put java (>=1.5) in your PATH." 2>&2
  exit 1
fi

#####################################################
# See if SERVER_PORT is defined
#####################################################
if [ "$SERVER_PORT" ] 
then
  JAVA_OPTIONS+=("-Dserver.port=$SERVER_PORT")
fi

#####################################################
# See if SERVER_LOGS is defined
#####################################################
if [ "$SERVER_LOGS" ]
then
  JAVA_OPTIONS+=("-Dserver.logs=$SERVER_LOGS")
fi

#####################################################
# Add server properties to Java VM options.
#####################################################
JAVA_OPTIONS+=("-Dserver.home=$SERVER_HOME" "-Djava.io.tmpdir=$TMPDIR")

[ -f "$SERVER_HOME/etc/start.config" ] && JAVA_OPTIONS=("-DSTART=$SERVER_HOME/etc/start.config" "${JAVA_OPTIONS[@]}")

#####################################################
# This is how the Server server will be started
#####################################################

SERVER_START=com.earnstone.id.EidServer

START_INI=$(dirname $SERVER_START)/start.ini
[ -r "$START_INI" ] || START_INI=""

RUN_ARGS=(${JAVA_OPTIONS[@]} -cp $CLASSPATH "$SERVER_START" $SERVER_ARGS "${CONFIGS[@]}")
RUN_CMD=("$JAVA" ${RUN_ARGS[@]})

#####################################################
# Comment these out after you're happy with what 
# the script is doing.
#####################################################
if (( DEBUG ))
then
  echo "SERVER_HOME     =  $SERVER_HOME"
  echo "SERVER_CONF     =  $SERVER_CONF"
  echo "SERVER_RUN      =  $SERVER_RUN"
  echo "SERVER_PID      =  $SERVER_PID"
  echo "SERVER_ARGS     =  $SERVER_ARGS"
  echo "CONFIGS        =  ${CONFIGS[*]}"
  echo "JAVA_OPTIONS   =  ${JAVA_OPTIONS[*]}"
  echo "JAVA           =  $JAVA"
  echo "RUN_CMD        =  ${RUN_CMD}"
fi

##################################################
# Do the action
##################################################
case "$ACTION" in
  start)
    echo -n "Starting Server: "

    if (( NO_START )); then 
      echo "Not starting server - NO_START=1";
      exit
    fi

    if type start-stop-daemon > /dev/null 2>&1 
    then
      unset CH_USER
      if [ -n "$SERVER_USER" ]
      then
        CH_USER="-c$SERVER_USER"
      fi
      if start-stop-daemon -S -p"$SERVER_PID" $CH_USER -d"$SERVER_HOME" -b -m -a "$JAVA" -- "${RUN_ARGS[@]}" --daemon
      then
        sleep 1
        if running "$SERVER_PID"
        then
          echo "OK"
        else
          echo "FAILED"
        fi
      fi

    else

      if [ -f "$SERVER_PID" ]
      then
        if running $SERVER_PID
        then
          echo "Already Running!"
          exit 1
        else
          # dead pid file - remove
          rm -f "$SERVER_PID"
        fi
      fi

      if [ "$SERVER_USER" ] 
      then
        touch "$SERVER_PID"
        chown "$SERVER_USER" "$SERVER_PID"
        # FIXME: Broken solution: wordsplitting, pathname expansion, arbitrary command execution, etc.
        su - "$SERVER_USER" -c "
          ${RUN_CMD[*]} --daemon &
          disown \$!
          echo \$! > '$SERVER_PID'"
      else
        "${RUN_CMD[@]}" &
        disown $!
        echo $! > "$SERVER_PID"
      fi

      echo "STARTED Server `date`" 
    fi

    ;;

  stop)
    echo -n "Stopping Server: "
    if type start-stop-daemon > /dev/null 2>&1; then
      start-stop-daemon -K -p"$SERVER_PID" -d"$SERVER_HOME" -a "$JAVA" -s HUP
      
      TIMEOUT=30
      while running "$SERVER_PID"; do
        if (( TIMEOUT-- == 0 )); then
          start-stop-daemon -K -p"$SERVER_PID" -d"$SERVER_HOME" -a "$JAVA" -s KILL
        fi

        sleep 1
      done

      rm -f "$SERVER_PID"
      echo OK
    else
      PID=$(cat "$SERVER_PID" 2>/dev/null)
      kill "$PID" 2>/dev/null
      
      TIMEOUT=30
      while running $SERVER_PID; do
        if (( TIMEOUT-- == 0 )); then
          kill -KILL "$PID" 2>/dev/null
        fi

        sleep 1
      done

      rm -f "$SERVER_PID"
      echo OK
    fi

    ;;

  restart)
    SERVER_SH=$0
    if [ ! -f $SERVER_SH ]; then
      if [ ! -f $SERVER_HOME/bin/server.sh ]; then
        echo "$SERVER_HOME/bin/server.sh does not exist."
        exit 1
      fi
      SERVER_SH=$SERVER_HOME/bin/server.sh
    fi

    "$SERVER_SH" stop "$@"
    "$SERVER_SH" start "$@"

    ;;

  supervise)
    #
    # Under control of daemontools supervise monitor which
    # handles restarts and shutdowns via the svc program.
    #
    exec "${RUN_CMD[@]}"

    ;;

  run|demo)
    echo "Running Server: "

    if [ -f "$SERVER_PID" ]
    then
      if running "$SERVER_PID"
      then
        echo "Already Running!"
        exit 1
      else
        # dead pid file - remove
        rm -f "$SERVER_PID"
      fi
    fi

    exec "${RUN_CMD[@]}"

    ;;

  check)
    echo "Checking arguments to Server: "
    echo "SERVER_HOME     =  $SERVER_HOME"
    echo "SERVER_CONF     =  $SERVER_CONF"
    echo "SERVER_RUN      =  $SERVER_RUN"
    echo "SERVER_PID      =  $SERVER_PID"
    echo "SERVER_PORT     =  $SERVER_PORT"
    echo "SERVER_LOGS     =  $SERVER_LOGS"
    echo "START_INI      =  $START_INI"
    echo "CONFIGS        =  ${CONFIGS[*]}"
    echo "JAVA_OPTIONS   =  ${JAVA_OPTIONS[*]}"
    echo "JAVA           =  $JAVA"
    echo "CLASSPATH      =  $CLASSPATH"
    echo "RUN_CMD        =  ${RUN_CMD[*]}"
    echo
    
    if [ -f "$SERVER_RUN/server.pid" ]
    then
      echo "Server running pid=$(< "$SERVER_RUN/server.pid")"
      exit 0
    fi
    exit 1

    ;;

  *)
    usage

    ;;
esac

exit 0
