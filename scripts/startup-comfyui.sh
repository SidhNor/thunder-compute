#!/usr/bin/env bash
# Run inside the instance. Safe to re-run.
set -euo pipefail

# Env:
#   R2_ACCESS_KEY, R2_SECRET_KEY, R2_ENDPOINT
# Optional:
#   R2_MODELS_BUCKET (default: gg-models-thunder)
#   COMFY_DIR (default: /home/ubuntu/ComfyUI)
#   PYTHON_BIN (default: python)

R2_MODELS_BUCKET="${R2_MODELS_BUCKET:-gg-models-thunder}"
COMFY_DIR="${COMFY_DIR:-/home/ubuntu/ComfyUI}"
PYTHON_BIN="${PYTHON_BIN:-/home/ubuntu/ComfyUI/.venv/bin/python3}"

# Ensure rclone exists
if ! command -v rclone >/dev/null 2>&1; then
  echo "Installing rclone..."
  curl -fsSL https://rclone.org/install.sh | bash
fi

# Configure r2 remote once
if ! rclone listremotes 2>/dev/null | grep -q '^r2:'; then
  : "${R2_ACCESS_KEY:?Set R2_ACCESS_KEY}"
  : "${R2_SECRET_KEY:?Set R2_SECRET_KEY}"
  : "${R2_ENDPOINT:?Set R2_ENDPOINT}"
  rclone config create r2 s3 \
    provider=Cloudflare \
    access_key_id="$R2_ACCESS_KEY" \
    secret_access_key="$R2_SECRET_KEY" \
    endpoint="$R2_ENDPOINT" \
    acl=
fi

# Update ComfyUI (minimal network)
if [ -d "$COMFY_DIR/.git" ]; then
  echo "Updating ComfyUI in $COMFY_DIR ..."
  git -C "$COMFY_DIR" pull --ff-only
else
  echo "ComfyUI not found at $COMFY_DIR"; exit 1
fi

# Update Manager if present
if [ -d "${COMFY_DIR}/custom_nodes/ComfyUI-Manager/.git" ]; then
  echo "Updating ComfyUI-Manager..."
  git -C "${COMFY_DIR}/custom_nodes/ComfyUI-Manager" pull --ff-only || true
fi

# Install/upgrade Python deps
echo "Installing Python dependencies..."
$PYTHON_BIN -m pip install -r "${COMFY_DIR}/requirements.txt"
$PYTHON_BIN -m pip install -r "${COMFY_DIR}/manager_requirements.txt"

cd "custom_nodes/comfyui-manager"
git reset --hard
git pull
$PYTHON_BIN -m pip install -r requirements.txt

cd "${COMFY_DIR}/custom_nodes"
git clone https://github.com/rgthree/rgthree-comfy.git
git clone https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git
git clone https://github.com/banodoco/steerable-motion
git clone https://github.com/kijai/ComfyUI-KJNodes.git
git clone https://github.com/yolain/ComfyUI-Easy-Use.git
git clone https://github.com/city96/ComfyUI-GGUF.git
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git
git clone https://github.com/willmiao/ComfyUI-Lora-Manager.git


$PYTHON_BIN -m pip install -r steerable-motion/requirements.txt
$PYTHON_BIN -m pip install -r ComfyUI-GGUF/requirements.txt
$PYTHON_BIN -m pip install -r ComfyUI-Easy-Use/requirements.txt
$PYTHON_BIN -m pip install -r ComfyUI-VideoHelperSuite/requirements.txt
$PYTHON_BIN -m pip install -r ComfyUI-Lora-Manager/requirements.txt
$PYTHON_BIN ComfyUI-Frame-Interpolation/install.py

cd "${COMFY_DIR}"

$PYTHON_BIN -m pip install sageattention --no-build-isolation


# Sync models from R2
echo "Syncing models r2:${R2_MODELS_BUCKET}/models -> ${COMFY_DIR}/models"
mkdir -p "${COMFY_DIR}/models"
rclone sync "r2:${R2_MODELS_BUCKET}/models" "${COMFY_DIR}/models" \
    --progress --transfers=2 --multi-thread-streams 128 \
    --multi-thread-cutoff 200M --buffer-size 1G \
    --s3-disable-checksum --fast-list \
    --s3-chunk-size 128M --s3-upload-concurrency 32


R2_WORKFLOWS_BUCKET="${R2_WORKFLOWS_BUCKET:-$R2_MODELS_BUCKET}"
R2_WORKFLOWS_PREFIX="${R2_WORKFLOWS_PREFIX:-workflows}"

# Pull private workflows from R2 (safe if empty)
mkdir -p "${COMFY_DIR}/workflows"
if rclone lsf "r2:${R2_WORKFLOWS_BUCKET}/${R2_WORKFLOWS_PREFIX}" >/dev/null 2>&1; then
  echo "Syncing workflows r2:${R2_WORKFLOWS_BUCKET}/${R2_WORKFLOWS_PREFIX} -> ${COMFY_DIR}/workflows"
  rclone sync "r2:${R2_WORKFLOWS_BUCKET}/${R2_WORKFLOWS_PREFIX}" "${COMFY_DIR}/user/default/workflows" --progress --fast-list
else
  echo "No workflows found at r2:${R2_WORKFLOWS_BUCKET}/${R2_WORKFLOWS_PREFIX} (skipping)"
fi

# Start ComfyUI using Thunder's launcher
echo "Starting ComfyUI..."
cd "${COMFY_DIR}"
start-comfyui

