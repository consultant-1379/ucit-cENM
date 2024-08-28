#!/bin/bash
#
#
# WHERE nome ~ '^t(201[0-9]|2020)\d{4}_\d+_\d+$';
#
version=1.1.9
tag=1.1.9
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
regex=""
#
function usage () {
  echo "Usage: $cmd [-e number_of_days (max $max_ndays)] <label> [regex]"
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
#
keep="false"
#
if [ "$1" == "-k" ]; then
  keep="true"
  shift
fi
#
if [ "$1" == "-e" ]; then
  shift
  check_arg $1
  ndays=$1
  shift
fi
#
if [ -z "$1" ]; then
  usage
else
  label=$1
  shift
fi
#
if [ ! -z "$1" ]; then
  regex="$1"
  shift
fi
regex_enc=$(echo "$regex" | base64)
#
if [ $ndays -gt $max_ndays ]; then
  usage
fi
#
/bin/rm *.x.c 2>/dev/null
#
script="$script_dir/delete_entity_pattern.sh"
#
exp=$(date -d @$(( $(date +%s) + 3600*24*$ndays )) +%d/%m/%Y)
#
out_script_name="delete_entity_pattern_${label}_from_db"
out_script_name_sh="${out_script_name}.sh"
#
cat >  "$out_script_name_sh" <<_EOF_
#!/bin/bash
#
source <( base64 -d << __EOF__
_EOF_
#
sed -e "s/_SCRIPT_REGEX_ENC_/${regex_enc}/" \
    -e "s/_SCRIPT_VERSION_/${version}/" \
    -e "s/_SCRIPT_VERSION_/${version}/" \
    -e "s/_SCRIPT_TAG_/${tag}/" \
    -e "s,_SCRIPT_EXPIRES_,${exp}," $script | base64 >>  "$out_script_name_sh"

cat >>  "$out_script_name_sh" <<_EOF_
__EOF__
)
#
_EOF_
#
shc -r -e $exp -m "$0 expired on $exp, please ask for a new one" -f "$out_script_name_sh" -o "$out_script_name"
#
if [ "$keep" != "true" ]; then
  rm -f ${out_script_name_sh}
fi
#
rm -f ${out_script_name_sh}.x.c
#
echo "Executable file is: $out_script_name   Will expire on: $exp"
#
