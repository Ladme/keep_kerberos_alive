## Keep Kerberos Alive

Get perpetual Kerberos ticket renewal on Metacentrum-family clusters. Only works with Kerberos Heimdal.

> [!warning]
> This tool is written specifically for the needs of the [RoVa Lab](https://vacha.ceitec.cz/) and intended to be used on Robox desktops. Using Keep Kerberos Alive on Metacentrum frontends is not only *not* recommended, but will in fact most likely not work since all processes running on a Metacentrum frontend for longer than 1-2 hours are automatically killed.

## Installation

```bash
curl -fsSL https://github.com/Ladme/keep_kerberos_alive/releases/latest/download/install.sh | bash
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

## How does this work?

As part of the installation process, a keytab is generated and saved to `~/keep_kerberos_alive/kka.keytab`. A keytab is a file that contains cryptographic keys derived from your password, which Kerberos uses to verify your identity without ever storing or transmitting the password itself. Consequently, it can be used to obtain a valid Kerberos ticket without needing to provide a password. You only need a password to *generate* the keytab, which is why you are prompted for it during the installation.

> [!WARNING]
> Your keytab file is sensitive and should be kept secure. Do not share it with anyone, and do not move it from the location where it is placed after installation. Not only will Keep Kerberos Alive be unable to find it, but it may also become accessible to other users on the system and abused. **If you suspect your keytab file has been compromised, change your password immediately!** This makes the keytab file obsolete and prevents further unauthorized access.

The `keep_kerberos_alive` function works by spawning a background process that periodically (every 3 hours) generates a new Kerberos ticket using the configured keytab. This continues until the process wrapped inside `keep_kerberos_alive` finishes or fails, at which point the background renewal process is automatically terminated. You don't need to worry about the newly generated tickets overwriting the Kerberos tickets in your main session - `keep_kerberos_alive` uses its own isolated Kerberos credentials cache.

`resurrect_kerberos` is a simpler function that just generates a new Kerberos ticket from the keytab file and applies it to the current session.

The installer also ensures that both functions are available in your shell by sourcing them in your `.bashrc` file. However, nohup runs and cron jobs start with a minimal environment that does not load `.bashrc` automatically - so if you plan to use either Keep Kerberos Alive function in those contexts, you will need to source `.bashrc` explicitly at the start of your script.
