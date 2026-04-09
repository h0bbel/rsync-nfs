# rsync-nfs

A minimal Docker container that exposes an rsync daemon and writes directly to an NFS backend.

## Why this exists

Synology Hyper Backup cannot target remote NFS mounts directly.

- Hyper Backup requires a destination at the **root of a volume**
- Synology mounts remote NFS shares in **subdirectories only**

This makes it impossible to use a remote NFS share as a backup destination.

This container solves that by acting as a bridge:

*Synology → rsync → container → NFS*

More details:

## Features

- Extremely small Alpine-based image
- Rsync daemon frontend
- NFS backend (mounted inside container)
- Debug mode via environment variable
- Config generated at runtime

## Usage

### Run container

``` bash
docker run -d \
  --name rsync-nfs \
  --privileged \
  -p 873:873 \
  -e NFS_SERVER=10.111.1.101 \
  -e NFS_PATH=/export/data \
  rsync-nfs
```

### Optional environment variables

| Variable        | Description                     | Default |
| --------------- | ------------------------------- | ------- |
| NFS_VERSION     | NFS version (3, 4, 4.1, 4.2)    | 4       |
| NFS_MOUNT_POINT | Mount location inside container | /data   |
| DEBUG           | Enable logging to stdout        | false   |

### Logs

```bash
docker logs -f rsync-nfs
```

## Synology Setup

The container can run on Synology directly, just ensure that you change the external port to something else than port 873 as this is in use already. I've used port 8073 in my setup. Hyper Backup also requires that you put in a username in the job settings, but this information is disregarded by the container.

### Notes

- **Requires privileged mode for NFS mounting**
- In my testing mounting as NFS 4 works when running on Synology, NFS 4.1 does not work.
- It currently has no authentication added. Not for the rsync front end, or for the NFS mount. My setup doesn't require it, but I might add it in a later version if there is a need for it.

### Hyper Backup

- Choose rsync-compatible server
- Server: Container IP
- Port: 873 or other port configured during container setup.
- Module: data (this is the NFS mount point in the container)

## License

[MIT]( https://github.com/h0bbel/rsync-nfs?tab=License-1-ov-file)