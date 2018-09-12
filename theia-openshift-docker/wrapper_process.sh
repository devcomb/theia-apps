#!/bin/bash

set -e
if [ -e "/opt/app-root/etc/generate_container_user" ]; then
  source /opt/app-root/etc/generate_container_user
fi

DEFAULT_DEBUG_PORT=5858
DEBUG_PORT=${DEBUG_PORT:-${DEFAULT_DEBUG_PORT}}
DEFAULT_STATUS_POLL=60
STATUS_POLL=${STATUS_POLL:-${DEFAULT_STATUS_POLL}}
DEFAULT_THEIA_APP=/home/theia/theia_process.sh
THEIA_APP=${THEIA_APP:-${DEFAULT_THEIA_APP}}
DEFAULT_APP_ASSEMBLE=/usr/libexec/s2i/assemble
APP_ASSEMBLE=${APP_ASSEMBLE:-${DEFAULT_APP_ASSEMBLE}}
DEFAULT_APP_PROC=/usr/libexec/s2i/run
APP_PROC=${APP_PROC:-${DEFAULT_APP_PROC}}
DEFAULT_DEV_MODE=true
DEV_MODE=${DEV_MODE:-${DEFAULT_DEV_MODE}}
DEFAULT_SEC_COMMAND="exec npm run -d $NPM_RUN"
SEC_COMMAND=${SEC_COMMAND:-${DEFAULT_SEC_COMMAND}}
DEFAULT_SEC_DEBUG_COMMAND="exec nodemon --inspect=$DEBUG_PORT"
SEC_DEBUG_COMMAND=${SEC_DEBUG_COMMAND:-${DEFAULT_SEC_DEBUG_COMMAND}}
DEFAULT_GIT_REPO_URL=""
GIT_REPO_URL=${GIT_REPO_URL:-${DEFAULT_GIT_REPO_URL}}
DEFAULT_GIT_REPO_REF=""
GIT_REPO_REF=${GIT_REPO_REF:-${DEFAULT_GIT_REPO_REF}}
DEFAULT_ASSEMBLE=false
ASSEMBLE=${ASSEMBLE:-${DEFAULT_ASSEMBLE}}


#This will need to be set to true when used as builder image
DEFAULT_SEC_PROC=false
SEC_PROC=${SEC_PROC:-${DEFAULT_SEC_PROC}}

if [ -z "$NODE_ENV" ]; then
  if [ "$DEV_MODE" == true ]; then
    export NODE_ENV=development
  else
    export NODE_ENV=production
  fi
fi

# Allow users to inspect/debug the builder image itself, by using:
# $ docker run -it <imagename> --debug
#
[ "$1" == "--debug" ] && exec /bin/bash

echo -e "Environment: \n\tDEV_MODE=${DEV_MODE}"\
"\tNODE_ENV=${NODE_ENV}\n\tDEBUG_PORT=${DEBUG_PORT}"\
"\n\tSEC_PROC=${SEC_PROC}"\
"\n\tSEC_COMMAND=${SEC_COMMAND}"\
"\n\tSEC_DEBUG_COMMAND=${SEC_DEBUG_COMMAND}"

if [ "$DEV_MODE" == true ]; then
  # Start the theia process
  echo "DEV_MODE=$DEV_MODE - Starting ${THEIA_APP} ."
  ${THEIA_APP} &
  status=$?
  if [ $status -ne 0 ]; then
    echo "Failed to start ${THEIA_APP}: $status"
    exit $status
  fi
  echo "Success starting ${THEIA_APP}: $status"
fi

# Start the secondary process
if [ "$SEC_PROC" == true ]; then
  if [ ! "$GIT_REPO_URL" == "" ]; then
    echo "Fetching source code from $GIT_REPO_URL."
    git clone $GIT_REPO_URL /tmp/src
    if [ ! "$GIT_REPO_REF" == "" ]; then
      echo "Checkout branch $GIT_REPO_REF."
      git checkout $GIT_REPO_REF
    fi
  fi
  if [ "$ASSEMBLE" == true ]; then
    echo "Running assemble code."
    $APP_ASSEMBLE
  fi
  echo "Starting node process."
  if [ "$DEV_MODE" == true ]; then
    echo "Launching via nodemon..."
    ${SEC_DEBUG_COMMAND}
  else
    echo "Launching via secondary application..."
    ${SEC_COMMAND}
  fi
fi

# Naive check runs checks once a minute to see if either of the processes exited.
# The container exits with an error
# if it detects that either of the processes has exited.
# Otherwise it loops forever, waking up every ${DEFAULT_STATUS_POLL} seconds

if [ "$DEV_MODE" == true ] || [ "$SEC_PROC" == true ] ; then
  while sleep ${DEFAULT_STATUS_POLL}; do
    if [ "$DEV_MODE" == true ]; then
      ps aux |grep ${THEIA_APP} |grep -q -v grep
      PROCESS_1_STATUS=$?
      else
        PROCESS_1_STATUS=0
    fi
    if [ "$SEC_PROC" == true ]; then
      ps aux |grep ${APP_PROC} |grep -q -v grep
      PROCESS_2_STATUS=$?
      else
        PROCESS_2_STATUS=0
    fi
    # If the greps above find anything, they exit with 0 status
    # If they are not both 0, then something is wrong
    if [ $PROCESS_1_STATUS -ne 0 -o $PROCESS_2_STATUS -ne 0 ]; then
      echo "One of the processes has already exited."
      exit 1
    fi
  done
fi
