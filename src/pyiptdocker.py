__author__ = 'francesco'

import optparse
import subprocess
import sys
import re
import os
import imp
import logging
import getpass

##  CONSTANTS INTO VARIABLE
USERNAME = getpass.getuser()
SUDO_CMD="sudo " if USERNAME!="root" else ""

BIT_TO_BYTE=1/8
UNIT_KB=1024
UNIT_MB=1024*UNIT_KB
UNIT_GB=1024*UNIT_MB
UNIT_TB=1024*UNIT_GB

"""
# configuration default policies can be customized with :
CONFIG['DEFAULT_ACCEPT_POLICIES']['INPUT'] = 'DROP';
CONFIG['DEFAULT_ACCEPT_POLICIES']['FORWARD'] = 'DROP';

"""
CONFIG = {
    "PYIPTDOCKER_VERSION" : 2.1 ,
    "CUSTOM_CHAIN_PREFIX" : os.getenv('CUSTOM_CHAIN_PREFIX', "ipth_") ,
    "DEFAULT_ACCEPT_POLICIES" : {
        'INPUT' : 'ACCEPT',
        'FORWARD': 'ACCEPT',
        'OUTPUT': 'ACCEPT'
    } ,
    #    "iptableRulesFile" : '/etc/network/iptables.rules' , ##  use only 1 path to store rules
    "iptables_persistent_ipv4" : '/etc/iptables/rules.v4' , ## iptables persistent default path ( https://www.thomas-krenn.com/en/wiki/Saving_Iptables_Firewall_Rules_Permanently )
    "iptables_persistent_ipv6" : '/etc/iptables/rules.v6' , ## iptables persistent default

    ## THIS COMMAND ALSO INCLUDE FILTERS TO EXCLUDE DIFFERENTLY MANAGED CHAINS ,
    ## IE : kubernetes and docker rules should not be restored automatically on reboot

    "IPTABLES_SAVE_CMD" : SUDO_CMD+""" iptables-save | grep -iv ' docker0' | grep -v ' -j DOCKER' | grep -v ':DOCKER -'  | grep -v 'DOCKER-' | grep -v 'KUBE-' """
}



# prefix used in all custom chains


logger = logging.getLogger()
handler = logging.StreamHandler()
formatter = logging.Formatter(
    '%(asctime)s %(name)-12s %(levelname)-8s %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# default tables and chains
IPTH_DEFAULTS = {
    'tables': { ## -> cat /proc/net/ip_tables_names
        'nat': ['PREROUTING' ,'INPUT' ,'OUTPUT' ,'POSTROUTING'],  # chains
        'filter': ['INPUT','FORWARD' ,'OUTPUT' ], # chains
        'mangle': ['PREROUTING' ,'FORWARD','INPUT' ,'OUTPUT' ,'POSTROUTING'], # chains
        'raw': ['PREROUTING'  ,'OUTPUT' ], # chains
#        'security': ['INPUT','FORWARD' ,'OUTPUT' ], # chains ----> NB: removed because never used and not implemented in all kernels! 
    }
}
ALLOWED_CUSTOMCHAINS_POSITIONS = ["first","last","custom"]



##
##   interfaces to customize configuration
##





##
##
##  MAIN LIBRARY
##
##



def failPolicyJustExit(execBashCommand):
    logger.fatal("!!!! FATAL ERROR,  command failed , exiting rc = %s , command = %s , stderr = %s , stdout =  %s" , execBashCommand.rc,execBashCommand.command,execBashCommand.err,execBashCommand.out)
    sys.exit("error")


def failPolicy_CleanIptablesAndExit(execBashCommand):
    logger.fatal( "error on execution occurred : %s " , execBashCommand )
    applyDefaultAcceptPolicy()
    deleteAllCustomChains()
    logger.fatal( "configuration cleaned, EXITING" )
    logger.fatal("!!!! FATAL ERROR,  command failed , exiting rc = %s , command = %s , stderr = %s , stdout =  %s" , execBashCommand.rc,execBashCommand.command,execBashCommand.err,execBashCommand.out)
    sys.exit("failPolicy_CleanIptablesAndExit")


def execIptable(command , onFailPolicy=failPolicy_CleanIptablesAndExit):
    return ExecBashCommand(SUDO_CMD+"/sbin/iptables " +command,onFailPolicy)

class ExecBashCommand:

    def __init__(self,command,onFailPolicy=None):
        self.command = command
        logger.debug( "COMMAND # [%s] " , self.command )
        self.p = subprocess.Popen(self.command , shell=True, stdout=subprocess.PIPE ,stderr=subprocess.PIPE)
        self.err = self.p.stderr.read().rstrip()
        self.out = self.p.stdout.read().rstrip()
        self.p.wait()
        self.rc = self.p.returncode
        if(len(self.out)) > 0:
            logger.debug("COMMAND STDOUT [%s] " , self.out)
        if(len(self.err)) > 0:
            logger.debug("COMMAND STDERR [%s] " , self.err)
        if self.rc != 0 :
            logger.debug("COMMAND rc [%s] " , self.rc)
            logger.warning("[ExecBashCommand] error rc = %s , command = %s , stderr = %s , stdout =  %s" , self.rc,self.command,self.err,self.out)
            if onFailPolicy is not None:
                onFailPolicy(self)



def applyDefaultAcceptPolicy():
    """
    set filter table to accept
    :return: nothing
    """
    filterChains = IPTH_DEFAULTS['tables']['filter']
    for k in range(len(filterChains )): # foreach chain
        chainName=filterChains[k]
        execIptable("-t filter  -P "+chainName+" "+CONFIG["DEFAULT_ACCEPT_POLICIES"][chainName])

def findChains(table):
    '''
        :return array with chains found in table
    '''
    # return output in this format 'Chain INPUT (policy ACCEPT)'
    chainLines = \
        execIptable("-n -L -t "+table+" | egrep \"^Chain\" ") \
            .out.split("\n")

    # extract chain name from iptables output line
    def extractChainName(line):
        m = re.search('^Chain ([^\s]*)', line)
        if m:
            return m.group(1)

    return map(extractChainName, chainLines)


def findCustomChains(table):
    '''
        :return array with custom chains found in table
    '''
    # return output in this format 'Chain INPUT (policy ACCEPT)'
    logger.debug("looking for custom chains in %s",table)
    return filter(
        lambda x: x.startswith(CONFIG['CUSTOM_CHAIN_PREFIX']) ,
        findChains(table))


##def flushChain(table,chainName):

def findJumpRuleInChain(table,chainToSearchInto,chainToFind):
    '''
    :param table the table to search into ie: filter
    :param chainToSearchInto the chain to search into ie: INPUT
    :param chainToFind the chain to search for
    :returns list of rules ID that matches a jump rule to the desired chain in the requested chain
    '''
    logger.debug("findJumpRuleInChain: %s  %s %s",table,chainToSearchInto,chainToFind)
    c = execIptable("-n -t "+table+" -L "+chainToSearchInto+" --line-number")
    """
    sample:
iptables -t filter -L INPUT --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    ipth_first_filter_INPUT  all  --  anywhere             anywhere
2    ipth_last_filter_INPUT  all  --  anywhere             anywhere
    """
    def filterJumpRuler(ruleRow):
        """
        :param ruleRow: rule to search for
        :return: true if ruleRow has ben found
        """
        #sample:1    ipth_first_filter_INPUT  all  --  anywhere             anywhere
        m = re.search('^\d+\s+([^\s]*) .*', ruleRow)
        logger.debug("[findJumpRuleInChain] matching %s , ? %s ", ruleRow ,m )
        if m:
            logger.debug("[findJumpRuleInChain] m.group(1)==chainToSearchInto -> %s == %s , ? %s ", m.group(1),chainToFind,(m.group(1)==chainToSearchInto))
        if m and m.group(1)==chainToFind :
            return True
        return False

    def extractJumpRuleNumber(ruleRow):
        m = re.search('^(\d+)\s+([^\s]*)', ruleRow)
        logger.debug("[extractJumpRuleNumber] matching %s , ? %s ", ruleRow ,m )
        return m.group(1)


    #extract rule number of matching rules
    return map(extractJumpRuleNumber,
               # extract jump rules matching desired destination
               filter(filterJumpRuler
                      ,c.out.split("\n")))



def recursiveDeleteOfChain(table,chainName):
    logger.debug("[recursiveDeleteOfChain] : %s %s",table,chainName)
    requestedTableChains = findChains(table)

    # delete references to the chain in other chains
    for k in range(len(requestedTableChains)):
        searchIntoChain=requestedTableChains[k]
        while True:
            foundJumpRules = findJumpRuleInChain(table,searchIntoChain,chainName)
            if len(foundJumpRules) < 1 :
                logger.debug("[recursiveDeleteOfChain] no more links for %s  into %s/%s",chainName,table,searchIntoChain)
                break;
            else:
                ruleNumberToDelete=foundJumpRules[0]
                logger.debug("[recursiveDeleteOfChain] deleting rule number %s that links for %s  into %s/%s",ruleNumberToDelete,chainName,table,searchIntoChain)
                c = execIptable("-t "+table+" -D "+searchIntoChain+" "+ruleNumberToDelete)


    # find rule links
    logger.info("search jump rule results = %s",findJumpRuleInChain(table,"INPUT",chainName))

    # flush chain
    c = execIptable("-t "+table+" -F "+chainName)
    # delete chain
    c = execIptable("-t "+table+" -X "+chainName)


def applyDefaultSuffixToChainName(chainName):
    return CONFIG['CUSTOM_CHAIN_PREFIX']+chainName


def buildCommandChainJumpRule(iptChainItem,jumpAdditionalParams=""):
    postionNumber=""
    rulePosition="-A" # append (last rule )
    if iptChainItem.destinationChainPosition=="first":
        rulePosition="-I" # insert (first rule )
        postionNumber="1"

    return "-t "+iptChainItem.destinationTable+" "+rulePosition+" "+iptChainItem.destinationChain+" "+postionNumber+" "+jumpAdditionalParams+" -j "+iptChainItem.chainName


def createFloatingChain(iptChainItem):
    logger.info("creating floating chain %s " , iptChainItem)
    c = execIptable("-t " + iptChainItem.destinationTable + " -N " + iptChainItem.chainName)
    return c


def createAutoPositionedChain(iptChainItem):

    logger.info("creating positioned chain %s",iptChainItem)
    cCreateChain = execIptable("-t "+iptChainItem.destinationTable+" -N "+iptChainItem.chainName)
    cJumpToChainRule = execIptable(
        buildCommandChainJumpRule(iptChainItem))



def createChain(iptChainItem):
    if iptChainItem.destinationTable not in  IPTH_DEFAULTS['tables'].keys():
        sys.exit("invalid destination table name %s , not found in valid tables list %s" % (str(iptChainItem.destinationTable),str(IPTH_DEFAULTS['tables'].keys())) )

    if iptChainItem.destinationChainPosition == "" or iptChainItem.destinationChainPosition == "custom":
        createFloatingChain(iptChainItem)
    elif iptChainItem.destinationChainPosition == "first" or iptChainItem.destinationChainPosition == "last":
        createAutoPositionedChain(iptChainItem)
    else:
        sys.exit("invalid chain [%] position %s , allowed positions are : %s " % (
            str(iptChainItem),
            str(iptChainItem.destinationChainPosition,
                str(ALLOWED_CUSTOMCHAINS_POSITIONS) )
        ))

def saveIptablesConfigurationWithoutDockerChains():
    map(
        lambda destination:(
            logger.info("saving iptables configuration on %s " , destination) ,
            ExecBashCommand(CONFIG['IPTABLES_SAVE_CMD'] +" > "+destination,failPolicyJustExit) ,
            logger.info("CONFIGURATION SAVED! destination was : %s " , destination) ,
        ),
        [
            CONFIG['iptables_persistent_ipv4']
            #,CONFIG['iptableRulesFile']
        ]
    )



class IPTChainItem():
    destinationTable=""
    destinationChain=""
    destinationChainPosition=""
    chainName=""

    def __str__(self):
        return "destinationTable[%s] , destinationChain[%s] , destinationChainPosition[%s] , chainName[%s] ,  " \
               % (self.destinationTable,self.destinationChain,self.destinationChainPosition,self.chainName)


    @staticmethod
    def PositionedChain(tableAndChainAndPosition):
        """
        this is a constructor for IPTChainItem
        :param tableAndChainAndPosition: a string that contain destination table name, chain name and position joined by "/", ie: "filter/INPUT/last"
        :return: new chain Item
        """
        if len(tableAndChainAndPosition.split("/")) != 3:
            sys.exit("invalid param tableAndChainAndPosition "+ str(tableAndChainAndPosition) + " , format is : destinationTable/chain/position(first|last) ")
        cc = IPTChainItem()

        (cc.destinationTable,
         cc.destinationChain,
         cc.destinationChainPosition) =tableAndChainAndPosition.split("/")
        cc.destinationTable.lower()

        cc.chainName = applyDefaultSuffixToChainName(cc.destinationChainPosition+"_"+cc.destinationTable+"_"+cc.destinationChain)
        return cc

    @staticmethod
    def FloatingChain(tableAndChainsuffix):
        """
        this is a constructor for IPTChainItem
        :param tableAndChainsuffix: a string that contain destination table name and  chain name joined by "/", ie: "filter/INPUT/last"
        :return: new chain Item
        """
        if len(tableAndChainsuffix.split("/")) != 2:
            sys.exit("invalid param chainAndTableName "+ str(tableAndChainsuffix) + " , format is : tableName/chainSuffix ")

        cc = IPTChainItem()
        (cc.destinationTable,
         chainSuffix) =tableAndChainsuffix.split("/")
        cc.destinationTable.lower()
        cc.chainName = applyDefaultSuffixToChainName(chainSuffix)

        return cc

    def __init__(self):
        pass


def deleteAllCustomChains():
    logger.debug("[deleteAllCustomChains] _ start")
    logger.info("deleting all previously created custom chains ")
    map(
        lambda tableName: map(
            lambda customChain:recursiveDeleteOfChain(tableName,customChain) ,
            findCustomChains(tableName)),
        IPTH_DEFAULTS['tables'].keys()) # for each main tables

    logger.debug("[deleteAllCustomChains] _ end")


class TemplatedChainRules:

    iptChainItem = None
    rules=[]

    @staticmethod
    def PositionedChain(tableAndChainAndPosition):

        t = TemplatedChainRules(
            IPTChainItem.PositionedChain(tableAndChainAndPosition))

        return t

    @staticmethod
    def FloatingChain(tableAndChainsuffix):
        t = TemplatedChainRules(
            IPTChainItem.FloatingChain(tableAndChainsuffix))
        return t

    def __init__(self,iptChainItem):

        logger.info("initializing template on chain object [%s]",iptChainItem)
        self.iptChainItem = iptChainItem

    def __cleanAndSplitRulesString(self,ruleString):
        return filter(
            lambda ruleRow:
            len(ruleRow)>1 and ruleRow[0]!="#",
            map(
                lambda ruleRow:ruleRow.strip(), ruleString.split("\n")))

    def __appendRulesList(self,newRulesArray):
        # strip rows and delete empty rows
        logger.debug("[%s] appending rules %s ", self.iptChainItem,newRulesArray)
        self.rules=self.rules + newRulesArray

    def addInterpolatedRules(self,ruleString):
        """
        interpolated rules convert special keywords such  {k_table} {k_chain}
        with values of destination table and current chain name
        """
        def applyTemplate(rule):
            return rule.format(
                k_table=self.iptChainItem.destinationTable,
                k_chain=self.iptChainItem.chainName,
            )

        self.__appendRulesList(
            map(
                applyTemplate
                ,self.__cleanAndSplitRulesString(ruleString)
            ))
        return self

    def addRawRules(self,rulesString):
        self.__appendRulesList(
            self.__cleanAndSplitRulesString(rulesString))
        return self

    def addAppendRules(self,rulesString):
        def prefixAppendRule(rule):
            return "-A "+self.iptChainItem.chainName+" "+rule

        self.__appendRulesList(
            map(
                prefixAppendRule
                ,self.__cleanAndSplitRulesString(rulesString)
            ))
        return self

    def getRulesCount(self):
        return len(self.rules)


    def apply(self):
        logger.info("Applying %s rules , on chain object [%s] ",str(len(self.rules)),self.iptChainItem)

        logger.debug("creating chain %s",self.iptChainItem)
        createChain(self.iptChainItem)

        logger.debug("applying ruleset %s",self.rules)
        for ruleRow in self.rules:
            c = execIptable("-t "+self.iptChainItem.destinationTable+" "+ruleRow)
            # # stop the world and open firewall if problem occurr
            # if c.rc!=0:
            #     failPolicy_CleanIptablesAndExit(
            #         "error applying rule [%s] on [%s]" % (ruleRow,self.iptChainItem) )



        return self




def get_args():
    """
    parse arguments
    """

    usage = 'this program should be called from a php templated file'
    parser = optparse.OptionParser(usage=usage)


    parser.add_option(
        '--uninstall', '-U',
        action="store_true",
        default=False,
        help='uninstall iptables customizations',
        dest='param_uninstall'
    )
    parser.add_option(
        '--test', '-E',
        action="store_true",
        default=False,
        help='execute tests with test chain prefix',
        dest='param_run_test'
    )
    parser.add_option(
        '--verbose', '-V',
        action="store_true",
        default=False,
        help='print verbose logging',
        dest='param_verbose'
    )
    parser.add_option(
        '--save-rules', '-S',
        action="store_true",
        default=False,
        help='save iptables rules (except docker rules) for next iptables restart',
        dest='param_save_rules'
    )

    parser.add_option(
        '--template', '-T',
        type='string',
        default="",
        help='location of template file',
        dest='param_template_full_path'
    )

    parser.add_option(
        '--chains-prefix', '-P',
        type='string',
        default="",
        help='custom chains prefix',
        dest='param_chains_prefix'
    )

    return parser.parse_args()[0]


def performTest():
    logger.setLevel(logging.DEBUG)
    logger.info("RUNNING TEST MODE _ start")
    CONFIG['CUSTOM_CHAIN_PREFIX'] = "TEST"
    initialize()

    ######################################
    t_STUB_PACKET_COUNTER = TemplatedChainRules.FloatingChain("filter/stub_packet_counter").addAppendRules("""
    -j RETURN -m comment --comment "only count returns"
    """).apply()

    t_STUB_PACKET_COUNTER__chainName = t_STUB_PACKET_COUNTER.iptChainItem.chainName
    logger.debug("t_STUB_PACKET_COUNTER__chainName = %s",t_STUB_PACKET_COUNTER__chainName)

    ######################################
    t_custom1_floatingchain = TemplatedChainRules.FloatingChain("filter/custom1").addAppendRules("""
    -j {stub_packet_counter} -m comment --comment " counter 5"
    """.format(stub_packet_counter=t_STUB_PACKET_COUNTER__chainName)
                                                                                                 ).apply()

    t_custom1_floatingchain__chainName = t_custom1_floatingchain.iptChainItem.chainName
    logger.debug("t_custom1_floatingchain__chainName  = %s",t_custom1_floatingchain__chainName )

    ######################################
    t_filter_input_last = TemplatedChainRules. \
        PositionedChain("filter/INPUT/last") \
        .addAppendRules(
        r'''
        -m state --state ESTABLISHED,RELATED -j ACCEPT
        -s 127.0.0.1 -j ACCEPT
        '''
    ).addInterpolatedRules(
        r'''
    -A {k_chain} -m state --state ESTABLISHED,RELATED -j ACCEPT
    -A {k_chain} -s 127.0.0.1 -j ACCEPT
    -A {k_chain} -s 127.0.0.1 -j '''+t_custom1_floatingchain__chainName+'''

        '''
    ).apply()

    t_filter_input_last__chainName = t_filter_input_last.iptChainItem.chainName
    logger.debug("rulesCount= %s",t_filter_input_last.getRulesCount())
    assert t_filter_input_last.getRulesCount() == 5
    ######################################

    map(
        lambda table: execIptable("-t " + table + " -nvL ") ,
        IPTH_DEFAULTS['tables'].keys())

    logger.info("test finished, performing cleanup...")
    deleteAllCustomChains()





def initialize():
    applyDefaultAcceptPolicy()
    deleteAllCustomChains()


def load_template_file(param_template_full_path):
    logger.info("loading template file [%s]",param_template_full_path)
    # TODO not implemented yet
    # if not os.path.isfile(param_template_full_path):
    #    sys.exit("cannot load tempalte file, ["+str(param_template_full_path)+"] is not a file")
    #
    # py_template = imp.load_source("pyiptdocker_template", param_template_full_path)
    #
    # initialize()
    #
    # py_template
    #
    # pass


if __name__ == '__main__':
    # /usr/share/collectd/types.db
    #pyiptdocker_start()
    OPTIONS = get_args()
    logger.info("RUNNING IN STANDALONE EXECUTION")

    if OPTIONS.param_verbose:
        logger.setLevel(logging.DEBUG)

    if OPTIONS.param_chains_prefix != "":
        CONFIG['CUSTOM_CHAIN_PREFIX'] = OPTIONS.param_chains_prefix

    if OPTIONS.param_uninstall:
        applyDefaultAcceptPolicy()
        deleteAllCustomChains()

    if OPTIONS.param_run_test:
        performTest()

    if len(OPTIONS.param_template_full_path) > 1:
        load_template_file(OPTIONS.param_template_full_path)



    if OPTIONS.param_save_rules:
        logger.info("SAVING RULES")
        saveIptablesConfigurationWithoutDockerChains()


        #c = ExecBashCommand("sudo iptables -nvL")




        #print "command executed : " , c.out


print "end"