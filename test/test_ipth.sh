#!/bin/bash

set -x
set -e
set -o pipefail

. ./../src/ipth.sh

ipth_check_version "1.1"

test_chain_name="test_chain"
test_table="filter"

# delete test chain if exist
if find_chain_exists $test_table $test_chain_name ; then
    echo 'test chain:'$test_chain_name' exists and will be deleted before test can start '
    recursive_delete_chain $test_table $test_chain_name
fi


# create chain and then chain should exists
create_chain $test_table $test_chain_name
if ! find_chain_exists $test_table  $test_chain_name ; then
    echo 'error, '$test_chain_name'  chain should exists at this point '
    exit 1
fi




# generate jump and count references
create_jump_rule $test_table 'INPUT' $test_chain_name 'first'
count_references=$(get_chain_references_count $test_table $test_chain_name)
[ "${count_references}" == "1" ] || {
    echo 'error, references count should be 1'
    exit 1
}
create_jump_rule $test_table 'OUTPUT' $test_chain_name 'first'

count_references=$(get_chain_references_count $test_table $test_chain_name)
[ "${count_references}" == "2" ] || {
    echo 'error, references count should be 2'
    exit 1
}

## now delete chain with references
recursive_delete_chain $test_table $test_chain_name
if find_chain_exists $test_table  $test_chain_name ; then
    echo 'error, '$test_chain_name'  chain should has been removed '
    exit 1
fi




# test chain name generator :
[ "$(autogenerate_custom_chain_name 'filter' 'INPUT' 'first')" == "v_first_filter_INPUT" ] || {
    echo 'error, wrong expectations on generated name '
    exit 1
}
[ "$(autogenerate_custom_chain_name 'filter' 'INPUT' 'last')" == "v_last_filter_INPUT" ] || {
    echo 'error, wrong expectations on generated name '
    exit 1
}


generated_table=$(autocreate_AUTOpositioned_chain 0 'filter' 'INPUT' 'first')
[ ! -z "$generated_table" ] && {
    echo 'error, table should has been disabled! > '$generated_table
    exit 1
}

generated_table=$(autocreate_AUTOpositioned_chain 1 'filter' 'INPUT' 'first')
[ -z "$generated_table" ] && {
    echo 'error, table should has been enabled! > '$generated_table
    exit 1
}
count_references=$(get_chain_references_count 'filter' $generated_table)
[ "${count_references}" == "1" ] || {
    echo 'error, references count should be 1'
    exit 1
}



## -- TEMPLATE SAMPLE
declare -ga custom_created_chains
#custom_created_chains=() #array of custom created chains ( to be used in case of reset )
tablename="filter"
chainparent_position="first"
chain_parent="INPUT"
enabled="1"
# full & recreate rule
built_chain=$(autocreate_AUTOpositioned_chain $enabled $tablename $chain_parent $chainparent_position)
# if created, apply rules
[ ! -z "$built_chain" ] && {
custom_created_chains+=("$tablename/$built_chain")
/sbin/iptables  -t  $tablename  -A "$built_chain" -p tcp -m limit --limit 5/min -j LOG --log-prefix "Denied TCP: " --log-level 7
/sbin/iptables  -t  $tablename  -A "$built_chain" -p tcp -m limit --limit 51/min -j LOG --log-prefix "Denied TCP2: " --log-level 7
}

## test assertions
rules_count=$(get_last_rule_number $tablename $built_chain)
[ "${rules_count}" == "2" ] || {
    echo 'error, unexpected rules count '
    exit 1
}
recursive_delete_chain $tablename $built_chain

echo 'chain array = ' "${custom_created_chains[0]}"


#test automated chain array creation
[ ${custom_created_chains[0]} == "filter/$built_chain" ] || {
    echo 'error, unexpected created chains array values  '
    exit 1
}



# TEST AUTOMATED-CHAIN-RESET
BUILT_auto_CHAIN_1=""
BUILT_auto_CHAIN_2=""
tablename="filter"
chainparent_position="first"
chain_parent="INPUT"
enabled="1"
# full & recreate rule
built_chain=$(autocreate_AUTOpositioned_chain $enabled $tablename $chain_parent $chainparent_position)
BUILT_auto_CHAIN_1=$built_chain
# if created, apply rules
[ ! -z "$built_chain" ] && {
custom_created_chains+=("$tablename/$built_chain")
/sbin/iptables  -t  $tablename  -A "$built_chain" -p tcp -m limit --limit 5/min -j LOG --log-prefix "Denied TCP -- aaa: " --log-level 7
/sbin/iptables  -t  $tablename  -A "$built_chain" -p tcp -m limit --limit 51/min -j LOG --log-prefix "Denied TCP2 -- aaa: " --log-level 7
}


# ....  another automated created chain ...
tablename="filter"
chainparent_position="last"
chain_parent="FORWARD"
enabled="1"
# full & recreate rule
built_chain=$(autocreate_AUTOpositioned_chain $enabled $tablename $chain_parent $chainparent_position)
BUILT_auto_CHAIN_2=$built_chain
# if created, apply rules
[ ! -z "$built_chain" ] && {
custom_created_chains+=("$tablename/$built_chain")
/sbin/iptables  -t  $tablename  -A "$built_chain" -p tcp -m limit --limit 5/min -j LOG --log-prefix "Denied TCP -- bbbb: " --log-level 7
/sbin/iptables  -t  $tablename  -A "$built_chain" -p tcp -m limit --limit 51/min -j LOG --log-prefix "Denied TCP2 -- bbbb: " --log-level 7
}


# test rules count

rules_count=$(get_last_rule_number $tablename $BUILT_auto_CHAIN_1)
[ "${rules_count}" == "2" ] || {
    echo 'error, unexpected rules count in'$BUILT_auto_CHAIN_1
    exit 1
}



## show current iptables conf
echo 'not both 2 custom chain should exists with jumps from forward and input chains...\n'
iptables -L  -n -v -t filter

delete_created_custom_chains

# ... verify that custom-created-chain no longer exists
if find_chain_exists $tablename $BUILT_auto_CHAIN_1 ; then
    echo 'error, '$tablename' '$built_chain ' should has been delete from >delete_created_custom_chains'
    exit 1
fi

# ... verify that custom-created-chain no longer exists
if find_chain_exists $tablename $BUILT_auto_CHAIN_2 ; then
    echo 'error, '$tablename' '$BUILT_auto_CHAIN_2' should has been delete from >delete_created_custom_chains'
    exit 1
fi





## create manual positioned chain, the chain created should exists and have 0 references
tablename="filter"
chain_manual_name="test_manual_chain"
enabled="1"
built_chain=$(autocreate_MANUAL_positioned_chain $enabled $tablename $chain_manual_name)
[ ! -z "$built_chain" ] && {
custom_created_chains+=("$tablename/$built_chain")
/sbin/iptables  -t  $tablename  -A "$built_chain" -p tcp -m limit --limit 5/min -j LOG --log-prefix " custom chain logging: " --log-level 7
}

rules_count=$(get_last_rule_number $tablename $built_chain)
[ "${rules_count}" == "1" ] || {
    echo 'error, unexpected rules count in'$built_chain
    exit 1
}

if ! find_chain_exists $tablename $built_chain ; then
    echo 'error, '$tablename' '$built_chain' should exits!'
    exit 1
fi

count_references=$(get_chain_references_count $tablename $built_chain)
[ "${count_references}" == "0" ] || {
    echo 'error, references count should be 0'
    exit 1
}



# test with two custom chain, as first and last
# -- todo

echo " TEST OK ! "
exit 0