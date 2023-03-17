## Code Signing with Lambda
This repository implements a number of governance controls for signing function zip files and layers when deploying Lambda functions.

### Pre-requisites
First we need to setup `etc/environment.sh` for use with our `makefile`. Note that we'll use an `S3BUCKET` bucket with versioning disabled and an `S3VERSIONED` bucket with versioning enabled. Versioning is required when doing signed deployments.

```bash
PROFILE=aws-cli-profile
REGION=aws-region
S3BUCKET=aws-sam-cli-bucket-for-templates
S3VERSIONED=aws-sam-cli-bucket-for-templates-versioned

IAM_STACK=controls-deployment-role
IAM_TEMPLATE=iac/iam.yaml
IAM_OUTPUT=iac/iam_output.yaml
IAM_PARAMS="ParameterKey=pBucket,ParameterValue=${S3BUCKET}"
O_CFN_ROLE_ARN=output-for-cfn-role

P_VALID_DAYS=31
SIGNER_STACK=controls-signer
SIGNER_TEMPLATE=iac/signer.yaml
SIGNER_OUTPUT=iac/signer_output.yaml
SIGNER_PARAMS="ParameterKey=pValidDays,ParameterValue=${P_VALID_DAYS}"
O_SIGNER_ARN=output-for-signer-arn
O_SIGNER_ID=output-for-signer-id
O_SIGNING_CONFIG_ARN=output-for-signing-config-arn

P_NAME=python3-xray
P_DESCRIPTION=xray-2.11.0-signed
P_SIGNING_PROFILES_LAYER="LayerXray=${O_SIGNER_ID}"
LAYER_STACK=controls-layer
LAYER_TEMPLATE=iac/layer.yaml
LAYER_OUTPUT=iac/layer_output.yaml
LAYER_PARAMS="ParameterKey=pName,ParameterValue=${P_NAME} ParameterKey=pDescription,ParameterValue=${P_DESCRIPTION}"
O_LAYER_ARN=output-from-layer-arn
O_LAYER_VERSION_NUMBER=version-number-from-layer-arn

P_FN_MEMORY=128
P_FN_TIMEOUT=15
P_SIGNING_PROFILES_FN="Fn=${O_SIGNER_ID}"
LAMBDA_STACK=controls-function
LAMBDA_TEMPLATE=iac/lambda.yaml
LAMBDA_OUTPUT=iac/lambda_output.yaml
LAMBDA_PARAMS="ParameterKey=pFnMemory,ParameterValue=${P_FN_MEMORY} ParameterKey=pFnTimeout,ParameterValue=${P_FN_TIMEOUT} ParameterKey=pLayerArn,ParameterValue=${O_LAYER_ARN} ParameterKey=pSigningConfigArn,ParameterValue=${O_SIGNING_CONFIG_ARN}"
O_FN=output-for-function-id
```

With the environment configuration set, we'll now deploy a few stacks.

### Governance IAM Role
We're creating an IAM role under which all other actions will be governed. This emulates the same behavior as enterprises that deploy via pipeline toolchains, which assume IAM roles for performing actions within an AWS account.

You can deploy the IAM role using: `make iam`
* Update the `O_CFN_ROLE_ARN` output variable in `etc/environment.sh` with the output from the deployment.

### Signer
Next we'll create the signing profile and signing configuration: `make signer`.
* Update `O_SIGNER_ARN`, `O_SIGNER_ID`, and `O_SIGNING_CONFIG_ARN` with the output from the deployment.

### Layer
Next we'll prepare the layer directory and perform a signed deployment. First we'll install the Python `aws-xray-sdk` library locally: `make layer.prepare`

Next we'll perform a signed deployment: `make layer.signed`
* Update `O_LAYER_ARN` with the output from the deployment.
* Update `O_LAYER_VERSION_NUMBER` with the version number of the deployed layer.

### Function
Finally we'll deploy a function with the signed layer and a signed zip deployment: `make lambda.signed`
* Update `O_FN` with the output from the deployment.

Test the function by running: `make lambda.invoke.sync`.

### Test Unsigned Deployments
And now test a deployment with an unsigned zip deployment, which will fail: `make lambda.unsigned`

You should see an error message as follows:
```
Resource handler returned message: "Lambda cannot deploy the function. The function or layer might be signed using a signature that the client is not configured to accept. Check the provided signature for arn:aws:lambda:{REGION}:{ACCOUNTID}:function:{FUNCTIONID}. (Service: Lambda, Status Code: 400, Request ID: b9f228eb-35a5-4601-b4ad-4564d8c4aae1)" (RequestToken: c950e133-5d4a-c673-bab8-c3cd2b081406, HandlerErrorCode: InvalidRequest)
```
