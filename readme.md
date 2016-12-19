## DOCKER IPTABLES HELPER:
this application is used as library for template files to handle iptables manipulation without having to reboot iptables
have the work `DOCKER` in the name because I've used it mainly for docker, which uses iptables for his networking
so I cannot flush the whole iptables at whill while doing firewalling,
this application inject custom chains at the begin/end of main iptables chain and manage only those, so no firewall flush
is required to update the rules (more idemnpotent behaviour)


# usage:
```
export APP_SRC="......" # exact to pyiptdocker.py files 
export TEMPLATE_SRC="......" # full path to python-pyipth template file 
export PYTHONPATH=$PYTHONPATH:$APP_SRC; python $TEMPLATE_SRC --verbose

## save results for iptables-restore that run after reboot ( so rules are applied immediately after network is available ) 
python $APP_SRC/pyiptdocker.py --save-rules

```

## DOCKERZIED RUN: docker require capabilities to run iptables 
 `docker run --rm -ti --cap-add=NET_ADMIN quay.io/fravi/env-fatubuntu1604 iptables -nvL`  




## TODO
create tests everywhere and refactor the design to made the application easier to use 


# docker iptables helper
## add iptables rules in custom chain without interfering with docker


## NB:
 - templated blank lines or starting with # will be stripped
 - some words are stripped from iptables-save operations to avoid conflicts with DOCKER / K8S
  so avoid using anywhere in the template the words :
  - "docker0"
  - ":docker"
  - "kube-"
  

