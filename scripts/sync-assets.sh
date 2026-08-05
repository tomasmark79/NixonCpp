#!/usr/bin/env bash

set -euo pipefail

SOURCE_DIR="${1:?Missing source asset directory}"
DEST_DIR="${2:?Missing destination asset directory}"
STAMP_FILE="${3:?Missing stamp file}"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Asset source directory does not exist: $SOURCE_DIR" >&2
    exit 1
fi

if [[ -z "$DEST_DIR" || "$DEST_DIR" == "/" || "$DEST_DIR" == "$SOURCE_DIR" ]]; then
    echo "Refusing unsafe asset destination: $DEST_DIR" >&2
    exit 1
fi

if [[ -d "$DEST_DIR" ]] && diff -qr "$SOURCE_DIR" "$DEST_DIR" >/dev/null; then
    if [[ ! -e "$STAMP_FILE" ]]; then
        touch "$STAMP_FILE"
    fi
    exit 0
fi

mkdir -p "$DEST_DIR"
find "$DEST_DIR" -mindepth 1 -delete
cp -a "$SOURCE_DIR/." "$DEST_DIR/"
touch "$STAMP_FILE"
