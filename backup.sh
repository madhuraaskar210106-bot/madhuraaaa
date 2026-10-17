#!/bin/bash
# Backup script for Minecraft server world data to Google Cloud Storage
# Lab: Create and Configure Virtual Machines (CBL016)

# Detect Bucket Name if not set
if [ -z "$YOUR_BUCKET_NAME" ]; then
    YOUR_BUCKET_NAME=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id 2>/dev/null || gcloud config get-value project 2>/dev/null)
fi

# Ensure bucket exists
gcloud storage buckets describe "gs://${YOUR_BUCKET_NAME}-minecraft-backup" &>/dev/null || \
gcloud storage buckets create "gs://${YOUR_BUCKET_NAME}-minecraft-backup" 2>/dev/null || true

# Ensure world directory exists
if [ ! -d "${BASH_SOURCE%/*}/world" ]; then
    mkdir -p "${BASH_SOURCE%/*}/world"
fi

# Broadcast save commands to Minecraft screen session
screen -r mcs -X stuff '/save-all\n/save-off\n' 2>/dev/null || true

# Copy world folder to Cloud Storage with timestamp
/usr/bin/gcloud storage cp -R "${BASH_SOURCE%/*}/world" "gs://${YOUR_BUCKET_NAME}-minecraft-backup/$(date "+%Y%m%d-%H%M%S")-world"

# Resume auto-save
screen -r mcs -X stuff '/save-on\n' 2>/dev/null || true
