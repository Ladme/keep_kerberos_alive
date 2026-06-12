#!/bin/bash

# Utilities for obtaining perpetual Heimdal Kerberos tickets on Metacentrum-family clusters
# Version 1.0.0
# MIT License
# Copyright (c) 2026 Ladislav Bartos

# path to a keytab used by keep_kerberos_alive
export KKA_KEYTAB="${HOME}/keep_kerberos_alive/kka.keytab"

# default renew interval is 3 hours
# the default ticket lifetime is 10 hours, so even if one kinit randomly fails,
# we still have plenty of time to renew before the ticket expires
export KKA_RENEW_INTERVAL=10800

keep_kerberos_alive() (
    # ensure that the required env vars are set
    local KEYTAB="${KKA_KEYTAB:?"Error: KKA_KEYTAB environment variable is not set."}"
    local RENEW_INTERVAL="${KKA_RENEW_INTERVAL:?"Error: KKA_RENEW_INTERVAL environment variable is not set."}"

    # check that a command was actually passed
    if [ $# -eq 0 ]; then
        echo "Error: No command provided to keep_kerberos_alive." >&2
        exit 1
    fi

    # check that the keytab exists
    if [ ! -f "$KEYTAB" ]; then
        echo "Error: Keytab file not found at '$KEYTAB'" >&2
        exit 1
    fi

    # get principal from keytab
    local PRINCIPAL=$(/usr/bin/ktutil -k "$KEYTAB" list 2>/dev/null \
        | awk '{for (i=1;i<=NF;i++) if ($i ~ /@/) {print $i; exit}}')

    # set an isolated Kerberos credentials cache for this process
    # use this subshell's PID to avoid conflicts with other processes
    export KRB5CCNAME="FILE:/tmp/krb5cc_${BASHPID}"

    # get new ticket from keytab before starting to avoid issues with stale tickets
    if ! /usr/bin/kinit -kt "$KEYTAB" "$PRINCIPAL"; then
        echo "Error: Initial kinit failed. Aborting." >&2
        exit 1
    fi

    # start the background ticket renewal loop
    # it runs in its own process group so
    # cleanup kills both the loop and the sleep child
    setsid bash -c '
        while true; do
            sleep "$1"
            /usr/bin/kinit -kt "$2" "$3"
        done
    ' _ "${RENEW_INTERVAL}" "${KEYTAB}" "${PRINCIPAL}" &
    local RENEW_PID=$!

    # do cleanup no matter how the script exits
    # this will not work if the script is SIGKILLed
    cleanup() {
        # use negative PID, which kills the whole process group
        kill -- -"${RENEW_PID}" 2>/dev/null
        rm -f "${KRB5CCNAME#FILE:}"
    }
    trap cleanup EXIT INT TERM

    # execute the actual script/command
    "$@"

    # exit the subshell
    exit $?
)

resurrect_kerberos() {
    # ensure that the required env vars are set
    local KEYTAB="${KKA_KEYTAB:?"Error: KKA_KEYTAB environment variable is not set."}"

    # check that the keytab exists
    if [ ! -f "$KEYTAB" ]; then
        echo "Error: Keytab file not found at '$KEYTAB'" >&2
        return 1
    fi

    # get principal from keytab
    local PRINCIPAL=$(/usr/bin/ktutil -k "$KEYTAB" list 2>/dev/null \
        | awk '{for (i=1;i<=NF;i++) if ($i ~ /@/) {print $i; exit}}')

    # get a ticket from the keytab
    if ! /usr/bin/kinit -kt "$KEYTAB" "$PRINCIPAL"; then
        echo "Error: kinit with keytab failed. Aborting." >&2
        return 1
    fi
}
