#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="${COMFY_DIR:-/home/ubuntu/ComfyUI}"
R2_WORKFLOWS_BUCKET="${R2_WORKFLOWS_BUCKET:-${R2_MODELS_BUCKET:-gg-models-thunder}}"
R2_WORKFLOWS_PREFIX="${R2_WORKFLOWS_PREFIX:-workflows}"

command -v rclone >/dev/null || { echo "rclone missing"; exit 1; }
: "${R2_ACCESS_KEY:?Set R2_ACCESS_KEY}"
: "${R2_SECRET_KEY:?Set R2_SECRET_KEY}"
: "${R2_ENDPOINT:?Set R2_ENDPOINT}"

if ! rclone listremotes 2>/dev/null | grep -q '^r2:'; then
  rclone config create r2 s3 provider=Cloudflare access_key_id="$R2_ACCESS_KEY" secret_access_key="$R2_SECRET_KEY" endpoint="$R2_ENDPOINT" acl=
fi

echo "Saving workflows ${COMFY_DIR}/workflows -> r2:${R2_WORKFLOWS_BUCKET}/${R2_WORKFLOWS_PREFIX}"
rclone sync "${COMFY_DIR}/workflows" "r2:${R2_WORKFLOWS_BUCKET}/${R2_WORKFLOWS_PREFIX}" --progress --fast-list
echo "Done."