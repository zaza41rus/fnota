# Closed-lid mode

Optional; install from Keep Awake → Keep working with lid closed.
Uses `pmset -a disablesleep 1`, restoring the previous SleepDisabled value.
No password/automatic-lock preference changes and no promise to bypass a locked session.

Installation (native macOS administrator authorization):
- `/Library/PrivilegedHelperTools/local.fnota.lid` (root:wheel, 0555)
- `/Library/LaunchDaemons/local.fnota.lid.plist` (root:wheel, 0644)
- no sudoers changes, no arbitrary command execution service.

The helper accepts only a <=1KB, regular, non-symlink lease owned by the installation user,
with an 8-second heartbeat, valid signed fnota PID, and fixed installed executable path.
The signature requirement uses the existing ad-hoc bundle identity. It is not a strong
publisher identity: a local same-user attacker able to replace this user-installed app
could impersonate that identity. The helper's capability remains restricted to sleep control.
Developer ID signing is needed for stronger publisher authentication in distribution.

A root-owned journal `/private/var/db/fnota-lid-state` is written before changing sleep.
The helper restores on expired/missing lease, app exit, timer/session stop, high temperature,
low battery, SIGTERM, and startup after a helper crash. Failed restoration retains the
journal for retry. launchd KeepAlive restarts a crashed helper. Heartbeats stop if fnota hangs.
Status: `/private/var/run/fnota-lid-status-UID.json`; lease: `/private/var/run/fnota-lid-UID/lease.json`.

Avoid simultaneous closed-lid sessions in Amphetamine and fnota: the setting is global.
The helper preserves the pre-session value, including an existing override from another app.

Uninstall from About fnota; the bundled uninstall script bootouts only this service,
restores any remaining journal and removes only this helper and launch daemon.

Automated tests cover lease expiry, invalid/dead clients, clock rollback, original-value
preservation, crash recovery and failed restoration retries. Physical lid closure requires
live confirmation on the target Mac; it is not proven by assertions or unit tests alone.
