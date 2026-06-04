## Keep Kerberos Alive

Get perpetual Kerberos ticket renewal on Metacentrum-family clusters. Only works with Kerberos Heimdal.

## Installation

```bash
curl -fsSL https://github.com/Ladme/keep_kerberos_alive/releases/download/v0.1.0/install.sh | bash
```

You will be prompted for your Kerberos password, twice. Provide the password you use to log in to your desktop. Then source your `.bashrc` file to finish the installation.

## Features

Keep Kerberos Alive provides two bash functions: `keep_kerberos_alive` and `resurrect_kerberos`.

### `keep_kerberos_alive`

`keep_kerberos_alive` makes sure that a process it wraps always has a valid Kerberos ticket.

This command is mostly intended for long-running operations run using `nohup`.

Example:

*long_running_script.sh*
```bash
#!/bin/bash

while true; do
    qstat -fxw
    sleep 12000
done
```

If you run this using `nohup ./long_running_script.sh &`, the script will run out of valid Kerberos tickets in <10 hours and fail.

To avoid this, you can write a wrapper script which uses `keep_kerberos_alive`.

*wrapper.sh*
```bash
#!/bin/bash

# you need to source the .bashrc file when using nohup
source ~/.bashrc

# wrap the long-running script into keep_kerberos_alive
keep_kerberos_alive ./long_running_script.sh
```

Then run the wrapper using `nohup ./wrapper.sh &`.

Alternatively, convert your `long_running_script.sh` into a bash function and put everything into a single script.

*single_script.sh*
```bash
#!/bin/bash

source ~/.bashrc

long_running_task() {
    while true; do
        qstat -fxw
        sleep 12000
    done
}

keep_kerberos_alive long_running_task
```

You can also use `keep_kerberos_alive` to wrap a python script.

*wrapper.sh*
```bash
#!/bin/bash

source ~/.bashrc

keep_kerberos_alive python3 long_running_script.py
```

Again, run using `nohup ./wrapper.sh &`.

***

### `resurrect_kerberos`

`resurrect_kerberos` restores a Kerberos ticket in your current session without a password prompt.

This command is mostly intended to be used in cron jobs. 

Example:

*crontab*
```bash
# .bashrc file needs to be sourced to get access to the Keep Kerberos Alive functions
SHELL=/bin/bash     
BASH_ENV=~/.bashrc

0 0 * * * /path/to/your/cron/job/script.sh
```

*script.sh*
```bash
#!/bin/bash

# get a valid Kerberos ticket
resurrect_kerberos
# perform an operation that requires a valid Kerberos ticket
# such as querying the batch system
qstat -fxw
# or creating a file on shared storage
touch /storage/brno12-cerit/home/${USER}/some_file.txt
```
