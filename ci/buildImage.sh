#!/usr/bin/env bash
set -xe

## ACCEPTED ENV VARIABLES :
export DOCKER_REPO=${DOCKER_REPO:-test}
export PUSH_SHA=${PUSH_SHA:-0} # IF 1 , image will be pushed to docker repository
export PUSH_TAG=${PUSH_TAG:-0} # IF 1 , image will be pushed to docker repository
export PUSH_LATEST=${PUSH_LATEST:-0} # IF 1 , image will be pushed to docker repository
export IMAGENAME=${IMAGENAME?} # IF 1 , image will be pushed to docker repository


export SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export PROJECT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )

if [ -z $DOCKERFILE_DIR ]; then
export DOCKERFILE_DIR=$PROJECT_DIR"/src/"
fi

cd $DOCKERFILE_DIR

# constants
export VERSION_NAME_TMP_FILE='build.name' # this file will contain generated version name
export TAG_NAME_TMP_FILE='tag.name' # this file will contain generated version name
export BRANCH_NAME_TMP_FILE='branch.name' # this file will contain generated version name


if [ -z "${IMAGENAME}" ]; then
  echo " please provide imagename! "
  exit 1;
fi

DOCKER_BUILD_OPTS=${DOCKER_BUILD_OPTS:-} # ie : --network=host 

export TAG_WITH_SHA=$(cat "${PROJECT_DIR}/${VERSION_NAME_TMP_FILE}")
export SCM_TAG_DATA=$(cat "${PROJECT_DIR}/${TAG_NAME_TMP_FILE}")
export SCM_BRANCH_NAME_DATA=$(cat "${PROJECT_DIR}/${BRANCH_NAME_TMP_FILE}")


docker build ${DOCKER_BUILD_OPTS} -t ${DOCKER_REPO}/${IMAGENAME}:${TAG_WITH_SHA} .
docker tag  ${DOCKER_REPO}/${IMAGENAME}:${TAG_WITH_SHA} ${DOCKER_REPO}/${IMAGENAME}:latest

echo 'docker image ->'${DOCKER_REPO}/${IMAGENAME}:${TAG_WITH_SHA}'<- built ! '

if [[ ${PUSH_SHA} -eq 1 ]]; then
  docker push ${DOCKER_REPO}/${IMAGENAME}:${TAG_WITH_SHA}
    echo 'docker image SHA ->'${DOCKER_REPO}/${IMAGENAME}:${TAG_WITH_SHA}'<- pushed ! '
fi
if [[ ${PUSH_LATEST} -eq 1 ]]; then
  docker push ${DOCKER_REPO}/${IMAGENAME}:latest
  echo 'docker image LATEST ->'${DOCKER_REPO}/${IMAGENAME}:latest'<- pushed ! '

fi


if [ ! -z "${SCM_TAG_DATA}"  ] && [  ! -z "${SCM_BRANCH_NAME_DATA}" ]; then ## if TAG VERSION exists
  export BRANCH_AND_TAG=$SCM_BRANCH_NAME_DATA'-'$SCM_TAG_DATA
  docker tag  ${DOCKER_REPO}/${IMAGENAME}:${TAG_WITH_SHA} ${DOCKER_REPO}/${IMAGENAME}:${BRANCH_AND_TAG}
  echo 'docker image tag ->'${DOCKER_REPO}/${IMAGENAME}:${BRANCH_AND_TAG}'<- built ! '
  if [[ ${PUSH_TAG} -eq 1 ]]; then
    echo 'docker image tag ->'${DOCKER_REPO}/${IMAGENAME}:${BRANCH_AND_TAG}'<- pushed ! '
    docker push ${DOCKER_REPO}/${IMAGENAME}:${BRANCH_AND_TAG}
  fi
fi