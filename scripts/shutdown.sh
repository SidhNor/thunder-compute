#!/bin/bash
# shutdown.sh - Run locally after finishing

ID=$(tnr status | grep -oP '(?<=ID: )\d+' | tail -1)

# Optional: Sync outputs back to R2 or local
# rclone sync /workspace/ComfyUI/output r2:your-bucket-name/outputs --progress

tnr delete "$ID"
echo "Instance $ID deleted. All ephemeral data lost."