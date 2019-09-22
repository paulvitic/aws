#!/usr/bin/env bash

REGION=eu-central-1
DIR=$(pwd)
USERS=users
STORAGE=storage
CONTAINERS=containers
ENVIRONMENT=environment

createUsers(){
  TEMPLATE=$DIR/1-$USERS.yml
  STACK=$1-$USERS

  echo Creating admin user for environment $1
  aws --profile pvitic-administrator \
	    --region $REGION \
	    cloudformation deploy \
      --stack-name $STACK \
      --template $TEMPLATE \
      --capabilities CAPABILITY_NAMED_IAM \
      --parameter-overrides StackRootName=$1

}

loginEvironmentAdmin() {
  STACK=$1-$USERS

  echo "export AWS_ACCESS_KEY_ID=$(aws cloudformation describe-stacks --stack-name $STACK | \
      jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "AccessKey") | .OutputValue')" >> .env \
  && echo "export AWS_SECRET_ACCESS_KEY=$(aws cloudformation describe-stacks --stack-name $STACK | \
      jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "SecretKey") | .OutputValue')" >> .env \
  && source .env

  echo Switched to user:
  aws sts get-caller-identity
}

deleteUsers(){
  STACK=$1-$USERS

  echo Deleting stack $STACK
  aws --profile pvitic-administrator \
	    --region eu-central-1 \
	    cloudformation delete-stack --stack-name $STACK \
	&& aws --profile pvitic-administrator \
	      --region eu-central-1 \
	      cloudformation wait stack-delete-complete --stack-name $STACK
}

createStorage(){
  TEMPLATE=$DIR/2-$STORAGE.yml
  STACK=$1-$STORAGE

  echo Creating storage for environment $1
  aws cloudformation deploy \
      --stack-name $STACK \
      --template $TEMPLATE \
      --parameter-overrides StackRootName=$1

  echo Uploading cloud formation templates to storage
  BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name $STACK | \
    jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "BucketName") | .OutputValue') \
  && aws s3 cp . s3://$BUCKET_NAME/ --recursive --exclude "*" --include "*.yml"

}

deleteStorage() {
  STACK=$1-$STORAGE

  BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name $STACK | \
    jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "BucketName") | .OutputValue')

  echo Emtying bucket $BUCKET_NAME
  aws s3 rm s3://$BUCKET_NAME --recursive

  echo Deleting stack $STACK
  aws --region eu-central-1 cloudformation delete-stack --stack-name $STACK \
  && aws --region eu-central-1 cloudformation wait stack-delete-complete --stack-name $STACK
}

createContainerRepos(){
  TEMPLATE=$DIR/3-$CONTAINERS.yml
  STACK=$1-$CONTAINERS

  aws cloudformation deploy \
      --stack-name $STACK \
      --template $TEMPLATE \
      --parameter-overrides StackRootName=$1 ImageRepositoryName=$1-mongodb \
  && pushImage "$STACK"
}

deleteContainerRepos(){
  STACK=$1-$CONTAINERS

  IMAGES=$(aws ecr describe-images --repository-name $1-mongodb --output json | jq '.[]' | jq '.[]' | jq -r '.imageDigest')
  for IMAGE in ${IMAGES[*]}; do
    echo "Deleting $IMAGE"
    aws ecr batch-delete-image --repository-name $1-mongodb --image-ids imageDigest=$IMAGE
  done

  echo deleteing stack $STACK
  aws --region eu-central-1 cloudformation delete-stack --stack-name $STACK \
  && aws --region eu-central-1 cloudformation wait stack-delete-complete --stack-name $STACK
}

pushImage(){
  IMAGE_NAME=$(aws cloudformation describe-stacks --stack-name $1 | \
    jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "ContainerRepoURI") | .OutputValue') \
  && cd mongodb \
  && echo "logging into AWS Container repository" \
  && $(aws ecr get-login --region eu-central-1 --no-include-email) \
  && echo "building image ${IMAGE_NAME}" \
  && docker build -t ${IMAGE_NAME} . \
  && echo "pushing image ${IMAGE_NAME}" \
  && docker push ${IMAGE_NAME} \
  && cd ../
}

deploy(){
  START=`date +%s`
  createUsers "$1" \
  && loginEvironmentAdmin "$1" \
  && createStorage "$1" \
  && createContainerRepos "$1" \
  && END=`date +%s` \
  && echo $1 deployed in $((END-START)) seconds

  rm $DIR/.env
}

delete(){
  START=`date +%s`

  loginEvironmentAdmin "$1" \
  && deleteContainerRepos "$1" \
  && deleteStorage "$1" \
  && deleteUsers "$1" \
  && END=`date +%s` \
  && echo $1 deleted in $((END-START)) seconds

  rm $DIR/.env
}

#deploy(){

#  CONTAINERS_STACK=$1-containers
#
#
#  ENVIRONMENT_STACK=$1-environment
#  aws --debug cloudformation deploy \
#      --stack-name $ENVIRONMENT_STACK \
#      --template $ENVIRONMENT_TEMPLATE \
#      --parameter-overrides StackRootName=$1
#
#  rm $DIR/.env
#}



#if [ $# -ne 1 ]; then
#  echo 1>&2 "Usage: $0 environment action"
#  exit 3
#fi

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
