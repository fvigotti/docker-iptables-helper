#!/usr/bin/env bash
set -xe
#
#  VERSION BUILDS BASED ON `version` file content
#  versioned branch are branch with vNN.NN name syntax
#
#

export SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export PROJECT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd ) # escape "ci" dir

# constants
export VERSION_NAME_TMP_FILE='build.name' # this file will contain generated version name
export TAG_NAME_TMP_FILE='tag.name' # this file will contain generated version name
export BRANCH_NAME_TMP_FILE='branch.name' # this file will contain generated version name


## enter main project dir
cd $PROJECT_DIR


## there are needed because commit will be cherry picked from jenkins plugin so easier ways to retrieve those informations do not work
getShortCommitHash(){
  echo $(git rev-parse --short HEAD)
}

getCurrentBranch(){
  echo $(git for-each-ref --sort=-committerdate --format='%(refname:short) %(objectname)' | grep "$(git rev-parse HEAD)"  | head -1 | cut -d" " -f 1 | cut -d '/' -f 2)
  # | grep origin
}

# ie: 20160729.153549
buildVersionDateTag(){
  date +'%Y%m%d.%H%M%S'
}

getCurrentTag(){
  git describe --exact-match --tags $(git rev-parse HEAD) 2>/dev/null || echo ''
}

export BUILD_NAME=$(getCurrentBranch)'.'$(buildVersionDateTag)'.'$(getShortCommitHash)

echo $BUILD_NAME > "${VERSION_NAME_TMP_FILE}"
echo $(getCurrentBranch) > "${BRANCH_NAME_TMP_FILE}"
echo $(getCurrentTag)  > "${TAG_NAME_TMP_FILE}"

