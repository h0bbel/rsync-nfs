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
  echo "$(date '+%Y-%m-%d %H:%M:%S') [entrypoint] $*"
}

DLOG() {
  if is_debug; then
    LOG "$@"
  fi
}

LOG "Starting rsync-nfs entrypoint"

# Dump env only in debug mode (avoids leaking secrets normally)
if is_debug; then
  LOG "Environment variables:"
  env | sort | sed 's/^/  /'
fi

# Validate required variables
: "${NFS_SERVER:?NFS_SERVER not set}"
: "${NFS_PATH:?NFS_PATH not set}"

NFS_MOUNT_POINT="${NFS_MOUNT_POINT:-/data}"
NFS_VERSION="${NFS_VERSION:-4.1}"

LOG "Configuration:"
LOG "  NFS_SERVER=$NFS_SERVER"
LOG "  NFS_PATH=$NFS_PATH"
LOG "  NFS_MOUNT_POINT=$NFS_MOUNT_POINT"
LOG "  NFS_VERSION=$NFS_VERSION"
LOG "  DEBUG=$DEBUG"

# Prepare mount point
LOG "Creating mount point..."
mkdir -p "$NFS_MOUNT_POINT"

# Build mount options (Synology-safe defaults)
MOUNT_OPTS="vers=${NFS_VERSION},proto=tcp,rsize=1048576,wsize=1048576,noatime,nodiratime"

LOG "Mounting NFS with options: $MOUNT_OPTS"

if mount -t nfs -o "$MOUNT_OPTS" \
  "${NFS_SERVER}:${NFS_PATH}" \
  "${NFS_MOUNT_POINT}"; then
  LOG "NFS mount succeeded"
else
  LOG "ERROR: NFS mount failed"
  exit 1
fi

# Verify mount
DLOG "Verifying mount table:"
DLOG "$(mount | grep "$NFS_MOUNT_POINT" || echo 'Mount not found')"

# List contents (debug only)
if is_debug; then
  LOG "Listing contents of $NFS_MOUNT_POINT:"
  ls -la "$NFS_MOUNT_POINT" || LOG "WARNING: Cannot list directory"
fi

# Generate rsync config dynamically
RSYNC_CONF="/tmp/rsyncd.conf"

if is_debug; then
  LOG "Generating rsync config (debug mode)"

  cat > "$RSYNC_CONF" <<EOF
uid = nobody
gid = nobody
use chroot = no
#max connections = 10

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

LOG "Starting rsync daemon..."

exec rsync --daemon --no-detach $RSYNC_FLAGS --config="$RSYNC_CONF"