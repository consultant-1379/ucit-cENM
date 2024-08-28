#!/bin/bash

CURR_DIR=$(pwd)
LG=""
PS=""
VAR=""
TYPE=""
DEP=""
INTEGRATION_VALUE_STRING=""
FORCE="False"
QUIET="False"

DEFAULT_SUBCHART="eric-enmsg-mscm"

print_out () {
  if [ "${QUIET}" != "True" ];
  then
    echo $1 $2
  fi
}

#*********************************************************#
# Fetch the latest ENM chart & values urls
#*********************************************************#
fetch_chart_information() {
  local PS_VERSION="${PS}"  
  #echo "PS_VERSION=$PS_VERSION"
  local SPRINT_DROP=$(echo $PS_VERSION | cut -d '.' -f -2)
  #echo "SPRINT_DROP=$SPRINT_DROP"
  local PS_URL="https://ci-portal.seli.wh.rnd.internal.ericsson.com/api/cloudnative/getCloudNativeProductSetContent/$SPRINT_DROP/$PS_VERSION/"
  #echo "PS_URL=$PS_URL"

  PS_JSON_RESPONSE=$(curl -s --location --request GET $PS_URL)
  #echo "PS_JSON_RESPONSE=$PS_JSON_RESPONSE"

  ENM_CHART_URL=$(echo $PS_JSON_RESPONSE | jq  '.[] | select(.integration_charts_data).integration_charts_data' | jq '.[] | select(.chart_name | contains("'$WANTED_ENM_CHART'")) | .chart_dev_url' | sed -e 's/^"//' -e 's/"$//')
  #echo "Retrieved url for $WANTED_ENM_CHART - $ENM_CHART_URL"

}

get_stateless_url ()
{
  CHART_NEW=($(echo "${ENM_CHART_URL}"))
  for chart in "${CHART_NEW[@]}";
  do
    if echo "$chart" | grep -q stateless ; then
      stateless_url="${chart}"
    fi
  done
}

usage ()
{
  echo ""
  echo "Usage: $0 [ -p PRODUCT_SET ] [ -c SUBCHART ] [ -q ] [ -h ]"
  echo ""
}

usage_detailed ()
{
  echo ""
	echo "This script download all the integration charts and the sed for a"
	echo "cENM specific ProductSet"
  usage
	echo ""
	echo "Arguments:"
	echo "  -p PRODUCT_SET"
	echo "     Optional, Default is Latest Green PS, format is NN.MM.XX[-YY]"
	echo "  -c chart_name"
	echo "     Specify from which subchart get the helmchart-library name (Default $DEFAULT_SUBCHART)"
	echo "  -q"
	echo "     Quiet do not print extra info, just the plain version."
	echo "  -h"
	echo "     Show this help and exit"
	echo ""
	echo ""
	echo "Some examples:"
	echo "  $1"
	echo "  $1 -p 21.10.108 -c eric-enmsg-amos"
	echo "  $1 -p 21.10.108 -c eric-enmsg-amos -q"
	echo ""
	exit 0
}

exit_abnormal ()
{
  usage
  exit 1
}

list_include_item()
{
  if [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]];
  then
    result=0
  else
    result=1
  fi

  return $result
}

check_ps()
{
  LOCAL_PS=$(echo $1 | cut -d '-' -f 1)
  if [[ ! ${LOCAL_PS} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];
  then
    echo "ERROR: $LOCAL_PS is not valid"
    echo "       Allowed format is: \"nnn.mmm.rrr[-n]\""
    exit_abnormal
  fi
}

check_variant()
{
  LOCAL_VARIANT=$1
  VARIANT="kaas openstack openstack-test xl"
  $(list_include_item "$VARIANT" "$LOCAL_VARIANT")
  if [ $? -ne 0 ];
  then
    echo "ERROR: $LOCAL_VARIANT is not included in VARIANT list"
    echo "       Allowed values are: \"${VARIANT}\""
    exit_abnormal
  fi
}

check_type()
{
  LOCAL_TYPE=$1
  TYPE_LIST="core-values single-instance multi-instance"
  $(list_include_item "$TYPE_LIST" "$LOCAL_TYPE")
  if [ $? -ne 0 ];
  then
    echo "ERROR: $LOCAL_TYPE is not included in TYPE list"
    echo "       Allowed values are: \"${TYPE_LIST}\""
    exit_abnormal
  fi
}

set_params ()
{
  if [ -z "${PS}" ];
  then
    LG="Latest_Green"
    if [ "${LG}" == "Latest_Green" ];
    then
      PS=$(curl -s --location --request GET 'https://ci-portal.seli.wh.rnd.internal.ericsson.com/api/cloudNative/getGreenProductSetVersion/latest/')
    fi
  fi

  if [ -z "${PRJ}" ];
  then
    PRJ="$DEFAULT_SUBCHART"
  fi

  if [ -z "${VAR}" ];
  then
    VAR="openstack"
  fi

  if [ -z "${TYPE}" ];
  then
    TYPE="single-instance"
  fi

  if [ -z "${DEP}" ];
  then
    myhost=$(hostname)
    DEP=ieatenm${myhost##*-}
    print_out "Retrieved dep is: \"${DEP}\""
  fi

}

print_params ()
{
  print_out ""
  print_out "Your selection is:"
  print_out ""
  print_out "PRODUCT_SET =   ${PS} ${LG}"
  print_out "VARIANT =       ${VAR}"
  print_out "TYPE =          ${TYPE}"
  print_out "DEPLOYMENT_ID = ${DEP}"
  print_out ""
  print_out ""
}

get_args ()
{
  while getopts ":p:v:d:c:qh" options;
  do
    case "${options}" in
      c )
        PRJ=$OPTARG
        ;;
      p )
        PS=$OPTARG
        check_ps "${PS}"
        ;;
      v )
        VAR=$OPTARG
        check_variant "${VAR}"
        ;;
      q )
        QUIET="True"
        ;;
      h )
        usage_detailed $0
        exit 0
        ;;
      : )
        echo "Error: -$OPTARG requires an argument"
        exit_abnormal
        ;;
      * )
        echo "Error: -$OPTARG unknown option"
        exit_abnormal
        ;; \? )
        echo "Error: -$OPTARG invalid option"
        exit_abnormal
        ;;
     esac
  done
}

main ()
{
  get_args $*
  set_params
  print_params
  fetch_chart_information
  stateless_url="none"
  get_stateless_url
  print_out "Stateless URL:$stateless_url"
  helmchart_version=$(wget -O - "$stateless_url" | tar zxOf - "eric-enm-stateless-integration/charts/$PRJ/charts/eric-enm-common-helmchart-library/Chart.yaml" | grep '^version:'| sed -e 's/version: //' -e 's/  *//g')
  print_out "-n" "Helmchart version:"
  echo "$helmchart_version"
}

main $*

