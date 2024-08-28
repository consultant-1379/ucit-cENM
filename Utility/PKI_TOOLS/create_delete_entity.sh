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
  echo "Usage: $cmd [-e number_of_days (max $max_ndays)] <entity name>[,<entity name>][,<entity name>][,....]"
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
entity_names=$1
#
if [ $ndays -gt $max_ndays ]; then
  usage
fi
#
/bin/rm *.x.c 2>/dev/null
#
script="$script_dir/delete_entity.sh"
#
entity_name="$1"
#
exp=$(date -d @$(( $(date +%s) + 3600*24*$ndays )) +%d/%m/%Y)
#
script_name=$(echo "$entity_name" | sed 's/,/_/g')
out_script_name="delete_entity_${script_name}_from_db"
out_script_name_sh="${out_script_name}.sh"
#
cat > "$out_script_name_sh" <<_EOF_
#!/bin/bash
#
base64 -d << __EOF__ | bash \$*
_EOF_
#
sed "s/_ENTITY_NAME_/$entity_name/" $script |base64 >> "$out_script_name_sh"
#
cat >> "$out_script_name_sh" <<_EOF_
__EOF__
_EOF_
#
shc -r -e $exp -m "$0 expired on $exp, please ask for a new one" -f "$out_script_name_sh" -o "$out_script_name"
#
rm -f ${out_script_name_sh}
rm -f ${out_script_name_sh}.x.c
#
echo "Executable file is: $out_script_name   Will expire on: $exp"
#
