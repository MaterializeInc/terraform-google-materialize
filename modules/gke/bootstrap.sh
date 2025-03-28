#!/bin/bash
set -xeuo pipefail

echo "Starting Local SSD disk setup for GCP"

# Install required tools
apt-get update
apt-get install -y lvm2

# Get the list of local SSD devices
# In GCP, local SSDs are typically mounted at /dev/disk/by-id/google-local-ssd-*
mapfile -t SSD_DEVICE_LIST < <(ls -1 /dev/disk/by-id/google-local-ssd-* || true)

echo "Found local SSD devices: ${SSD_DEVICE_LIST[*]:-none}"

if [ ${#SSD_DEVICE_LIST[@]} -eq 0 ]; then
  echo "No usable local SSD devices found"
  exit 0
fi

# Create physical volumes
for device in "${SSD_DEVICE_LIST[@]}"; do
  pvcreate -f "$device"
done

# Create volume group
vgcreate instance-store-vg "${SSD_DEVICE_LIST[@]}"

# Display results
pvs
vgs

echo "Disk setup completed"
