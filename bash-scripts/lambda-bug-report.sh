#!/bin/bash

# This script is intended to run on a Lambda machine and collects various system logs and information for diagnostic purposes.
# It includes the use of NVIDIA's bug report script to gather detailed information about NVIDIA GPUs and other system info.
# Credit to NVIDIA Corporation for the nvidia-bug-report.sh script.
# Note: This script consolidates system information, which may include sensitive data. User discretion advised.

# Copyright 2024 Lambda, Inc.
# Website:		https://lambdalabs.com
# Author(s):		Bryan Gwin
# Script License:	BSD 3-clause

# Script info and dislaimer
echo "This script is intended to run on a Lambda machine and collects various system logs and information for diagnostic purposes.
It includes the use of NVIDIA's bug report script to gather detailed information about NVIDIA GPUs and other system info.
Credit to NVIDIA Corporation for the nvidia-bug-report.sh script."
echo
echo "By delivering 'lambda-bug-report.log.gz' to Lambda, you acknowledge
and agree that sensitive information may inadvertently be included in
the output. Notwithstanding the foregoing, Lambda will use the
output only for the purpose of investigating your reported issue."
echo

# Define and create temporary directory
TMP_DIR="tmp_lambda_bug_report"
mkdir -p "$TMP_DIR"

# Define and create main directory for logs
FINAL_DIR="$TMP_DIR/lambda-bug-report"
mkdir -p "$FINAL_DIR"

# Directories under lambda-bug-report
DRIVES_AND_STORAGE_DIR="$FINAL_DIR/drives-and-storage"
mkdir -p "$DRIVES_AND_STORAGE_DIR"
SYSTEM_LOGS_DIR="$FINAL_DIR/system-logs"
mkdir -p "$SYSTEM_LOGS_DIR"
REPOS_AND_PACKAGES_DIR="$FINAL_DIR/repos-and-packages"
mkdir -p "$REPOS_AND_PACKAGES_DIR"
NETWORKING_DIR="$FINAL_DIR/networking"
mkdir -p "$NETWORKING_DIR"
GPU_MEMORY_ERRORS_DIR="$FINAL_DIR/gpu-memory-errors"
mkdir -p "$GPU_MEMORY_ERRORS_DIR"
BMC_INFO_DIR="$FINAL_DIR/bmc-info"
mkdir -p "$BMC_INFO_DIR"

collect_drive_checks() {
    # Ensure smartmontools is installed for smartctl
    if ! command -v smartctl >/dev/null 2>&1; then
        echo "smartctl could not be found, attempting to install."
        sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y smartmontools >/dev/null 2>&1
    fi

    lsblk -f >"$DRIVES_AND_STORAGE_DIR/lsblk.txt"

    # Collect SMART data for all drives
    DRIVES=$(lsblk | egrep "^sd|^nvm" | awk '{print $1}')
    for DRIVE in ${DRIVES}; do
        sudo smartctl -x /dev/"${DRIVE}" >"$DRIVES_AND_STORAGE_DIR/smartctl-${DRIVE}.txt" 2>&1
    done
}


# Generate NVIDIA bug report
echo "Running nvidia-bug-report.sh..."
sudo nvidia-bug-report.sh >/dev/null 2>&1

# If nvidia-bug-report.log.gz exists, decompress it
if [ -f "nvidia-bug-report.log.gz" ]; then
    gunzip -c nvidia-bug-report.log.gz >"${FINAL_DIR}/nvidia-bug-report.log"
fi

echo "Collecting system logs and information..."

# Collect system logs
for log in /var/log/dmesg /var/log/kern.log /var/log/syslog /var/log/apt/history.log; do
    if [ -f "$log" ]; then
        cp "$log" "$SYSTEM_LOGS_DIR/"
    fi
done

# Collect other logs
sudo dmesg -Tl err >"${SYSTEM_LOGS_DIR}/dmesg-errors.txt"
journalctl >"${SYSTEM_LOGS_DIR}/journalctl.txt"

# Check for ibstat and install if not present
if ! command -v ibstat >/dev/null 2>&1; then
    echo "ibstat could not be found, attempting to install."
    sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y infiniband-diags >/dev/null 2>&1
fi
ibstat >"${FINAL_DIR}/ibstat.txt"
if [ ! -s "${FINAL_DIR}/ibstat.txt" ]; then
    echo "No InfiniBand data available. This machine may not have InfiniBand." >"${FINAL_DIR}/ibstat.txt"
fi

# Check for ipmitool and install if not present
if ! command -v ipmitool >/dev/null 2>&1; then
    echo "ipmitool could not be found, attempting to install."
    sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y ipmitool >/dev/null 2>&1
fi
sudo ipmitool sel elist >"${BMC_INFO_DIR}/ipmi-elist.txt" 2>/dev/null
if [ ! -s "${BMC_INFO_DIR}/ipmi-elist.txt" ]; then
    echo "No IPMI ELIST data available. This machine may not have IPMI." >"${BMC_INFO_DIR}/ipmi-elist.txt"
fi
sudo ipmitool sdr >"${BMC_INFO_DIR}/ipmi-sdr.txt" 2>/dev/null
if [ ! -s "${BMC_INFO_DIR}/ipmi-sdr.txt" ]; then
    echo "No IPMI SDR data available. This machine may not have IPMI." >"${BMC_INFO_DIR}/ipmi-sdr.txt"
fi

# Check for sensors and install if not present
if ! command -v sensors >/dev/null 2>&1; then
    echo "sensors could not be found, attempting to install."
    sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y lm-sensors >/dev/null 2>&1
fi
sensors >"${FINAL_DIR}/sensors.txt"

# Check for iostat and install if not present
if ! command -v iostat >/dev/null 2>&1; then
    echo "iostat could not be found, attempting to install."
    sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y sysstat >/dev/null 2>&1
fi
sudo iostat -xt >"${DRIVES_AND_STORAGE_DIR}/iostat.txt"

# Check for lshw and install if not present
if ! command -v lshw >/dev/null 2>&1; then
    echo "lshw could not be found, attempting to install."
    sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y lshw >/dev/null 2>&1
fi
sudo lshw >"${FINAL_DIR}/hw-list.txt"

# Check for memory remapping and memory errors on GPUs
nvidia-smi --query-remapped-rows=gpu_bus_id,gpu_uuid,remapped_rows.correctable,remapped_rows.uncorrectable,remapped_rows.pending,remapped_rows.failure \
    --format=csv >"${GPU_MEMORY_ERRORS_DIR}/remapped-memory.txt"

nvidia-smi --query-gpu=index,pci.bus_id,uuid,ecc.errors.corrected.volatile.dram,ecc.errors.corrected.volatile.sram \
    --format=csv >"${GPU_MEMORY_ERRORS_DIR}/ecc-errors.txt"

nvidia-smi --query-gpu=index,pci.bus_id,uuid,ecc.errors.uncorrected.aggregate.dram,ecc.errors.uncorrected.aggregate.sram \
    --format=csv >"${GPU_MEMORY_ERRORS_DIR}/uncorrected-ecc_errors.txt"

# Check hibernation settings
sudo systemctl status hibernate.target hybrid-sleep.target \
    suspend-then-hibernate.target sleep.target suspend.target >"${FINAL_DIR}/hibernation-settings.txt"

# Collect other system information
df -hTP >"${DRIVES_AND_STORAGE_DIR}/df.txt"
cat /etc/fstab >"${DRIVES_AND_STORAGE_DIR}/fstab.txt"
cat /etc/default/grub >"${FINAL_DIR}/grub.txt"
lsmod >"${FINAL_DIR}/lsmod.txt"
dpkg -l >"${REPOS_AND_PACKAGES_DIR}/dpkg.txt"
pip -v list >"${REPOS_AND_PACKAGES_DIR}/pip-list.txt"
ls /etc/apt/sources.list.d >"${REPOS_AND_PACKAGES_DIR}/listd-repos.txt"
grep -v '^#' /etc/apt/sources.list >"${REPOS_AND_PACKAGES_DIR}/sources-list.txt"
cat /proc/mounts >"${DRIVES_AND_STORAGE_DIR}/mounts.txt"
sudo sysctl -a >"${FINAL_DIR}/sysctl-all.txt"
systemctl --type=service >"${FINAL_DIR}/systemctl-services.txt"
sudo netplan get all >"${NETWORKING_DIR}/netplan.txt" 2>/dev/null
ip addr >"${NETWORKING_DIR}/ip-addr.txt"
top -n 1 -b >"${FINAL_DIR}/top.txt"

collect_drive_checks

# Compress all collected logs into a single file
tar -zcf lambda-bug-report.tar.gz -C "$TMP_DIR" lambda-bug-report

# Cleanup
rm -rf "$TMP_DIR"

echo
echo "All logs have been collected and compressed into lambda-bug-report.tar.gz."
echo