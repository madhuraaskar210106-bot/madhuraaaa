# Google Cloud Skills Boost: Create and Configure Virtual Machines (CBL016)

[![GitHub Repo](https://img.shields.io/badge/GitHub-madhuraaaa-blue?logo=github)](https://github.com/madhuraaskar210106-bot/madhuraaaa)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-CBL016-orange?logo=googlecloud)](https://www.skills.google/)
[![Lab Score](https://img.shields.io/badge/Score-100%2F100-brightgreen)](#)

Complete automation scripts, instructions, and copy-paste commands to achieve **100/100 points** on the Google Cloud Skills Boost lab **Create and Configure Virtual Machines** (`CBL016`).

---

## 📋 Checkpoints & Score Breakdown

| Checkpoint | Task Description | Points |
| :--- | :--- | :---: |
| **Task 1 & 2** | Create the VM and prepare the data disk | **20 / 20** |
| **Task 3** | Install the Java Runtime Environment (JRE) and the Minecraft server | **20 / 20** |
| **Task 4** | Allow client traffic (Firewall Rule) | **20 / 20** |
| **Task 5** | Schedule regular backups (Cloud Storage & Cron) | **20 / 20** |
| **Task 6** | Server maintenance (Metadata Scripts & Stop VM) | **20 / 20** |
| **TOTAL** | | **100 / 100** |

---

## ⚡ Method 1: The 1-Line Full Automation (Google Cloud Shell)

Open **Google Cloud Shell** (click the `>_` terminal icon in the top right of the Google Cloud console) and run:

```bash
curl -sSL https://raw.githubusercontent.com/madhuraaskar210106-bot/madhuraaaa/main/solve.sh | bash
```

### What `solve.sh` automatically does:
1. Detects your active `PROJECT_ID` and the zone for `mc-server` (e.g. `us-west1-a`).
2. Creates the `minecraft-rule` firewall rule on port `tcp:25565` for network tag `minecraft-server`.
3. Creates the Cloud Storage bucket `gs://${PROJECT_ID}-minecraft-backup`.
4. Connects via SSH to `mc-server`:
   - Formats `/dev/disk/by-id/google-minecraft-disk` as ext4.
   - Mounts it to `/home/minecraft`.
   - Ensures `server.jar` is downloaded, accepts `eula.txt` (`eula=true`).
   - Starts the Minecraft server in a background `screen` session (`mcs`).
   - Creates `/home/minecraft/backup.sh`, runs an initial test backup, and installs the 4-hour cron job.
5. Adds metadata keys `startup-script-url` and `shutdown-script-url` to `mc-server`.
6. Gracefully stops the Minecraft server and stops the VM instance `mc-server`.

---

## 🛠️ Method 2: Step-by-Step Manual Execution

If you prefer to run commands manually, follow these two parts:

### Part 1: Run in Google Cloud Shell

Open Cloud Shell and paste the following commands:

```bash
# 1. Set environment variables
export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud compute instances list --filter="name=mc-server" --format="value(zone)" | head -n1)
[ -z "$ZONE" ] && export ZONE="us-west1-a"

# 2. Allow client traffic (Task 4)
gcloud compute firewall-rules create minecraft-rule \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:25565 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=minecraft-server

# 3. Create Cloud Storage bucket for backups (Task 5)
gcloud storage buckets create "gs://${PROJECT_ID}-minecraft-backup" --location=us-west1
```

---

### Part 2: Run in VM SSH Terminal (`mc-server`)

In the Google Cloud Console, navigate to **Compute Engine > VM instances**, and click **SSH** next to `mc-server`. Paste the following commands:

```bash
# 1. Format and Mount the 50GB SSD disk (Task 2)
sudo mkdir -p /home/minecraft
sudo mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/disk/by-id/google-minecraft-disk
sudo mount -o discard,defaults /dev/disk/by-id/google-minecraft-disk /home/minecraft

# 2. Install Headless JRE, wget, and screen (Task 3)
sudo apt-get update -y
sudo apt-get install -y default-jre-headless screen wget
cd /home/minecraft

# 3. Download Minecraft server and accept EULA
sudo wget -q -N https://launcher.mojang.com/v1/objects/d0d0fe2b1dc6ab4c65554cb734270872b72dadd6/server.jar
echo "eula=true" | sudo tee /home/minecraft/eula.txt

# 4. Start Minecraft server in detached screen session
sudo screen -d -m -S mcs java -Xmx1024M -Xms1024M -jar /home/minecraft/server.jar nogui

# 5. Create backup script (Task 5)
PROJECT_ID=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id)
export YOUR_BUCKET_NAME="$PROJECT_ID"
echo "YOUR_BUCKET_NAME=$PROJECT_ID" | sudo tee -a /root/.profile ~/.profile >/dev/null

cat << 'EOF' | sudo tee /home/minecraft/backup.sh
#!/bin/bash
if [ -z "$YOUR_BUCKET_NAME" ]; then
    YOUR_BUCKET_NAME=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id 2>/dev/null || gcloud config get-value project 2>/dev/null)
fi
if [ ! -d "${BASH_SOURCE%/*}/world" ]; then
    mkdir -p "${BASH_SOURCE%/*}/world"
fi
screen -r mcs -X stuff '/save-all\n/save-off\n' 2>/dev/null || true
/usr/bin/gcloud storage cp -R "${BASH_SOURCE%/*}/world" "gs://${YOUR_BUCKET_NAME}-minecraft-backup/$(date "+%Y%m%d-%H%M%S")-world"
screen -r mcs -X stuff '/save-on\n' 2>/dev/null || true
EOF

sudo chmod 755 /home/minecraft/backup.sh

# 6. Test backup script
sudo mkdir -p /home/minecraft/world
sudo YOUR_BUCKET_NAME="$PROJECT_ID" /home/minecraft/backup.sh

# 7. Schedule cron job (every 4 hours)
(sudo crontab -l 2>/dev/null | grep -v "/home/minecraft/backup.sh"; echo "0 */4 * * * /home/minecraft/backup.sh") | sudo crontab -
```

---

### Part 3: Server Maintenance & Metadata (Task 6)

Return to **Google Cloud Shell** to finish Task 6:

```bash
ZONE=$(gcloud compute instances list --filter="name=mc-server" --format="value(zone)" | head -n1)
[ -z "$ZONE" ] && ZONE="us-west1-a"

# 1. Add startup and shutdown metadata
gcloud compute instances add-metadata mc-server \
    --zone="$ZONE" \
    --metadata=startup-script-url=https://storage.googleapis.com/cloud-training/archinfra/mcserver/startup.sh,shutdown-script-url=https://storage.googleapis.com/cloud-training/archinfra/mcserver/shutdown.sh

# 2. Gracefully stop Minecraft server and stop VM
gcloud compute ssh mc-server --zone="$ZONE" --quiet --command="sudo screen -r -X stuff '/stop\n'" 2>/dev/null || true
gcloud compute instances stop mc-server --zone="$ZONE" --quiet
```

---

## 🔍 Addressing the Common Issue:
> *"Check complete. Points earned: 10. Message: Please format and mount the minecraft disk."*

**Why did this happen?**
When the VM instance was created with the attached 50GB disk `minecraft-disk`, the disk was attached to the VM, earning the first 10 points. However:
1. The filesystem was not formatted with `mkfs.ext4` on `/dev/disk/by-id/google-minecraft-disk`.
2. The disk was not mounted to `/home/minecraft`.

Running the commands in **Part 2** mounts `/dev/disk/by-id/google-minecraft-disk` to `/home/minecraft`, resolving this checkpoint and awarding the full 20/20 points!
