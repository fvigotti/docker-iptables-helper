## DOCKER IPTABLES HELPER:
this application is used as library for template files to handle iptables manipulation without having to reboot iptables
have the work `DOCKER` in the name because I've used it mainly for docker, which uses iptables for his networking
so I cannot flush the whole iptables at whill while doing firewalling,
this application inject custom chains at the begin/end of main iptables chain and manage only those, so no firewall flush
is required to update the rules (more idempotent behaviour)

## this repo is public!
 - https://gitlab.com/fravi/docker-iptables-helper
 - quay.io/fravi/pyipth

# usage:
```
export APP_SRC="......" # exact to pyiptdocker.py files 
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


# docker image usage :
```
#build
docker build -t ipth .

## test iptables 
docker run --rm -ti --cap-add=NET_ADMIN ipth iptables -nvL

## test application correctly installed 
docker run --rm -ti --cap-add=NET_ADMIN --net=host ipth python /usr/bin/pyiptdocker.py --test  

## execute library :
TEMPLATE_PATH=$(cd ./test && pwd)'/pyiptdocker_template_test.py'
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
  

