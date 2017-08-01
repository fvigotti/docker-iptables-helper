## DOCKER IPTABLES HELPER:
this application is used as library for template files to handle iptables manipulation without having to reboot iptables
this project have the word `DOCKER` in the name because I've used it mainly for docker/kubernetes , which uses iptables for his networking
so I cannot flush the whole iptables at will while doing firewalling,
this application inject custom chains at the begin/end of main iptables tables/chains and manage only those, so no firewall flush
is required to update the rules (idempotent behaviour)

## this repo is public!
 - https://gitlab.com/fravi/docker-iptables-helper
 - quay.io/fravi/pyipth
 - latest stable : quay.io/fravi/pyipth@sha256:d0ed69851f4c85795ac20673ec4f845fe3bccee98eaa9843d5b722a63b538a84
 
# usage:
```
export APP_SRC="......" # exact path to pyiptdocker.py file ( this application )  
export TEMPLATE_SRC="......" # full path to python-pyipth template file 
export PYTHONPATH=$PYTHONPATH:$APP_SRC; python $TEMPLATE_SRC --verbose

## save results for iptables-restore that run after reboot ( so rules are applied immediately after network is available ) 
python $APP_SRC/pyiptdocker.py --save-rules

## use the ( apt installable) script iptables-persistent to manage the reload of rules , 
    there are anyway more customizable ways 
     - bind the script load to network devices start
     - create custom init script that use iptables restore
```

## DOCKERZIED RUN: docker require capabilities to run iptables 
 `docker run --rm -ti --cap-add=NET_ADMIN quay.io/fravi/env-fatubuntu1604 iptables -nvL`  





## TODO
create tests everywhere and refactor the design to made the application easier to use
- at the moment chain placed as first rules in other chains are not enforced 
  this means that rules are created as first jump-rule but nothing ensure that this jump remain the first
  so new inserted rules ( like the KUBE*  DOCKER* rules ) are placed above  

- if the policy doesn't exist, and has been just created, the program try to delete it , but the command that uses return error:
  ie: 
  ```
        "2017-02-09 16:40:49,310 root         DEBUG    [deleteAllCustomChains] _ end",                                                                                                                              
        "2017-02-09 16:40:49,310 root         CRITICAL configuration cleaned, EXITING",                                                                                                                             
        "2017-02-09 16:40:49,310 root         CRITICAL !!!! FATAL ERROR,  command failed , exiting rc = 1 , command = /sbin/iptables -n -t nat -L ipth_last_nat_PREROUTING --line-number , stderr = iptables: No chain/target/match by that name. , stdout =  ",                                                                                                                                                                        
        "failPolicy_CleanIptablesAndExit"
    ], 
    "warnings": []
  ```
    
    
# docker image usage :
```
#build
docker build -t ipth .

## test iptables 
docker run --rm -ti --cap-add=NET_ADMIN ipth iptables -nvL

## test application correctly installed 
docker run --rm -ti --cap-add=NET_ADMIN --net=host ipth python /usr/bin/pyiptdocker.py --test  

## flush all firwall rules 
docker run --rm -ti --cap-add=NET_ADMIN --net=host ipth bash /usr/bin/stop-firewall.sh  

## execute library :
TEMPLATE_PATH=$(cd ./test && pwd)'/sample/pyiptdocker_template_test.py'
docker run --rm -ti --cap-add=NET_ADMIN --net=host -v $TEMPLATE_PATH:/opt/template.py:ro  ipth python /opt/template.py
 
 
 
## more tests using docker and templated sample rules :
TEMPLATE_PATH=$(cd ./test && pwd)'/sample/1_add_some_rules.py'
docker run --rm -ti --cap-add=NET_ADMIN --net=host -v $TEMPLATE_PATH:/opt/template.py:ro  ipth python /opt/template.py
 
## removed custom chains 
TEMPLATE_PATH=$(cd ./test && pwd)'/sample/2_delete_cusotm_chains.py'
docker run --rm -ti --cap-add=NET_ADMIN --net=host -v $TEMPLATE_PATH:/opt/template.py:ro  ipth python /opt/template.py


## removed custom chains using default unintstall  
TEMPLATE_PATH=$(cd ./test && pwd)'/sample/2_delete_cusotm_chains.py'
docker run --rm -ti --cap-add=NET_ADMIN --net=host -v $TEMPLATE_PATH:/opt/template.py:ro  ipth python /usr/bin/pyiptdocker.py --uninstall --verbose


### save rules :
docker run --rm -ti --cap-add=NET_ADMIN --net=host -v /etc/iptables:/etc/iptables:rw  ipth python /usr/bin/pyiptdocker.py --save-rules

```

## update remote repo manually:
docker build -t quay.io/fravi/pyipth .
docker push quay.io/fravi/pyipth:latest


## NB:
 - templated blank lines or starting with # will be stripped
 - some words are stripped from iptables-save operations to avoid conflicts with DOCKER / K8S
  so avoid using anywhere in the template the words :
  - "docker0"
  - ":docker"
  - "kube-"
  

