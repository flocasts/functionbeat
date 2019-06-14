#!env zsh
set -e

SID=$(uuid)

#TODO - enforce params
namespace=$1
action=$2
exclude=${3:=""}

[[ $exclude != "" ]] && exclude="|$exclude"


# Only populating live-api-<env>-hello-world until development is complete
aws --profile=flosports-production lambda list-functions | awk "/FunctionName/ && /${namespace}/ { print \$2 }" \
  | grep 'hello-world' | sed 's/"//g;s/,//' | sort >|log_groups.txt
# | egrep -v "logger|datadog|log-processor${exclude}" | sed 's/"//g;s/,//' | sort >|log_groups.txt

split=40
iter=0
suffix=0
entry=""
cp -f functionbeat_base.yml functionbeat.yml

for fn in `cat log_groups.txt`; do

  entry="      - { log_group_name: /aws/lambda/${fn}, filter_pattern: actualEnv }"

  if [[ $((iter % split)) -eq 0 ]]; then

    if [[ $iter -ne 0 ]]; then
      suffix=$((suffix + 1))
    fi  

    echo "Generating configuration for ${namespace}-log-processor${suffix}."
    echo >>functionbeat.yml
    sed "s/NAME_REPLACE_ME/${namespace}-log-processor${suffix}/" cloudwatch_template.yml >>functionbeat.yml
    echo "$entry" >>functionbeat.yml

  else
    echo "$entry" >>functionbeat.yml
  fi  

  iter=$((iter + 1))
done

echo "Executing functionbeat $action..."
set -x
./functionbeat setup --ilm-policy --pipelines --template -e -v
./functionbeat $action -e ${namespace}-log-processor{0..${suffix}}
