#!/bin/bash

# BASICS -----------------------------------------------------------------------
# shell options: extended globbing
shopt -qs extglob
set -x
declare -Ax config script

# --  DEFAULTS
script[name]="${0##*/}"


export DEFAULT_IPTABLES_SAVED_CONFIGURATION_FILE="/etc/network/iptables.rules"
config[output_dir]="/etc/ipth/saved"
export UNLOAD_FIREWALL_VALUE="" #if set this variable can override default rules enabling (in order to flush all ipth managed chains)


# --  HEADERS
print_usage() {
 echo 'usage:'${script[name]}' $templatefile $ipthfile $action[enable/disable/save]'
}
config[ipth_file]=$1
config[template_file]=$2
IPTH_ACTION=${3:-enable}


[[ "$BASH"  =~ ^.*bash$ ]] || {
    echo 'script is only bash compatible at the moment > '"$0"
    exit 1
}

[ ! -f "${config[ipth_file]}" ] && {
    echo 'invalid ipth file path > '"${config[ipth_file]}"
    print_usage
    exit 1
}


[ ! -f "${config[template_file]}" ] && {
    echo 'invalid template file path > '"${config[template_file]}"
    print_usage
    exit 1
}




[ -d "${config[output_dir]}" ] || mkdir -p "${config[output_dir]}"



save_pre_execution_iptables_config(){
  sudo sh -c "iptables-save > ${config[output_dir]}/saved_pre_test.rules"
  local tmp_save_filename='ipth_'$(date +%s)'_pre_test.rules'
  sudo sh -c "iptables-save > /tmp/${tmp_save_filename}"
}

run_test(){
    save_pre_execution_iptables_config
}

. ${config[ipth_file]}
. ${config[template_file]}


echo '... checking version'
ipth_check_version $IPTH_TEMPLATE_VERSION || {
exit 1
}

#####  ACTION ---> SAVE
[ "$IPTH_ACTION" == "save" ] && {
    #save iptables current configuration and exit
    iptables_save_without_docker $DEFAULT_IPTABLES_SAVED_CONFIGURATION_FILE
    echo 'current iptables configuration (without docker chains) saved in '$DEFAULT_IPTABLES_SAVED_CONFIGURATION_FILE
    exit 0
}


#####  ACTION ---> DISABLE
if [ $IPTH_ACTION == "disable" ]; then
    echo '... [ACTION] > DISABLE , template will be executed with default-disabled-param'
    export UNLOAD_FIREWALL_VALUE="0"
fi



echo '... set default accept policy'
set_default_accept_policy

save_pre_execution_iptables_config

echo '... applying template'
ipth_template

exit 0