#!/usr/bin/env bash

DIR=$(pwd)
ENV_ADMIN_STORAGE_TEMPLATE=$DIR/1-environment-admin-storage.yml

deploy(){
	aws --profile pvitic-administrator \
	    --region eu-central-1 \
	    --debug cloudformation deploy \
      --stack-name $1 \
      --template $ENV_ADMIN_STORAGE_TEMPLATE \
      --capabilities CAPABILITY_NAMED_IAM \
  && echo "export AWS_ACCESS_KEY_ID=$(aws cloudformation describe-stacks --stack-name $1 | \
      jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "AccessKey") | .OutputValue')" >> .env \
  && echo "export AWS_SECRET_ACCESS_KEY=$(aws cloudformation describe-stacks --stack-name $1 | \
      jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "SecretKey") | .OutputValue')" >> .env \
  && echo "export BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name $1 | \
    jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "BucketName") | .OutputValue')" >> .env \
  && source .env \
  && aws sts get-caller-identity \
  && aws --debug s3 cp . s3://$BUCKET_NAME/ --recursive --exclude "*" --include "*.yml"
  rm .env
}

delete(){
	aws --profile pvitic-administrator \
	    --region eu-central-1 \
	    --debug cloudformation delete-stack \
      --stack-name $1
}


if [ $# -ne 2 ]; then
  echo 1>&2 "Usage: $0 environment action"
  exit 3
fi

ENVIRONMENT_NAME=$1
ACTION=$2

case $ACTION in
deploy)
  echo "Deploying ${ENVIRONMENT_NAME} environment"
  deploy "$ENVIRONMENT_NAME"
  ;;
delete)
  echo "Deleting ${ENVIRONMENT_NAME} environment"
  delete "$ENVIRONMENT_NAME"
  ;;
*)
    echo "-- Action Options --"
    echo "deploy : Deploys environment"
    echo "delete : Deletes environment"
esac
