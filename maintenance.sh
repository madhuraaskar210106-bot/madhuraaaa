#!/bin/bash
# ==============================================================================
# Script: maintenance.sh
# Purpose: Task 6 - Server Maintenance (Metadata automation & VM stop)
# Run from Google Cloud Shell
# ==============================================================================
set -e

echo "=== Finding mc-server Zone ==="
ZONE=$(gcloud compute instances list --filter="name=mc-server" --format="value(zone)" | head -n1)
if [ -z "$ZONE" ]; then
    ZONE="us-west1-a"
fi
echo "Zone: $ZONE"

echo "=== Adding Startup and Shutdown Script Metadata ==="
gcloud compute instances add-metadata mc-server \
    --zone="$ZONE" \
    --metadata=startup-script-url=https://storage.googleapis.com/cloud-training/archinfra/mcserver/startup.sh,shutdown-script-url=https://storage.googleapis.com/cloud-training/archinfra/mcserver/shutdown.sh

echo "=== Gracefully Stopping Minecraft Server on VM ==="
gcloud compute ssh mc-server --zone="$ZONE" --quiet --command="sudo screen -r -X stuff '/stop\n'" 2>/dev/null || true
sleep 5

echo "=== Stopping mc-server VM Instance ==="
gcloud compute instances stop mc-server --zone="$ZONE" --quiet

echo "=========================================================="
echo "Task 6 Complete! Click Check my progress for Server maintenance."
echo "=========================================================="
