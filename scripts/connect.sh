set -euo pipefail

if [ ! -f .thunder/instance_id ]; then
  echo "No .thunder/instance_id found. Run the create script first." >&2
  exit 1
fi

ID=$(cat .thunder/instance_id)
echo "Connecting to $ID..."
tnr connect "$ID"