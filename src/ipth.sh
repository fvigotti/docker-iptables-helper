#!/bin/bash

# BASICS -----------------------------------------------------------------------
# shell options: extended globbing
shopt -qs extglob

# global arrays: script metadata, user config, user commands
declare -Ax script config
script[version]='1.1'
script[name]="${0##*/}"
script[pid]=$$
script[cmd_prefix]='cmd:'
script[verb_levels]='debug info status warning error critical fatal'
script[verb_override]=3
script[external_programs]='which iptables iptables-save iptables-restore tc sysctl readlink sed sort'

# USER CONFIG -----------------------------------------------------------------
# make sure this contains the path for "which", otherwise the script will abort
# in doubt type "which which"
config[which]='/usr/bin/which'

declare -Ax default_ipt_chains
default_ipt_chains[nat]='PREROUTING INPUT OUTPUT POSTROUTING'
default_ipt_chains[filter]='INPUT FORWARD OUTPUT'
default_ipt_chains[mangle]='PREROUTING FORWARD INPUT OUTPUT POSTROUTING'
default_ipt_chains[raw]='PREROUTING OUTPUT'
default_ipt_chains[security]='INPUT FORWARD OUTPUT'

# /sbin/iptables
export _ipt=$(which iptables)
export _ipt_save=$(which iptables-save)

ipth_check_version () {
REQUIRED_VERSION=$1
[ "${script[version]}" == "$REQUIRED_VERSION" ] || {
echo 'invalid version.. current = '"${script[version]}"' , required = '$REQUIRED_VERSION
return 1 ;
}
}

ipth_forced_unload_or_value(){
local custom_value=$1
echo ${UNLOAD_FIREWALL_VALUE:-$custom_value}
}

find_chain_exists(){
# search for a chain into a table
# return true (in bash is "return 0") if chain exists , false if not
local table_source=$1
local chain_to_search=$2
#local count_found=$(iptables  -L -n --line-number -t $table_source | awk '$2 ~ "^'${chain_to_search}'$" {print $2}' | wc -l )
local found=$(iptables  -L $chain_to_search -n -t $table_source 2>&1 >/dev/null && echo 'yes' || echo 'no' )
[ "$found" == "yes" ] && return 0 || return 1
}

if_exists_recusively_delete_chain() {
local table=$1
local chain=$2
if find_chain_exists $table $chain ; then
    recursive_delete_chain $table $chain
fi
}


find_jumpchain_rule_number (){
# search a jump chain rule number into another source-chain
# sample
# iptables -L FORWARD -n  --line-number  -t filter  | awk '$2 ~ "^DOCKER$"  {print  $1 }'
# @return 0 if not found
local table_source=$1
local chain_source=$2
local chain_to_search=$3
local retval=$(iptables  -L $chain_source -n  --line-number  -t $table_source | awk '$2 ~ "^'${chain_to_search}'$" {print $1}')
retval=${retval:-0}
echo $retval
}

delete_chain_references_in_default_chains (){
# search for chain references and delete them
# return amount of deleted references

local chain_to_search=$1
local table_name=$2
local COUNTER=0

for def_chain_name in ${default_ipt_chains[$table_name]}
  do
  echo 'searching '$chain_to_search' links on table : '$table_name'   , chain '$def_chain_name >&2
  found_rulenumber=$(find_jumpchain_rule_number $table_name $def_chain_name $chain_to_search)

  [ "$found_rulenumber" -gt "0" ] && {
      echo 'found/deleting rule on : '$table_name' > '$def_chain_name' rule n.: '$found_rulenumber  >&2
      COUNTER=$[$COUNTER +1]
      iptables -t $table_name -D $def_chain_name $found_rulenumber
  }
  #echo "value: ${default_ipt_chains[$i]}"
  done
echo $COUNTER
}

delete_chain_references_in_all_tables (){
# sesarch for chain references and then delete them
# in all default table and chains
# return amount of deleted references
local chain_to_search=$1
local COUNTER=0

for table_name in "${!default_ipt_chains[@]}"
do
  echo "entering table name : $table_name" >&2
  found=$(delete_chain_references_in_default_chains $chain_to_search "${default_ipt_chains[$table_name]}")
  COUNTER=$[$found +1]
done
echo $COUNTER
}

get_last_rule_number(){
# @return the number of the last rule in a chain, 0 if no rules are present
local table_source=$1
local chain_source=$2
local retval=$(iptables -L $chain_source  -n  --line-number  -t $table_source | egrep  "^[0-9]+" | tail -1 |awk '{ print $1 }')
retval=${retval:-0}
echo $retval
}


get_chain_references_count() {
# @return the count of references to a chain
local table_name=$1
local chain_to_search=$2
local retval=$(iptables -L -n -v -t $table_name  | grep 'Chain '$chain_to_search | sed -e 's/^[^\(]*(\([0-9]*\).*/\1/g')
retval=${retval:-0}
echo $retval
}


recursive_delete_chain() {
# performed actions:
# - delete references to custom chain,
# - delete custom chains
    declare -A creator
    creator[table]=$1
    creator[custom_chain_name]=$2

    # CLEAR PREVIOUS STATUS > delete references to chain and delete chain
    echo '>>> deleting references for chain : '${creator[custom_chain_name]} >&2

    deleted_items=$(delete_chain_references_in_default_chains "${creator[custom_chain_name]}" "${creator[table]}")
    echo '>>> deleting chain : '"${creator[custom_chain_name]}" >&2
    ## flush
    $_ipt -t "${creator[table]}" -F "${creator[custom_chain_name]}"
    ## delete
    $_ipt -t "${creator[table]}" -X "${creator[custom_chain_name]}"
}

create_chain_if_enabled() {
    local table=$1
    local chain=$2
    local enabled=$3
    if [ $enabled == "1" ];then
      create_chain $table $chain
      return 0 # return true
    fi
    return 1 # return false
}

create_chain() {
# create the required chain
    declare -A creator
    creator[table]=$1
    creator[custom_chain_name]=$2

    $_ipt -t "${creator[table]}" -N "${creator[custom_chain_name]}"
    [ "$?" == "0" ] || {
        echo '[FATAL] error during chain creation ! '"${creator[table]}"' '"${creator[custom_chain_name]}" >&2
        # exit 1 # there is a bug in chain deletion  ( which didn't delete correctly reference from custom chains to custom chains so the successive creation fail because the chain already exsits )
        echo '[BUG!] skipping error, attemp to continue anyway ... ' >&2
        return 0
    }
    return 0
}


set_default_accept_policy() {
$_ipt -t filter  -P INPUT ACCEPT
$_ipt -t filter  -P OUTPUT ACCEPT
$_ipt -t filter  -P FORWARD ACCEPT
}

delete_created_custom_chains(){
    local chains_count=${#custom_created_chains[@]}
    if [ "$chains_count" -lt "1" ]; then
        echo '[WARNING] reset chain has been called but custom chain array is empty' >&2
        return 0
    fi

    # delete LAST-POSITIONED RULES
    for i in "${!custom_created_chains[@]}"
    do
        echo "key  : $i"
        table_and_chain_to_split="${custom_created_chains[$i]}"
        splitted_ar=(${table_and_chain_to_split//\// })
        if [ "${#splitted_ar[@]}" != "2" ]; then
            echo '[ERROR] delete_created_custom_chains>  error during table/chain split-count '$i' , table_and_chain_to_split='$table_and_chain_to_split' , splitted_ar='$splitted_ar >&2
            return 1
        else
            #delete only last-positioned rules
            if $(echo "${splitted_ar[1]}" | grep -q "v_last_") ; then
                if_exists_recusively_delete_chain "${splitted_ar[0]}" "${splitted_ar[1]}"
            fi
        fi
    done

    for i in "${!custom_created_chains[@]}"
    do
        echo "key  : $i"
        table_and_chain_to_split="${custom_created_chains[$i]}"
        splitted_ar=(${table_and_chain_to_split//\// })
        if [ "${#splitted_ar[@]}" != "2" ]; then
            echo '[ERROR] delete_created_custom_chains>  error during table/chain split-count '$i' , table_and_chain_to_split='$table_and_chain_to_split' , splitted_ar='$splitted_ar >&2
            return 1
        else
            echo ' splitted_ar='"${splitted_ar[@]}"
            if_exists_recusively_delete_chain "${splitted_ar[0]}" "${splitted_ar[1]}"
        fi
    done

}

autogenerate_custom_chain_name() {
    declare -A creator
    creator[table]=$1
    creator[chain]=$2 # chain name (if position is manual) , or destination chain
    creator[position]=$3 # first , last ( default) , manual
    local retval='v_'"${creator[position]}"'_'"${creator[table]}"'_'"${creator[chain]}"
    echo $retval
}

create_jump_rule(){
# inject jump-to-chain as first or last rule in given parent chain
    declare -A creator
    creator[table]=$1
    creator[chain_src]=$2 # source chain where to insert the jump rule
    creator[chain_dst]=$3 # chain to jump into
    creator[position]=$4 # first , last ( default)
    local JUMP_ADDITIONAL_PARAMS=$5 # additional matches for the jump rule

    ## custom chain positioning
    local RULE_position=""
    local RULE_binding_action="A" # append
    [ "${creator[position]}" == "first" ] && {
        RULE_position="1"
        RULE_binding_action="I" # insert
    }

    $_ipt -t "${creator[table]}" -"${RULE_binding_action}" "${creator[chain_src]}" $RULE_position $JUMP_ADDITIONAL_PARAMS -j "${creator[chain_dst]}"

    [ "$?" == "0" ] || {
        echo '[FATAL] error during jump insertion ! > '"${creator[table]}"' -'"${RULE_binding_action}"' '"${creator[chain_src]}"' '$RULE_position' '$JUMP_ADDITIONAL_PARAMS' -j '"${creator[chain_dst]}" >&2
        exit 1
    }
    return 0
}




autocreate_MANUAL_positioned_chain() {
# autocreate , deleting previous version & references
# if disabled param == "1" , only delete previous version
    if [ "$#" -ne 3 ]; then
        echo '[FATAL] autocreate_non_positioned_chain > invalid param count 3 expected , and '"$#"' provided' >&2
        exit 1
    fi
    # HEADER
    local ENABLED=$1 # 0 = false , 1 = true
    local TABLE=$2 # iptables destination table
    local CHAIN_NAME=$3 # destination chain

    # FLUSH PREVIOUS VERSION
    if_exists_recusively_delete_chain $TABLE $CHAIN_NAME

    # RECREATE CHAIN IF ENABLED
    if $(create_chain_if_enabled $TABLE $CHAIN_NAME $ENABLED) ; then
        echo $CHAIN_NAME
    else
        echo ''
    fi
}


autocreate_AUTOpositioned_chain() {
# create chain autopositioned & autnominated on top/bottom of another chain
# return the name of the chain created or '' if the chain has been only flushed & deleted

    # HEADER
    local OPTS_ENABLED=$1 # 0 = false , 1 = true
    local OPTS_TABLE=$2 # iptables destination table
    local OPTS_CHAIN=$3 # destination chain
    local OPTS_POSITION=$4 # first , last ( default)

    # PARAM VALIDATION
    [ "${OPTS_POSITION}" != "first" ] && [ "${OPTS_POSITION}" != "last" ] && {
        echo '[FATAL] invalid chain positioning '"${OPTS_POSITION}" >&2
        exit 1
    }


    # GENERATE CHAIN NAME
    local GENERATED_CHAIN_NAME=$(autogenerate_custom_chain_name "${OPTS_TABLE}" "${OPTS_CHAIN}" "${OPTS_POSITION}")
    echo 'generated chain name : '$GENERATED_CHAIN_NAME' from > '"${OPTS_TABLE}" "${OPTS_CHAIN}" "${OPTS_POSITION}" >&2

    # FLUSH PREVIOUS VERSION OF THE CHAIN
    if_exists_recusively_delete_chain "${OPTS_TABLE}" $GENERATED_CHAIN_NAME


    if [ "${OPTS_ENABLED}" -eq "1" ] ; then

        create_chain "${OPTS_TABLE}" $GENERATED_CHAIN_NAME
        create_jump_rule "${OPTS_TABLE}" "${OPTS_CHAIN}" $GENERATED_CHAIN_NAME "${OPTS_POSITION}"

        echo 'chain '$GENERATED_CHAIN_NAME ' is now enabled ('"${OPTS_TABLE}" "${OPTS_CHAIN}" "${OPTS_POSITION}"')' >&2
        echo $GENERATED_CHAIN_NAME
    else
        echo 'chain '$GENERATED_CHAIN_NAME ' will be disabled ('"${OPTS_TABLE}" "${OPTS_CHAIN}" "${OPTS_POSITION}"')' >&2
        echo ''
    fi


}


iptables_save_without_docker(){
    # save current configuration without docker chains & rules

    local destination=$1
    $_ipt_save | grep -iv ' docker0' | grep -v ' -j DOCKER' | grep -v ':DOCKER -' > "${destination}"
}