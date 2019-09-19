#!/usr/bin/env bash

ENVIRONMENT_NAME_SUFFIX=-env
DIR=$(pwd)
SEED_TEMPLATE=$DIR/1-seed.yml
CONTAINERS_TEMPLATE=$DIR/2-containers.yml

deploy(){
  SEED_STACK=$1-seed
	aws --profile pvitic-administrator \
	    --region eu-central-1 \
	    --debug cloudformation deploy \
      --stack-name $SEED_STACK \
      --template $SEED_TEMPLATE \
      --capabilities CAPABILITY_NAMED_IAM \
  && echo "export AWS_ACCESS_KEY_ID=$(aws cloudformation describe-stacks --stack-name $SEED_STACK | \
      jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "AccessKey") | .OutputValue')" >> .env \
  && echo "export AWS_SECRET_ACCESS_KEY=$(aws cloudformation describe-stacks --stack-name $SEED_STACK | \
      jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "SecretKey") | .OutputValue')" >> .env \
  && echo "export BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name $SEED_STACK | \
    jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "BucketName") | .OutputValue')" >> .env \
  && source .env \
  && aws sts get-caller-identity \
  && aws --debug s3 cp . s3://$BUCKET_NAME/ --recursive --exclude "*" --include "*.yml"

  CONTAINERS_STACK=$1-containers
  aws --debug cloudformation deploy \
      --stack-name $CONTAINERS_STACK \
      --template $CONTAINERS_TEMPLATE \
      --parameter-overrides ImageRepositoryName=mongodb

  rm .env
}

delete(){
  # TODO delete containers then delete seed
	aws --profile pvitic-administrator \
	    --region eu-central-1 \
	    --debug cloudformation delete-stack \
      --stack-name $1
}


if [ $# -ne 1 ]; then
  echo 1>&2 "Usage: $0 environment action"
  exit 3
fi

ACTION=$1

case $ACTION in
deploy)
  ENVIRONMENT_NAME=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 8 | head -n 1)$ENVIRONMENT_NAME_SUFFIX
  echo "Deploying ${ENVIRONMENT_NAME} environment"
  deploy "$ENVIRONMENT_NAME"
  ;;
delete)
  if [ -z "$2" ]
  then
      echo ERROR: "delete requires environment id"
      exit 1
  else
      ENVIRONMENT_NAME=$2$ENVIRONMENT_NAME_SUFFIX
      echo "Deleting ${ENVIRONMENT_NAME} environment"
      delete "$ENVIRONMENT_NAME"
  fi
  ;;
*)
    echo "-- Action Options --"
    echo "deploy : Deploys environment"
    echo "delete : Deletes environment"
esac
