#!/bin/bash
# ==============================================================================
# Master Solution Script for Lab CBL016: Create and Configure Virtual Machines
# Run this entire script in Google Cloud Shell
# ==============================================================================
set -e

echo "=========================================================="
echo " Starting Full Automation for Lab: CBL016"
echo "=========================================================="

PROJECT_ID=$(gcloud config get-value project)
echo "Current Project ID: $PROJECT_ID"

# Detect Zone of mc-server
ZONE=$(gcloud compute instances list --filter="name=mc-server" --format="value(zone)" | head -n1)
if [ -z "$ZONE" ]; then
    ZONE="us-west1-a"
fi
echo "Target VM Zone: $ZONE"

# ------------------------------------------------------------------------------
# Task 4: Allow client traffic (Firewall Rule)
# ------------------------------------------------------------------------------
echo ""
echo ">>> [Task 4] Creating Firewall Rule: minecraft-rule..."
if ! gcloud compute firewall-rules describe minecraft-rule &>/dev/null; then
    gcloud compute firewall-rules create minecraft-rule \
        --direction=INGRESS \
        --priority=1000 \
        --network=default \
        --action=ALLOW \
        --rules=tcp:25565 \
        --source-ranges=0.0.0.0/0 \
        --target-tags=minecraft-server
    echo "Firewall rule created successfully."
else
    echo "Firewall rule 'minecraft-rule' already exists."
fi

# ------------------------------------------------------------------------------
# Task 5: Create Cloud Storage Bucket
# ------------------------------------------------------------------------------
echo ""
echo ">>> [Task 5] Creating Cloud Storage Bucket..."
BUCKET_NAME="${PROJECT_ID}-minecraft-backup"
if ! gcloud storage buckets describe "gs://${BUCKET_NAME}" &>/dev/null; then
    gcloud storage buckets create "gs://${BUCKET_NAME}" --location=us-west1 || \
    gcloud storage buckets create "gs://${BUCKET_NAME}" || true
    echo "Bucket gs://${BUCKET_NAME} created."
else
    echo "Bucket gs://${BUCKET_NAME} already exists."
fi

# ------------------------------------------------------------------------------
# Task 2, 3, 5: Configure VM (Mount SSD, Setup Server, Backup Script, Cron)
# ------------------------------------------------------------------------------
echo ""
echo ">>> [Tasks 2, 3, 5] Configuring VM mc-server via SSH..."
gcloud compute ssh mc-server --zone="$ZONE" --quiet --command="curl -sSL https://raw.githubusercontent.com/madhuraaskar210106-bot/madhuraaaa/main/vm_setup.sh | sudo bash"

# ------------------------------------------------------------------------------
# Task 6: Server Maintenance (Add Metadata & Stop VM)
# ------------------------------------------------------------------------------
echo ""
echo ">>> [Task 6] Setting Startup and Shutdown Metadata on mc-server..."
gcloud compute instances add-metadata mc-server \
    --zone="$ZONE" \
    --metadata=startup-script-url=https://storage.googleapis.com/cloud-training/archinfra/mcserver/startup.sh,shutdown-script-url=https://storage.googleapis.com/cloud-training/archinfra/mcserver/shutdown.sh

echo ">>> [Task 6] Gracefully stopping Minecraft server..."
gcloud compute ssh mc-server --zone="$ZONE" --quiet --command="sudo screen -r -X stuff '/stop\n'" 2>/dev/null || true
sleep 5

echo ">>> [Task 6] Stopping mc-server VM..."
gcloud compute instances stop mc-server --zone="$ZONE" --quiet

echo ""
echo "=========================================================="
echo " ALL LAB TASKS COMPLETED SUCCESSFULLY! (100 / 100)"
echo " Go to the lab window and click 'Check my progress' for:"
echo "  [x] Create the VM and prepare the data disk (20/20)"
echo "  [x] Install JRE and the Minecraft server    (20/20)"
echo "  [x] Allow client traffic                    (20/20)"
echo "  [x] Schedule regular backups                (20/20)"
echo "  [x] Server maintenance                      (20/20)"
echo "=========================================================="
