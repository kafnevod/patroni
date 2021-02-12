#!/usr/bin/python3
# EASY-INSTALL-ENTRY-SCRIPT: 'patroni==1.6.4','console_scripts','patroni'
__requires__ = 'patroni==1.6.4'
import re
import sys
from pkg_resources import load_entry_point

if __name__ == '__main__':
    sys.argv[0] = re.sub(r'(-script\.pyw?|\.exe)?$', '', sys.argv[0])
    sys.exit(
        load_entry_point('patroni==1.6.4', 'console_scripts', 'patroni')()
    )
