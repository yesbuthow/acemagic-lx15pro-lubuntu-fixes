#!/bin/bash
set -euo pipefail

SWAPFILE="${1:-/swapfile}"

if [ ! -f "$SWAPFILE" ]; then
    echo "Errore: swapfile non trovato: $SWAPFILE" >&2
    exit 1
fi

PAGE_SIZE="$(getconf PAGESIZE)"
FS_BLOCK_SIZE="$(stat -f -c %S "$SWAPFILE")"

PHYSICAL_BLOCK="$(
    sudo filefrag -v "$SWAPFILE" |
    awk '$1 ~ /^0:$/ {gsub(/\.\./,"",$4); gsub(/:/,"",$4); print $4; exit}'
)"

if [ -z "$PHYSICAL_BLOCK" ]; then
    echo "Errore: impossibile leggere il primo physical offset con filefrag." >&2
    exit 1
fi

RESUME_OFFSET=$(( PHYSICAL_BLOCK * FS_BLOCK_SIZE / PAGE_SIZE ))

echo "swapfile=$SWAPFILE"
echo "page_size=$PAGE_SIZE"
echo "filesystem_block_size=$FS_BLOCK_SIZE"
echo "first_physical_block=$PHYSICAL_BLOCK"
echo "resume_offset=$RESUME_OFFSET"
