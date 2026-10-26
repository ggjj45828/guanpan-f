#!/bin/sh
set -eu

data_dir="${F_MINUTE_DATA_DIR:-/data}"
if [ "$data_dir" != "/data" ]; then
    echo "F_MINUTE_DATA_DIR must remain /data inside the container" >&2
    exit 1
fi

mkdir -p /data
if ! chown 10001:10001 /data; then
    echo "Cannot assign /data to service UID 10001; check that the NAS volume is writable and not read-only/root-squashed" >&2
    exit 1
fi
if ! chmod u+rwx /data; then
    echo "Cannot grant service UID 10001 access to /data" >&2
    exit 1
fi

for path in /data/* /data/.[!.]* /data/..?*; do
    [ -e "$path" ] || continue
    owner="$(stat -c %u "$path")"
    if [ "$owner" != "10001" ] && ! chown -R 10001:10001 "$path"; then
        echo "Cannot assign existing data path to service UID 10001: $path" >&2
        exit 1
    fi
done

exec setpriv --reuid=10001 --regid=10001 --clear-groups -- "$@"
