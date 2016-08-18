#!/usr/bin/env python

import subprocess
import select
import os, pty

def get_cli_subprocess_handle():
    masterPTY, slaveTTY = pty.openpty()
    return masterPTY, slaveTTY, subprocess.Popen(
                                                 '/bin/bash',
                                                 shell=False,
                                                 stdin=slaveTTY,
                                                 stdout=slaveTTY,
                                                 stderr=slaveTTY,
                                                 )
masterPTY, slaveTTY, sub = get_cli_subprocess_handle()
select.select([masterPTY],[],[])
print(os.read(masterPTY, 1024))
