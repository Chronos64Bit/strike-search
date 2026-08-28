#!/bin/sh
# Strike Search entrypoint.
#
# Forked from protemplate/searxng. Two deliberate differences from upstream,
# both learned by breaking the live instance on 2026-08-27.

set -eu

CONF_DIR=/etc/searxng
BACKUP_DIR=/etc/searxng-backup
CONF="$CONF_DIR/settings.yml"

# 1. The repository is the source of truth, on every boot.
#
# Upstream copied from the backup only when settings.yml was *absent*. That is
# fine exactly once. Afterwards the volume holds a file, the copy is skipped
# forever, and editing this repo and redeploying changes nothing at all --
# the deploy succeeds, the service restarts, and it keeps serving the old
# config. That failure is silent, which is the worst kind.
#
# Copying every boot means a deploy actually deploys. The cost is that manual
# edits made inside the container do not survive a restart. That is the
# intended trade: config that only exists in a container cannot be reviewed,
# diffed, or rolled back.
if [ -d "$BACKUP_DIR" ]; then
    echo "strike: syncing config from image into $CONF_DIR"
    cp -f "$BACKUP_DIR"/* "$CONF_DIR"/
fi

# 2. Fail closed when the secret key is missing.
#
# Upstream warned and carried on, which left SearXNG's built-in
# "ultrasecretkey" default in place. SearXNG then refuses to start with
#   ERROR:searx.webapp: server.secret_key is not changed.
# several steps later, so the message you get describes a symptom rather than
# the cause. Worse, if it ever did boot, session cookies would be forgeable
# with a key that is public knowledge. Stopping here says what is wrong.
if [ -z "${SEARXNG_SECRET_KEY:-}" ]; then
    echo "strike: SEARXNG_SECRET_KEY is not set; refusing to start." >&2
    echo "strike: booting would leave the public default key in place." >&2
    exit 1
fi

# Anchored to the start of the line so it rewrites the setting and not any
# comment that happens to mention secret_key. Upstream's pattern was
# unanchored and global.
if [ -f "$CONF" ]; then
    echo "strike: setting secret_key from the environment"
    sed -i "s|^\( *\)secret_key:.*|\1secret_key: \"${SEARXNG_SECRET_KEY}\"|" "$CONF"
else
    echo "strike: $CONF is missing after sync; refusing to start." >&2
    exit 1
fi

exec /usr/local/searxng/entrypoint.sh "$@"
