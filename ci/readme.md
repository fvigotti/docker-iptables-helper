# usage:

  ## step 1: extract tag and version from git 
  ./ci/buildCurrentVersionName.sh
    
      will create 3 files that can be read with with branch, 
      version name and current tag
      build.name   , ie : master.20161103.155043.a727bf9 
      tag.name   ,  ie : master-v0.1 
      
      these files can be read from the ci, ie, with jenkins:
       def buildname = readFile 'build.name'
       def tagname = readFile 'tag.name'
       def branchname = readFile 'branch.name'
  ## step 2:
   build the image  
   `$$$ARGS$$$ ./ci/buildImage.sh`  
   ie:   
   `DOCKER_REPO="quay.io/fravi" PUSH_SHA=1 PUSH_LATEST=1 PUSH_TAG=1 IMAGENAME="images-ci-scripts" ./ci/buildImage.sh`
   
             
 | ARGS| |
 |---|---|
 | DOCKER_BUILD_OPTS | additional build options, ie: --network=host --compress --squash |
 | PUSH_SHA | create a tagged image with unique id, and push aswell |
       
     

     
### to update those scripts:
from project directory
```bash
docker pull quay.io/fravi/ci-imagebuilder:latest
OWNERID=$(stat -c '%u' ./)
docker run --rm -ti -e OWNERID=${OWNERID} -v `pwd`/ci:/target quay.io/fravi/ci-imagebuilder:latest




```
