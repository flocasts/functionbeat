#!/bin/bash
set -e

AWS="aws --profile=flosports-production"
SID=$(uuid)

#TODO - enforce params
namespace=$1
env=$2
action=$3

rm -f configs/*.yml

$AWS lambda list-functions | awk "/FunctionName/ && /${namespace}/ { print \$2 }" \
  | egrep -v 'logger|datadog|testola|thumb|jasons' \
  | sed 's/"//g;s/,//' | sort >|log_groups.txt

split=30
iter=0
suffix=0
entry=""

for fn in `cat log_groups.txt`; do

  entry="      - { log_group_name: /aws/lambda/${fn}, filter_pattern: INFO }"

  if [[ $((iter % split)) -eq 0 ]]; then

    if [[ $iter -ne 0 ]]; then
      suffix=$((suffix + 1))
    fi  

    echo "Generating log-processor - ${suffix}."
    sed "s/NAME_REPLACE_ME/${namespace}-log-processor${suffix}/;s/ENV_REPLACE_ME/${env}/" cw_logs_scaffold.yml >|configs/function.${suffix}.yml
    echo "$entry" >>configs/function.${suffix}.yml

  else
    echo "$entry" >>configs/function.${suffix}.yml
  fi  

  iter=$((iter + 1))
done

rm -f log_groups.txt

set -x
iter=0
for conf in `ls configs`; do
  ./functionbeat $action -c functionbeat.yml -c configs/${conf} -e -d "*" ${namespace}-log-processor${iter}
  iter=$((iter + 1))
done