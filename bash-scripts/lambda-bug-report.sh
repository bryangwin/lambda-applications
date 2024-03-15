#!/bin/bash

# This script is intended to run on a Lambda machine and collects various system logs and information for diagnostic purposes.
# It includes the use of NVIDIA's bug report script to gather detailed information about NVIDIA GPUs and other system info.
# Credit to NVIDIA Corporation for the nvidia-bug-report.sh script.

# Author: Bryan Gwin
# Date: 2024-03-13
# Version: 1.0

# Define temporary directory for processing
TMP_DIR="tmp_lambda_bug_report"
mkdir -p "$TMP_DIR"
FINAL_DIR="$TMP_DIR/lambda-bug-report"
mkdir -p "$FINAL_DIR"

collect_drive_checks() {
    # Ensure smartmontools is installed for smartctl
    if ! command -v smartctl &>/dev/null; then
        echo "smartctl could not be found, attempting to install."
        sudo apt-get update && sudo apt-get install -y smartmontools
    fi

    # Create Directory for Drive Checks
    DRIVE_CHECKS_DIR="$FINAL_DIR/check-drives"
    mkdir -p "$DRIVE_CHECKS_DIR"

    lsblk -f >"$DRIVE_CHECKS_DIR/lsblk.txt"

    DRIVES=$(lsblk | egrep "^sd|^nvm" | awk '{print $1}')
    for DRIVE in ${DRIVES}; do
        sudo smartctl -x /dev/"${DRIVE}" >"$DRIVE_CHECKS_DIR/smartctl-${DRIVE}.txt" 2>&1
    done
}

# Generate NVIDIA bug report
sudo nvidia-bug-report.sh

# If nvidia-bug-report.log.gz exists, decompress it
if [ -f "nvidia-bug-report.log.gz" ]; then
    gunzip -c nvidia-bug-report.log.gz >"${FINAL_DIR}/nvidia-bug-report.log"
fi

# Collect system logs
SYSTEM_LOGS_DIR="$FINAL_DIR/system_logs"
mkdir -p "$SYSTEM_LOGS_DIR"

for log in /var/log/dmesg /var/log/kern.log /var/log/syslog /var/log/apt/history.log; do
    if [ -f "$log" ]; then
        cp "$log" "$SYSTEM_LOGS_DIR/"
    fi
done

# Collect other logs
sudo dmesg -Tl err >"${FINAL_DIR}/dmesg_errors.txt"
journalctl >"${FINAL_DIR}/journalctl.txt"

# Check for ibstat and install if not present
if ! command -v ibstat &>/dev/null; then
    echo "ibstat could not be found, attempting to install."
    sudo apt-get update && sudo apt-get install -y infiniband-diags
fi
ibstat >"${FINAL_DIR}/ibstat.txt"

# Check for ipmitool and install if not present
if ! command -v ipmitool &>/dev/null; then
    echo "ipmitool could not be found, attempting to install."
    sudo apt-get update && sudo apt-get install -y ipmitool
fi
sudo ipmitool sel elist >"${FINAL_DIR}/elist.txt"
sudo ipmitool sdr >"${FINAL_DIR}/sdr.txt"

# Chech for sensors and install if not present
if ! command -v sensors &>/dev/null; then
    echo "sensors could not be found, attempting to install."
    sudo apt-get update && sudo apt-get install -y lm-sensors
fi
sensors >"${FINAL_DIR}/sensors.txt"

# Check for iostat and install if not present
if ! command -v iostat &>/dev/null; then
    echo "iostat could not be found, attempting to install."
    sudo apt-get update && sudo apt-get install -y sysstat
fi
sudo iostat -xt >"${FINAL_DIR}/iostat.txt"

# Check for memory remapping and memory errors on GPUs
nvidia-smi --query-remapped-rows=gpu_bus_id,gpu_uuid,remapped_rows.correctable,remapped_rows.uncorrectable,remapped_rows.pending,remapped_rows.failure --format=csv >"${FINAL_DIR}/remapped_memory.txt"
nvidia-smi --query-gpu=index,pci.bus_id,uuid,ecc.errors.corrected.volatile.dram,ecc.errors.corrected.volatile.sram --format=csv >"${FINAL_DIR}/ecc_errors.txt"
nvidia-smi --query-gpu=index,pci.bus_id,uuid,ecc.errors.uncorrected.aggregate.dram,ecc.errors.uncorrected.aggregate.sram --format=csv >"${FINAL_DIR}/uncorrected_ecc_errors.txt"

# Collect other system information
df -hTP >"${FINAL_DIR}/df.txt"
cat /etc/fstab >"${FINAL_DIR}/fstab.txt"
cat /etc/default/grub >"${FINAL_DIR}/grub.txt"
lsmod >"${FINAL_DIR}/modules.txt"
dpkg -l >"${FINAL_DIR}/dpkg.txt"
pip -v list >"${FINAL_DIR}/pip_list.txt"
lshw >"${FINAL_DIR}/hw_list.txt"
ls /etc/apt/sources.list.d >"${FINAL_DIR}/listd_repos.txt"
grep -v '^#' /etc/apt/sources.list >"${FINAL_DIR}/sources_list.txt"
cat /proc/mounts >"${FINAL_DIR}/mounts.txt"
sysctl -a >"${FINAL_DIR}/sysctl.txt"
systemctl --type=service >"${FINAL_DIR}/services.txt"
sudo netplan get all >"${FINAL_DIR}/netplan.txt"
ip addr >"${FINAL_DIR}/ip_addr.txt"
top -n 1 -b >"${FINAL_DIR}/top.txt"

collect_drive_checks

# Compress all collected logs into a single file
tar -zcvf lambda-bug-report.tar.gz -C "$TMP_DIR" lambda-bug-report

# Cleanup
rm -rf "$TMP_DIR"

echo "All logs have been collected and compressed into lambda-bug-report.tar.gz."
