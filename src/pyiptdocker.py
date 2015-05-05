__author__ = 'francesco'

import optparse
import subprocess
import urllib2
import sys
import traceback
import re
import time

import json
import httplib
import urllib
import sys
import traceback
import re
from HTMLParser import HTMLParser
import argparse
import md5
import time
import hashlib
import copy

from datetime import date
from time import gmtime, strftime
import os
import subprocess
import sys
import signal
import shlex
import random
import copy
from pprint import pprint
import re
import logging
from logging.config import dictConfig


BIT_TO_BYTE=1/8
UNIT_KB=1024
UNIT_MB=1024*UNIT_KB
UNIT_GB=1024*UNIT_MB
UNIT_TB=1024*UNIT_GB


# prefix used in all custom chains
CUSTOM_CHAIN_PREFIX = "ipth_"

logger = logging.getLogger()
handler = logging.StreamHandler()
formatter = logging.Formatter(
    '%(asctime)s %(name)-12s %(levelname)-8s %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.DEBUG)


IPTH_DEFAULTS = {
    'tables': {
        'nat': ['PREROUTING' ,'INPUT' ,'OUTPUT' ,'POSTROUTING'],
        'filter': ['INPUT','FORWARD' ,'OUTPUT' ],
        'mangle': ['PREROUTING' ,'FORWARD','INPUT' ,'OUTPUT' ,'POSTROUTING'],
        'raw': ['PREROUTING'  ,'OUTPUT' ],
        'security': ['INPUT','FORWARD' ,'OUTPUT' ],
        }
}

def execIptable(command,exitOnFail=False):
    return ExecBashCommand("sudo /sbin/iptables " +command,exitOnFail=exitOnFail)

def setDefaultAcceptPolicy():
    filterChains = IPTH_DEFAULTS['tables']['filter']
    for k in range(len(filterChains )):
        execIptable("-t filter  -P "+filterChains[k]+" ACCEPT",exitOnFail=True)

def findChains(table):
    '''
        :return array with chains found in table
    '''
    # return output in this format 'Chain INPUT (policy ACCEPT)'
    c = execIptable("-L -t "+table+" | egrep \"^Chain\" ",exitOnFail=True)

    def getChainInLine(line):
        m = re.search('^Chain ([^\s]*)', line)
        if m:
            return m.group(1)

    return map(getChainInLine,c.out.split("\n"))


def findCustomChains(table):
    '''
        :return array with custom chains found in table
    '''
    # return output in this format 'Chain INPUT (policy ACCEPT)'
    return filter(lambda x: x.startswith(CUSTOM_CHAIN_PREFIX) ,
           findChains(table))


##def flushChain(table,chainName):


def deleteChainExternalLinks(table,chainName):

def recursiveDeleteOfChain(table,chainName):
    logger.debug("recursiveDeleteOfChain: %s %s",table,chainName)

    # flush chain
    c = execIptable("-t "+table+" -F "+chainName,exitOnFail=True)
    # delete chain
    c = execIptable("-t "+table+" -X "+chainName,exitOnFail=True)


def createChainName(chainName):
    return CUSTOM_CHAIN_PREFIX+chainName


def buildCommandChainJumpRule(table,jumpFromChain,jumpToChain,position,jumpAdditionalParams=""):
    postionNumber=""
    rulePosition="-A" # append (last rule )
    if position=="first":
        rulePosition="-I" # insert (first rule )
        postionNumber="1"

    return "-t "+table+" "+rulePosition+" "+jumpFromChain+" "+postionNumber+" "+jumpAdditionalParams+" -j "+jumpToChain

def createAutoPositionedChain(table,destionationChain,position="first"):
    destionationChain=destionationChain.upper()
    if position not in ["first","last"]:
        sys.exit("invalid param position "+ position)
    chainName = createChainName(position+"_"+table+"_"+destionationChain)
    logger.debug("creating autopositioned chain : %s",chainName)
    c = execIptable("-t "+table+" -N "+chainName,exitOnFail=True)
    c = execIptable(
        buildCommandChainJumpRule(table,destionationChain,chainName,position)
        ,exitOnFail=True)

    # todo positioning of created chains






class ExecBashCommand:

    def __init__(self,command,exitOnFail=False):
        self.command = command
        logger.debug( "COMMAND ######################> %s " , self.command )
        self.p = subprocess.Popen(self.command , shell=True, stdout=subprocess.PIPE ,stderr=subprocess.PIPE)
        self.err = self.p.stderr.read().rstrip()
        self.out = self.p.stdout.read().rstrip()
        self.p.wait()
        self.rc = self.p.returncode
        logger.debug("COMMAND STDOUT######################> %s " , self.out)
        logger.debug("COMMAND STDERR######################> %s " , self.err)
        logger.debug("COMMAND rc######################> %s " , self.rc)
        if exitOnFail and self.rc != 0:
            logger.error("!!!! FATAL ERROR,  command failed , exiting rc = %s , command = %s , stderr = %s , stdout =  %s" , self.rc,self.command,self.err,self.out)
            sys.exit("error")





def get_args():
    """
    parse arguments
    """

    usage = 'validate counterservlet data and send results back to collectd'
    parser = optparse.OptionParser(usage=usage)


    parser.add_option(
        '--uninstall', '-U',
        action="store_true",
        default=False,
        help='uninstall iptables customizations',
        dest='param_uninstall'
    )

    parser.add_option(
        '--template', '-T',
        type='string',
        default="",
        help='location of template file',
        dest='param_template'
    )

    parser.add_option(
        '--chains-prefix', '-P',
        type='string',
        default="",
        help='custom chains prefix',
        dest='param_chains_prefix'
    )

    return parser.parse_args()[0]


if __name__ == '__main__':
    # /usr/share/collectd/types.db
    OPTIONS = get_args()

    if OPTIONS.param_chains_prefix != "":
        CUSTOM_CHAIN_PREFIX = OPTIONS.param_chains_prefix

    #c = ExecBashCommand("sudo iptables -nvL")

    setDefaultAcceptPolicy()


    logger.info("custom chains : %s " , findCustomChains("filter") )
    logger.info("deleting chains "  )

    map(
        lambda x:recursiveDeleteOfChain("filter",x) ,
        findCustomChains("filter"))

    logger.info("custom chains : %s " , findCustomChains("filter") )


    #print findCustomChains("filter")
    createAutoPositionedChain("filter","input")
    createAutoPositionedChain("filter","input","last")

    logger.info("custom chains : %s " , findCustomChains("filter") )



    #print "command executed : " , c.out


