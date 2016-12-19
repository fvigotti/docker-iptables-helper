from pyiptdocker import *

logger.setLevel(logging.DEBUG)
configureDefaultAcceptPolicy(False)
initialize()

######################################

## create floating chain
t_STUB_PACKET_COUNTER = TemplatedChainRules.FloatingChain("filter/stub_packet_counter").addAppendRules("""
    -j RETURN -m comment --comment "only count returns"
    """).apply()

t_STUB_PACKET_COUNTER__chainName = t_STUB_PACKET_COUNTER.iptChainItem.chainName
logger.debug("t_STUB_PACKET_COUNTER__chainName = %s",t_STUB_PACKET_COUNTER__chainName)


######################################
## create floating chain
t_custom1_floatingchain = TemplatedChainRules.FloatingChain("filter/custom1").addAppendRules("""
    -j {stub_packet_counter} -m comment --comment " counter 5"
    """.format(stub_packet_counter=t_STUB_PACKET_COUNTER__chainName)
).apply()

t_custom1_floatingchain__chainName = t_custom1_floatingchain.iptChainItem.chainName
logger.debug("t_custom1_floatingchain__chainName  = %s",t_custom1_floatingchain__chainName )

######################################
## create a chain and inject at give position )
t_filter_input_last = TemplatedChainRules. \
    PositionedChain("filter/INPUT/last") \
    .addAppendRules(
    r'''
    -m state --state ESTABLISHED,RELATED -j ACCEPT
    -s 127.0.0.5 -j ACCEPT
    '''
).addInterpolatedRules(
    r'''
-A {k_chain} -m state --state ESTABLISHED,RELATED -j ACCEPT
-A {k_chain} -s 127.0.0.1 -j ACCEPT
-A {k_chain} -s 127.0.0.1 -j '''+t_custom1_floatingchain__chainName+'''
        '''
).apply()

t_filter_input_last__chainName = t_filter_input_last.iptChainItem.chainName
######################################



