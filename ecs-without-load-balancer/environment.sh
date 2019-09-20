#!/usr/bin/env bash

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
      --parameter-overrides StackRootName=$1 \
  && echo "export AWS_ACCESS_KEY_ID=$(aws cloudformation describe-stacks --stack-name $SEED_STACK | \
      jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "AccessKey") | .OutputValue')" >> .env \
  && echo "export AWS_SECRET_ACCESS_KEY=$(aws cloudformation describe-stacks --stack-name $SEED_STACK | \
      jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "SecretKey") | .OutputValue')" >> .env \
  && BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name $SEED_STACK | \
    jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "BucketName") | .OutputValue') \
  && source .env \
  && aws sts get-caller-identity \
  && aws --debug s3 cp . s3://$BUCKET_NAME/ --recursive --exclude "*" --include "*.yml"

  CONTAINERS_STACK=$1-containers
  aws --debug cloudformation deploy \
      --stack-name $CONTAINERS_STACK \
      --template $CONTAINERS_TEMPLATE \
      --parameter-overrides StackRootName=$1 ImageRepositoryName=$1-mongodb \
  && IMAGE_NAME=$(aws cloudformation describe-stacks --stack-name $CONTAINERS_STACK | \
    jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "ContainerRepoURI") | .OutputValue') \
  && cd mongodb \
  && echo "logging into AWS Container repository" \
  && $(aws ecr get-login --region eu-central-1 --no-include-email) \
  && echo "building image ${IMAGE_NAME}" \
  && docker build -t ${IMAGE_NAME} . \
  && echo "pushing image ${IMAGE_NAME}" \
  && docker push ${IMAGE_NAME} \
  && cd ../

  rm $DIR/.env
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
  ENVIRONMENT_ID=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 8 | head -n 1)
  echo "Deploying ${ENVIRONMENT_ID} environment"
  deploy "$ENVIRONMENT_ID"
  ;;
delete)
  if [ -z "$2" ]
  then
      echo ERROR: "delete requires environment id"
      exit 1
  else
      ENVIRONMENT_ID=$2
      echo "Deleting ${ENVIRONMENT_ID} environment"
      delete "$ENVIRONMENT_ID"
  fi
  ;;
*)
    echo "-- Action Options --"
    echo "deploy : Deploys environment"
    echo "delete : Deletes environment"
esac
