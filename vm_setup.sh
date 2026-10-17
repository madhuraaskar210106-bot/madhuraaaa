#!/bin/bash
# ==============================================================================
# Script: vm_setup.sh
# Target: mc-server VM (Run inside SSH or via gcloud compute ssh)
# Lab: Create and Configure Virtual Machines (CBL016)
# ==============================================================================
set -e

echo "=========================================================="
echo "Step 1: Format and Mount SSD Data Disk"
echo "=========================================================="

# Create temporary backup of /home/minecraft if files already exist on root disk
if [ -d /home/minecraft ] && [ "$(ls -A /home/minecraft 2>/dev/null)" ] && ! grep -qs '/home/minecraft' /proc/mounts; then
    echo "Caching existing files from unmounted /home/minecraft..."
    sudo mkdir -p /tmp/mc_cache
    sudo cp -r /home/minecraft/* /tmp/mc_cache/ 2>/dev/null || true
fi

sudo mkdir -p /home/minecraft

# Format and mount the persistent SSD if not already mounted
if ! grep -qs '/home/minecraft' /proc/mounts; then
    echo "Formatting disk /dev/disk/by-id/google-minecraft-disk..."
    sudo mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/disk/by-id/google-minecraft-disk || true

    echo "Mounting disk to /home/minecraft..."
    sudo mount -o discard,defaults /dev/disk/by-id/google-minecraft-disk /home/minecraft
else
    echo "Disk is already mounted at /home/minecraft."
fi

# Restore cached files if any
if [ -d /tmp/mc_cache ] && [ "$(ls -A /tmp/mc_cache 2>/dev/null)" ]; then
    echo "Restoring cached files to mounted disk..."
    sudo cp -r /tmp/mc_cache/* /home/minecraft/ 2>/dev/null || true
    sudo rm -rf /tmp/mc_cache
fi

echo "=========================================================="
echo "Step 2: Install Headless JRE, Screen, Wget & Server"
echo "=========================================================="
sudo apt-get update -y
sudo apt-get install -y default-jre-headless screen wget

cd /home/minecraft

# Download server.jar if missing
if [ ! -f /home/minecraft/server.jar ]; then
    echo "Downloading Minecraft server 1.11.2 JAR..."
    sudo wget -q https://launcher.mojang.com/v1/objects/d0d0fe2b1dc6ab4c65554cb734270872b72dadd6/server.jar -O /home/minecraft/server.jar
fi

# Accept EULA
echo "eula=true" | sudo tee /home/minecraft/eula.txt >/dev/null

# Start Minecraft server in detached screen session 'mcs' if not running
if ! sudo screen -list | grep -q "mcs"; then
    echo "Starting Minecraft server in screen session 'mcs'..."
    cd /home/minecraft
    sudo screen -d -m -S mcs java -Xmx1024M -Xms1024M -jar /home/minecraft/server.jar nogui
else
    echo "Minecraft server screen session 'mcs' is already running."
fi

# Ensure world directory exists
sudo mkdir -p /home/minecraft/world

echo "=========================================================="
echo "Step 3: Setup Backup Script & Crontab"
echo "=========================================================="
PROJECT_ID=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id 2>/dev/null || gcloud config get-value project 2>/dev/null)
export YOUR_BUCKET_NAME="$PROJECT_ID"
echo "YOUR_BUCKET_NAME=$PROJECT_ID" | sudo tee -a /root/.profile ~/.profile >/dev/null

# Attempt to create the bucket if not already created
gcloud storage buckets create "gs://${PROJECT_ID}-minecraft-backup" 2>/dev/null || true

# Write backup.sh
cat << 'EOF' | sudo tee /home/minecraft/backup.sh >/dev/null
#!/bin/bash
if [ -z "$YOUR_BUCKET_NAME" ]; then
    YOUR_BUCKET_NAME=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id 2>/dev/null || gcloud config get-value project 2>/dev/null)
fi

# Ensure world directory exists
if [ ! -d "${BASH_SOURCE%/*}/world" ]; then
    mkdir -p "${BASH_SOURCE%/*}/world"
fi

screen -r mcs -X stuff '/save-all\n/save-off\n' 2>/dev/null || true
/usr/bin/gcloud storage cp -R "${BASH_SOURCE%/*}/world" "gs://${YOUR_BUCKET_NAME}-minecraft-backup/$(date "+%Y%m%d-%H%M%S")-world"
screen -r mcs -X stuff '/save-on\n' 2>/dev/null || true
EOF

sudo chmod 755 /home/minecraft/backup.sh

# Create Cloud Storage bucket if not already existing
echo "Ensuring backup bucket gs://${PROJECT_ID}-minecraft-backup exists..."
gcloud storage buckets create "gs://${PROJECT_ID}-minecraft-backup" 2>/dev/null || true

# Run test backup
echo "Executing test backup to gs://${PROJECT_ID}-minecraft-backup/ ..."
sudo YOUR_BUCKET_NAME="$PROJECT_ID" /home/minecraft/backup.sh || true

# Schedule cron job every 4 hours
(sudo crontab -l 2>/dev/null | grep -v "/home/minecraft/backup.sh"; echo "0 */4 * * * /home/minecraft/backup.sh") | sudo crontab -

echo "=========================================================="
echo "VM Configuration Complete!"
echo "Data disk mounted, Minecraft server running, and backups scheduled."
echo "=========================================================="
