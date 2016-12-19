from pyiptdocker import *

logger.setLevel(logging.DEBUG)

## by non configuring those , defaults (ACCEPT) are applied
# CONFIG['DEFAULT_ACCEPT_POLICIES']['INPUT'] = 'DROP';
# CONFIG['DEFAULT_ACCEPT_POLICIES']['FORWARD'] = 'DROP';

initialize()
deleteAllCustomChains()




