#!/usr/bin/env bash

DIR=$(pwd)
ENVIRONMENT_USERS_TEMPLATE=$DIR/1-environment-users.yml

deploy(){
	aws --profile pvitic-administrator \
	    --region eu-central-1 \
	    --debug cloudformation deploy \
      --stack-name $1 \
      --template $ENVIRONMENT_USERS_TEMPLATE \
      --capabilities CAPABILITY_NAMED_IAM \
  && aws cloudformation describe-stacks \
      --stack-name $1 | \
      jq -r '.Stacks[0].Outputs[]'
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
