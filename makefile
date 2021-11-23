include etc/environment.sh

iam: iam.package iam.deploy
iam.package:
	sam package -t ${IAM_TEMPLATE} --output-template-file ${IAM_OUTPUT} --s3-bucket ${S3BUCKET}
iam.deploy:
	sam deploy -t ${IAM_OUTPUT} --stack-name ${IAM_STACK} --parameter-overrides ${IAM_PARAMS} --capabilities CAPABILITY_NAMED_IAM

lambda: lambda.package lambda.deploy
lambda.package:
	sam package -t ${LAMBDA_TEMPLATE} --output-template-file ${LAMBDA_OUTPUT} --s3-bucket ${S3BUCKET}
lambda.deploy:
	sam deploy -t ${LAMBDA_OUTPUT} --stack-name ${LAMBDA_STACK} --parameter-overrides ${LAMBDA_PARAMS} --role-arn ${O_CFN_ROLE} --capabilities CAPABILITY_NAMED_IAM


lambda.local:
	sam local invoke -t ${LAMBDA_TEMPLATE} --parameter-overrides ${LAMBDA_PARAMS} --env-vars etc/envvars.json -e etc/event.json Fn | jq
lambda.invoke.sync:
	aws --profile ${PROFILE} lambda invoke --function-name ${O_FN} --invocation-type RequestResponse --payload file://etc/event.json --cli-binary-format raw-in-base64-out --log-type Tail tmp/fn.json | jq "." > tmp/response.json
	cat tmp/response.json | jq -r ".LogResult" | base64 --decode
	cat tmp/fn.json | jq
lambda.invoke.async:
	aws --profile ${PROFILE} lambda invoke --function-name ${O_FN} --invocation-type Event --payload file://etc/event.json --cli-binary-format raw-in-base64-out --log-type Tail tmp/fn.json | jq "."

xacct: xacct.package xacct.deploy
xacct.package:
	sam package --profile ${PROFILE_XACCT} -t ${XACCT_TEMPLATE} --output-template-file ${XACCT_OUTPUT} --s3-bucket ${S3BUCKET_XACCT}
xacct.deploy:
	sam deploy --profile ${PROFILE_XACCT} -t ${XACCT_OUTPUT} --stack-name ${XACCT_STACK} --parameter-overrides ${XACCT_PARAMS} --capabilities CAPABILITY_NAMED_IAM

layer: layer.package layer.deploy
lambda.prepare:
	rm -rf layer && mkdir -p layer/python && pip install boto3 -t layer/python
layer.package:
	sam package -t ${LAYER_TEMPLATE} --output-template-file ${LAYER_OUTPUT} --s3-bucket ${S3BUCKET}
layer.deploy:
	sam deploy -t ${LAYER_OUTPUT} --stack-name ${LAYER_STACK} --parameter-overrides ${LAYER_PARAMS} --role-arn ${O_CFN_ROLE} --capabilities CAPABILITY_NAMED_IAM
layer.signed: layer.package.signed layer.deploy
layer.package.signed:
	sam package -t ${LAYER_TEMPLATE} --output-template-file ${LAYER_OUTPUT} --s3-bucket ${S3VERSIONED} --signing-profiles ${SIGNING_PROFILES}
