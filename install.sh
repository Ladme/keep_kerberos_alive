#!/bin/bash

# Installation script for Keep Kerberos Alive
# Version 0.1.0
# MIT License
# Copyright (c) 2026 Ladislav Bartos

set -euo pipefail

KKA_VERSION="v__VERSION__"
KKA_DIR="${HOME}/keep_kerberos_alive"
KKA_KEYTAB="${KKA_DIR}/kka.keytab"
KKA_ENV="${KKA_DIR}/env.sh"
RELEASE_URL="https://github.com/Ladme/keep_kerberos_alive/releases/download/${KKA_VERSION}/env.sh"
BASHRC="${HOME}/.bashrc"
MARKER="# >>> keep_kerberos_alive environment >>>"
MARKER_END="# <<< keep_kerberos_alive environment <<<"

# all new files are private
umask 077

# helpers
info() { echo "[kka-install] $*"; }
die()  { echo "Error: $*" >&2; exit 1; }

# create temporary workspace
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# download the env.sh file
info "Downloading Keep Kerberos Alive ${KKA_VERSION}..."
curl -fsSL "$RELEASE_URL" -o "${WORK}/env.sh" \
    || die "Download failed from $RELEASE_URL"
SRC_ENV="${WORK}/env.sh"

# install the environment
mkdir -p "$KKA_DIR"
chmod 700 "$KKA_DIR"
install -m 600 "$SRC_ENV" "$KKA_ENV"
info "Installed environment to $KKA_ENV"

# set up sourcing in .bashrc
if grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
    info ".bashrc already sources the keep_kerberos_alive environment; skipping."
else
    {
        echo "\n"
        echo "$MARKER"
        echo "# Set up by the keep_kerberos_alive installer; sources the kka functions."
        echo "[ -f \"\$HOME/keep_kerberos_alive/env.sh\" ] && source \"\$HOME/keep_kerberos_alive/env.sh\""
        echo "$MARKER_END"
    } >> "$BASHRC"
    info "Added source line to $BASHRC"
fi

# check that the user has a valid Kerberos ticket
if ! /usr/bin/klist >/dev/null 2>&1; then
    die "No valid Kerberos ticket found. Please run 'kinit' and re-run this installer."
fi

# get the principal from an active klist
PRINCIPAL="$(/usr/bin/klist 2>/dev/null | awk '/Principal:/ {for (i=1;i<=NF;i++) if ($i ~ /@/) {print $i; exit}}')"
[ -n "$PRINCIPAL" ] || die "Could not determine principal from klist. Please run 'kinit' and re-run this installer."
info "Using principal: $PRINCIPAL"

# backup an existing keytab
if [ -e "$KKA_KEYTAB" ]; then
    BACKUP="${KKA_KEYTAB}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$KKA_KEYTAB" "$BACKUP"
    info "Existing keytab moved to $BACKUP"
fi

# create the keytab using ktutil
info "ktutil will now prompt for the Kerberos password of ${PRINCIPAL}."
/usr/bin/ktutil -k "$KKA_KEYTAB" add \
    -p "$PRINCIPAL" \
    -V 1 \
    -e aes256-cts-hmac-sha1-96 \
    || die "ktutil failed to add the principal to the keytab."

# lock everything
chmod 700 "$KKA_DIR"
chmod 600 "$KKA_KEYTAB"
chmod 600 "$KKA_ENV"
info "Locked permissions: $KKA_DIR, keytab, and env.sh."

info "Done. Open a new shell, or run: source \"$KKA_ENV\""
