#!/bin/bash
#
cmd=$0
#
# Default number of days before script will expire
#
ndays=10
#
max_ndays=30
#
function usage () {
  echo "Usage: $cmd [-e number_of_days (max $max_ndays)] script [args]"
  exit -1
}
#
function check_arg () {
  if [ -z "$1" ]; then
    usage
  fi
}
#
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  usage
fi
if [ "$1" == "-e" ]; then
  shift
  check_arg $1
  ndays=$1
  shift
fi
#
if [ $ndays -gt $max_ndays ]; then
  usage
fi
/bin/rm *.x.c 2>/dev/null
#
script_cmd="$1"
#
if ! file $script_cmd | grep -q "shell script" ; then
  echo "$script_cmd must be a shell script"
  exit
fi
#
exp=$(date -d @$(( $(date +%s) + 3600*24*$ndays )) +%d/%m/%Y)
#
prog_name="ad_hoc_tool_"$(echo "$script_cmd" | sed 's/\..*//')
#
shc -r -e $exp -m "$0 expired on $exp, please ask for a new one" -f ${script_cmd} -o ${prog_name}
#
echo "Expiration date: $exp"
#
/bin/rm *.x.c 2>/dev/null
#
