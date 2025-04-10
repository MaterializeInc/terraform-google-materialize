#!/bin/bash
set -xeuo pipefail

echo "Starting GCP NVMe SSD setup"

# Install required tools
if command -v apt-get >/dev/null 2>&1; then
  apt-get update
  apt-get install -y lvm2=2.03.11-2.1
elif command -v yum >/dev/null 2>&1; then
  yum install -y lvm2-2.03.11-5.el9
else
  echo "No package manager found. Please install required tools manually."
  exit 1
fi

# Find NVMe devices
SSD_DEVICE_LIST=()

# Try the standard GCP pattern first
devices=$(find /dev/disk/by-id/ -name "google-local-nvme-ssd-*" 2>/dev/null || true)
if [ -n "$devices" ]; then
  while read -r device; do
    SSD_DEVICE_LIST+=("$device")
  done <<<"$devices"
fi

# If no devices found via standard pattern, look for NVMe devices directly
if [ ${#SSD_DEVICE_LIST[@]} -eq 0 ]; then
  echo "No Local NVMe SSD devices found via standard pattern. Checking direct NVMe devices..."

  for device in /dev/nvme*n*; do
    # Skip if not a block device or if it's a partition
    if [[ -b "$device" && ! "$device" =~ "p"[0-9]+ ]]; then
      # Check if size is approximately 375GB
      size_bytes=$(blockdev --getsize64 $device 2>/dev/null || echo 0)
      # 375GB = approximately 402653184000 bytes
      if ((size_bytes > 400000000000 && size_bytes < 405000000000)); then
        echo "Found potential NVMe local SSD: $device ($((size_bytes / (1024 * 1024 * 1024))) GB)"
        SSD_DEVICE_LIST+=("$device")
      fi
    fi
  done
fi

echo "Found ${#SSD_DEVICE_LIST[@]} NVMe SSD devices: ${SSD_DEVICE_LIST[*]:-none}"

if [ ${#SSD_DEVICE_LIST[@]} -eq 0 ]; then
  echo "No usable NVMe SSD devices found"
  exit 0
fi

# Check if any of the devices are already in use by LVM
for device in "${SSD_DEVICE_LIST[@]}"; do
  if pvdisplay "$device" &>/dev/null; then
    echo "$device is already part of LVM, skipping setup"
    exit 0
  fi
done

# Create physical volumes
for device in "${SSD_DEVICE_LIST[@]}"; do
  echo "Creating physical volume on $device"
  pvcreate -f "$device"
done

# Create volume group named 'instance-store-vg'
echo "Creating volume group instance-store-vg"
vgcreate instance-store-vg "${SSD_DEVICE_LIST[@]}"

# Create a logical volume using 100% of the space
echo "Creating logical volume local-nvme-lv"
lvcreate -l 100%FREE -n local-nvme-lv instance-store-vg

# Format the logical volume
echo "Formatting logical volume with ext4"
mkfs.ext4 -F /dev/instance-store-vg/local-nvme-lv

# Mount the logical volume
mkdir -p /var/openebs || true
echo "Mounting logical volume to /var/openebs"
if ! grep -q "/dev/instance-store-vg/local-nvme-lv" /etc/fstab; then
  echo "/dev/instance-store-vg/local-nvme-lv /var/openebs ext4 discard,defaults,nofail 0 2" >>/etc/fstab
fi

if ! mount | grep -q "/var/openebs"; then
  mount /var/openebs
fi

# Display results
echo "LVM setup completed:"
pvs
vgs
lvs
df -h /var/openebs

echo "NVMe SSD setup completed successfully"
echo "OpenEBS can use: /var/openebs"
