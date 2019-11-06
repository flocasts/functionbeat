#!/bin/bash
set -e

AWS="aws --profile=flosports-production --output=json"
ROLE="arn:aws:iam::215207670129:role/log-processor-lambdaExecution"
OS=$1
NAMESPACE=$2
IDX_NAME=${3:-$NAMESPACE}
FN_NAME="log-processor-${NAMESPACE}"
MEM_SIZE=128
TIMEOUT=90
LAMBDA_CONCURRENCY=${LAMBDA_CONCURRENCY:-100}
LOG_PREFIX="${LOG_PREFIX:-/aws/lambda/}"
FB_META=${FB_META:-false}
ADD_FILTERS=${ADD_FILTERS:-true}

BASE_TEMPLATE="functionbeat_base.yml"
EXCLUDE="log-processor|datadog"
if [[ $FB_META == true ]]; then
  BASE_TEMPLATE="functionbeat_meta_base.yml"
  EXCLUDE="log-processor-log-processor|datadog${EXCLUDE}"
fi

if [[ $OS == "linux" ]]; then
  AWS="aws --output=json"
fi

echo "Building ${FN_NAME}."

$AWS  logs describe-log-groups --query "logGroups[*].logGroupName" | jq '.[]' \
  | sed 's/"//g;s/ //g;s/[\[\]]//g' \
  | grep "${NAMESPACE}" | grep "$LOG_PREFIX" | egrep -v "$EXCLUDE" | sort >|log_groups.txt


sed "s/VAR_NAME/${FN_NAME}/;s/IDX_NAME/${IDX_NAME}/" $BASE_TEMPLATE >| functionbeat.yml


for group in `cat log_groups.txt`; do
  entry="          - { log_group_name: ${group}, filter_pattern: '?-START ?-END ?-REPORT' }"
  echo "$entry" >>functionbeat.yml
done

chmod 600 beats.keystore
chmod 644 functionbeat.yml
sudo chown 0:0 beats.keystore
sudo chown 0:0 functionbeat.yml

sudo ./functionbeat-${OS} setup -e -v --index-management
echo "Building function package."
sudo ./functionbeat-${OS} -e -v package

sudo zip -u package-aws.zip ilm_policy.json

set +e
EXISTS=$($AWS lambda get-function --function-name log-processor-${NAMESPACE} --output text || false)
set -e
if [[ $EXISTS ]]; then
  echo "${FN_NAME} exists. Updating function."

  $AWS lambda update-function-configuration \
    --role "$ROLE" \
    --runtime "go1.x" \
    --handler "functionbeat-aws" \
    --memory-size $MEM_SIZE \
    --function-name "$FN_NAME" \
    --environment "Variables={BEAT_STRICT_PERMS=false,ENABLED_FUNCTIONS=${FN_NAME}}" \
    --timeout $TIMEOUT \
    --output text

  $AWS lambda put-function-concurrency \
    --function-name $FN_NAME \
    --reserved-concurrent-executions $LAMBDA_CONCURRENCY

  $AWS lambda update-function-code \
    --function-name "$FN_NAME" \
    --publish \
    --zip-file fileb://package-aws.zip \
    --output text

else

  echo "Creating ${FN_NAME}."

  $AWS lambda create-function \
    --role "$ROLE" \
    --runtime "go1.x" \
    --handler "functionbeat-aws" \
    --publish \
    --zip-file fileb://package-aws.zip \
    --memory-size $MEM_SIZE \
    --function-name "$FN_NAME" \
    --environment "Variables={BEAT_STRICT_PERMS=false,ENABLED_FUNCTIONS=${FN_NAME}}" \
    --tags "role=log-processor,project=${NAMESPACE}" \
    --timeout $TIMEOUT \
    --output text

    $AWS lambda put-function-concurrency \
    --function-name $FN_NAME \
    --reserved-concurrent-executions $LAMBDA_CONCURRENCY

  $AWS lambda add-permission \
    --principal logs.us-west-2.amazonaws.com \
    --action lambda:InvokeFunction \
    --statement-id "${NAMESPACE}-InvokeLogProcessor" \
    --source-arn "arn:aws:logs:us-west-2:215207670129:log-group:${LOG_PREFIX}${NAMESPACE}*:*" \
    --function-name "$FN_NAME" \
    --source-account 215207670129 \
    --output text || true

fi

if [[ $ADD_FILTERS == true ]]; then
  echo "Adding subscription filters..."

  for group in `cat log_groups.txt`; do
    echo $group
    group_filter=$(awk -F/ '{print $NF}' <<<$group)
    $AWS logs put-subscription-filter \
      --filter-name "$group_filter" \
      --log-group-name "$group" \
      --filter-pattern "actualEnv" \
      --destination-arn "arn:aws:lambda:us-west-2:215207670129:function:${FN_NAME}" \
      --distribution "ByLogStream" || true
  done
fi