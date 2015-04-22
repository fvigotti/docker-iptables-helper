#!/bin/bash

set -e

IPTH_TEMPLATE_VERSION="1.1"


ipth_template() {

custom_created_chains=()

####### --- MANUALLY INJECTED CHAINS

local chain=LOG_DROP
local table=filter
local enabled=$(ipth_forced_unload_or_value "1")
local created_chain=$(autocreate_MANUAL_positioned_chain $enabled $table $chain)
[ ! -z "$created_chain" ] && {
    $_ipt -t $table -A "$created_chain" -p tcp -m limit --limit 5/min -j LOG --log-prefix "TEST LOGGED TCP: " --log-level 7 -m comment --comment "log rows"
    $_ipt -t $table -A "$created_chain" -p tcp -j ACCEPT -m comment --comment "because it's a test! :)"
}


####### --- AUTO-INJECTED CHAINS

# -- filter / INPUT / first

local enabled=$(ipth_forced_unload_or_value "1")
local tablename="filter"
local chain_parent="INPUT"
local chainparent_position="first"
local created_chain=$(autocreate_AUTOpositioned_chain $enabled $tablename $chain_parent $chainparent_position)

[ ! -z "$created_chain" ] && {
    $_ipt -t $table -A "$created_chain"  -m state --state ESTABLISHED,RELATED -j ACCEPT
}


# -- filter / INPUT / last

local enabled=$(ipth_forced_unload_or_value "1")
local tablename="filter"
local chain_parent="INPUT"
local chainparent_position="last"
local created_chain=$(autocreate_AUTOpositioned_chain $enabled $tablename $chain_parent $chainparent_position)

[ ! -z "$created_chain" ] && {
    $_ipt -t $table -A "$created_chain" -m state --state ESTABLISHED,RELATED -j ACCEPT
}

# -- filter / OUTPUT / last

local enabled=$(ipth_forced_unload_or_value "1")
local tablename="filter"
local chain_parent="OUTPUT"
local chainparent_position="last"
local created_chain=$(autocreate_AUTOpositioned_chain $enabled $tablename $chain_parent $chainparent_position)

[ ! -z "$created_chain" ] && {
    $_ipt -t $table -A "$created_chain" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
}

} # END - ipth_template