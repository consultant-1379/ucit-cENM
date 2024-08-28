#!/bin/bash
#
cmd=$0
script_dir=$(dirname $cmd)
#
# Default number of days before script will expire
#
ndays=10
#
max_ndays=30
#
function usage () {
  echo "Usage: $cmd [-e number_of_days (max $max_ndays)]"
  echo "Usage: $cmd [-h|--help] Display this help"
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
#
/bin/rm *.x.c 2>/dev/null
#
script="ENM_PKI_ROOT_SWAP.sh"
#
exp=$(date -d @$(( $(date +%s) + 3600*24*$ndays )) +%d/%m/%Y)
#
script_name=enm_swap_cert_sn
#
shc -r -e $exp -m "$0 expired on $exp, please ask for a new one" -f "$script_dir/$script" -o "$script_name"
#
rm -f ${script}.x.c
#
echo "Executable file is: $script_name   Will expire on: $exp"
#
