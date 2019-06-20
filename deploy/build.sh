#!/bin/bash
set -ex 

AWS="aws --profile=flosports-production" 
NAMESPACE="live-api-dev"
FN_NAME="log-processor-${NAMESPACE}"

$AWS lambda create-function \
  --role "arn:aws:iam::215207670129:role/log-processor-lambdaExecution" \
  --runtime "go1.x" \
  --handler "functionbeat" \
  --publish \
  --zip-file fileb://package.zip \
  --memory-size 128 \
  --function-name "$FN_NAME" \
  --environment "Variables={BEAT_STRICT_PERMS=false,ENABLED_FUNCTIONS=${FN_NAME}}" \
  --timeout 10 \
  --output text

$AWS lambda add-permission \
  --principal logs.us-west-2.amazonaws.com \
  --action lambda:InvokeFunction \
  --statement-id "${NAMESPACE}-InvokeLogProcessor" \
  --source-arn "arn:aws:logs:us-west-2:215207670129:log-group:/aws/lambda/${NAMESPACE}-*:*" \
  --function-name "$FN_NAME" \
  --source-account 215207670129 \
  --output text | jq

$AWS lambda list-functions | awk "/FunctionName/ && /${NAMESPACE}/ { print \$2 }" \
  | grep 'hello-world' | sed 's/"//g;s/,//' | sed '/^$/d' | sort >|log_groups.txt

for fn in `cat log_groups.txt`; do 
  echo $fn
  fn_filter=$(tr -d '-' <<<$fn)
  $AWS logs put-subscription-filter \
    --filter-name $fn \
    --log-group-name "/aws/lambda/${fn}" \
    --filter-pattern "actualEnv" \
    --destination-arn "arn:aws:lambda:us-west-2:215207670129:function:${FN_NAME}" \
    --distribution "ByLogStream" \
    --output text | jq
done
