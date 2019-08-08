#!/bin/bash
set -e

AWS="aws --profile=flosports-production --output=json" 
ROLE="arn:aws:iam::215207670129:role/log-processor-lambdaExecution"
OS=$1
NAMESPACE=$2
IDX_NAME=$3
FN_NAME="log-processor-${NAMESPACE}"
MEM_SIZE=1024
TIMEOUT=90
# FB_META=true - export this if processing functionbeat logs

BASE_TEMPLATE="functionbeat_base.yml"
EXCLUDE="log-processor|datadog"
if [[ -n ${FB_META+x} && $FB_META ]]; then
  BASE_TEMPLATE="functionbeat_meta_base.yml"
  EXCLUDE="log-processor-log-processor|datadog${EXCLUDE}"
fi

if [[ $OS == "linux" ]]; then
  AWS="aws --output=json"
fi

echo "Building ${FN_NAME}."

$AWS lambda list-functions | awk "/FunctionName/ && /${NAMESPACE}/ { print \$2 }" \
  | egrep -v "$EXCLUDE" | sed 's/"//g;s/,//' | sort >|functions.txt

sed "s/VAR_NAME/${FN_NAME}/;s/IDX_NAME/${IDX_NAME}/" $BASE_TEMPLATE >| functionbeat.yml

for fn in `cat functions.txt`; do
  entry="          - { log_group_name: /aws/lambda/${fn}, filter_pattern: '?-START ?-END ?-REPORT' }"
  echo "$entry" >>functionbeat.yml
done

./functionbeat-${OS} setup -e -v --index-management
echo "Building function package."
./functionbeat-${OS} -e -v package

set +e
EXISTS=$($AWS lambda get-function --function-name log-processor-${NAMESPACE} --output text || false)
set -e
if [[ $EXISTS ]]; then
  echo "${FN_NAME} exists. Updating function."

  $AWS lambda update-function-configuration \
    --role "$ROLE" \
    --runtime "go1.x" \
    --handler "functionbeat" \
    --memory-size $MEM_SIZE \
    --function-name "$FN_NAME" \
    --environment "Variables={BEAT_STRICT_PERMS=false,ENABLED_FUNCTIONS=${FN_NAME}}" \
    --timeout $TIMEOUT \
    --output text

  $AWS lambda update-function-code \
    --function-name "$FN_NAME" \
    --publish \
    --zip-file fileb://package.zip \
    --output text

else

  echo "Creating ${FN_NAME}."

  $AWS lambda create-function \
    --role "$ROLE" \
    --runtime "go1.x" \
    --handler "functionbeat" \
    --publish \
    --zip-file fileb://package.zip \
    --memory-size $MEM_SIZE \
    --function-name "$FN_NAME" \
    --environment "Variables={BEAT_STRICT_PERMS=false,ENABLED_FUNCTIONS=${FN_NAME}}" \
    --tags "role=log-processor,project=${NAMESPACE}" \
    --timeout $TIMEOUT \
    --output text

  $AWS lambda add-permission \
    --principal logs.us-west-2.amazonaws.com \
    --action lambda:InvokeFunction \
    --statement-id "${NAMESPACE}-InvokeLogProcessor" \
    --source-arn "arn:aws:logs:us-west-2:215207670129:log-group:/aws/lambda/${NAMESPACE}*:*" \
    --function-name "$FN_NAME" \
    --source-account 215207670129 \
    --output text || true

fi

echo "Adding subscription filters..."

for fn in `cat functions.txt`; do 
  echo $fn
  fn_filter=$(tr -d '-' <<<$fn)
  $AWS logs put-subscription-filter \
    --filter-name $fn \
    --log-group-name "/aws/lambda/${fn}" \
    --filter-pattern "actualEnv" \
    --destination-arn "arn:aws:lambda:us-west-2:215207670129:function:${FN_NAME}" \
    --distribution "ByLogStream" || true
done
