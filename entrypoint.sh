#!/bin/sh
set -eu

DEBUG="${DEBUG:-false}"

is_debug() {
  case "$DEBUG" in
    1|true|TRUE|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

LOG() {
  if is_debug; then
    echo "[entrypoint] $*"
  fi
}

# Validate required env vars
: "${NFS_SERVER:?NFS_SERVER not set}"
: "${NFS_PATH:?NFS_PATH not set}"

NFS_MOUNT_POINT="${NFS_MOUNT_POINT:-/data}"
NFS_VERSION="${NFS_VERSION:-4.1}"

LOG "Starting rsync-nfs"
LOG "NFS_SERVER=$NFS_SERVER"
LOG "NFS_PATH=$NFS_PATH"
LOG "NFS_VERSION=$NFS_VERSION"
LOG "NFS_MOUNT_POINT=$NFS_MOUNT_POINT"

mkdir -p "$NFS_MOUNT_POINT"

# Mount NFS
MOUNT_OPTS="vers=${NFS_VERSION},tcp,rsize=1048576,wsize=1048576,noatime,nodiratime"

LOG "Mounting NFS with options: $MOUNT_OPTS"
mount -t nfs -o "$MOUNT_OPTS" "$NFS_SERVER:$NFS_PATH" "$NFS_MOUNT_POINT"

# Generate rsync config
RSYNC_CONF="/tmp/rsyncd.conf"

if is_debug; then
  LOG "Generating rsync config (debug mode)"

  cat > "$RSYNC_CONF" <<EOF
uid = nobody
gid = nobody
use chroot = no
max connections = 10

pid file = /var/run/rsyncd.pid
log file = /dev/stdout

transfer logging = yes
log format = %t [%p] %h %o %f %l %b

[data]
    path = $NFS_MOUNT_POINT
    read only = no
    list = yes
EOF

  RSYNC_FLAGS="--verbose"
else
  cat > "$RSYNC_CONF" <<EOF
uid = nobody
gid = nobody
use chroot = no

[data]
    path = $NFS_MOUNT_POINT
    read only = no
    list = yes
EOF

  RSYNC_FLAGS=""
fi

LOG "Starting rsync daemon"

exec rsync --daemon --no-detach $RSYNC_FLAGS --config="$RSYNC_CONF"