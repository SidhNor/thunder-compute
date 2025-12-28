#!/usr/bin/env bash
set -euo pipefail
# Usage: ./scripts/1. create-and-connect.sh [gpu] [storage_gb] [vcpus]

GPU=${1:-t4}
STORAGE=${2:-100}
VCPUS=${3:-8}

echo "Creating Thunder instance..."
tnr create --mode prototyping --template comfy-ui --gpu "$GPU" --disk-size-gb "$STORAGE" --vcpus "$VCPUS"

sleep 20
ID=$(tnr status | grep -oP '(?<=ID: )\d+' | tail -1)
if [ -z "${ID:-}" ]; then
  echo "Failed to get ID from 'tnr status'." >&2
  exit 1
fi

mkdir -p .thunder
echo "$ID" > .thunder/instance_id

echo "Instance $ID created."
echo "Next:"
echo "  - Connect: ./scripts/connect.sh"
echo "  - On the instance: run the GitHub one-liner to start ComfyUI."