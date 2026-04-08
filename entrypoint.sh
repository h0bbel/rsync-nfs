#!/bin/sh
set -eu

LOG() {
  [ "${DEBUG:-false}" = "true" ] && echo "[entrypoint] $*"
}

: "${NFS_SERVER:?NFS_SERVER not set}"
: "${NFS_PATH:?NFS_PATH not set}"

NFS_MOUNT_POINT="${NFS_MOUNT_POINT:-/data}"
NFS_VERSION="${NFS_VERSION:-4.1}"
DEBUG="${DEBUG:-false}"

LOG "Starting rsync-nfs"
LOG "NFS_SERVER=$NFS_SERVER"
LOG "NFS_PATH=$NFS_PATH"
LOG "NFS_VERSION=$NFS_VERSION"

mkdir -p "$NFS_MOUNT_POINT"

# Mount options tuned for performance
MOUNT_OPTS="vers=${NFS_VERSION},tcp,rsize=1048576,wsize=1048576,noatime,nodiratime"

LOG "Mounting NFS with options: $MOUNT_OPTS"
mount -t nfs -o "$MOUNT_OPTS" "$NFS_SERVER:$NFS_PATH" "$NFS_MOUNT_POINT"

RSYNC_CONF="/tmp/rsyncd.conf"

if [ "$DEBUG" = "true" ]; then
  LOG "Debug mode enabled"

  cat > "$RSYNC_CONF" <<EOF
uid = nobody
gid = nobody
use chroot = no
max connections = 10

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