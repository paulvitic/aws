#!/usr/bin/env bash

DIR=$(pwd)
CLOUDFORMATION_TEMPLATE=$DIR/peof-ecr.yml
STACK_NAME_PREFIX=peof
STACK_NAME_SUFFIX=container-repo

deploy(){
	aws --profile pvitic-administrator \
	    --region eu-central-1 \
	    --debug cloudformation deploy \
        --stack-name $1 \
        --template $CLOUDFORMATION_TEMPLATE \
        --parameter-overrides PEOFRepositoryName=$2
}

delete(){
	aws --profile pvitic-administrator \
	    --region eu-central-1 \
	    --debug cloudformation delete-stack \
        --stack-name $1
}


if [ $# -ne 2 ]; then
  echo 1>&2 "Usage: $0 Option Project"
  exit 3
fi

OPTION=$1
PROJECT=$2
STACK_NAME=$STACK_NAME_PREFIX-$PROJECT-$STACK_NAME_SUFFIX
REPOSITORY_NAME=$STACK_NAME_PREFIX-$PROJECT

case $OPTION in
deploy)
  echo "Deploying ${STACK_NAME} stack"
  deploy "$STACK_NAME" "$REPOSITORY_NAME"
  ;;
delete)
  echo "Deleting ${STACK_NAME} stack"
  delete "$STACK_NAME"
  ;;
*)
    echo "Did you forget something!! [ deploy | delete ]"
    echo "-- Options --"
    echo "deploy : Deploys stack"
    echo "delete : Deletes stack"
esac
