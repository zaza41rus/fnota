#!/bin/sh
set -eu
[ "$(/usr/bin/id -u)" = 0 ] || exit 1
/bin/launchctl bootout system/local.fnota.lid >/dev/null 2>&1 || true
# If the daemon was killed before it restored its journal, finish recovery here.
if [ -f /private/var/db/fnota-lid-state ]; then
 value=$(/bin/cat /private/var/db/fnota-lid-state)
 case "$value" in 0|1) /usr/bin/pmset -a disablesleep "$value" ;; *) exit 1 ;; esac
 /bin/rm -f /private/var/db/fnota-lid-state
fi
/bin/rm -f /Library/LaunchDaemons/local.fnota.lid.plist /Library/PrivilegedHelperTools/local.fnota.lid
