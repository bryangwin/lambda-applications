#!/bin/bash

# This script is intended to run on a Lambda machine and collects various system logs and information for diagnostic purposes.
# It includes the use of NVIDIA's bug report script to gather detailed information about NVIDIA GPU installations.
# Credit to NVIDIA Corporation for the nvidia-bug-report.sh script.
# Credit to Mark Dalton for collect_drive_checks.

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
    if ! command -v smartctl &> /dev/null; then
        echo "smartctl could not be found, attempting to install."
        sudo apt-get update && sudo apt-get install -y smartmontools
    fi

    DRIVES=$(lsblk | egrep "^sd|^nvm" | awk '{print $1}')

    mkdir -p check-drives
    lsblk -f > check-drives/lsblk.txt

    for DRIVE in ${DRIVES} ; do
        sudo smartctl -x /dev/${DRIVE} > check-drives/smartctl-${DRIVE}.txt 2>&1
    done

    tar -zcf check-drives.tgz check-drives
    # Expand check-drives.tgz into the FINAL_DIR directory
    tar -xzf check-drives.tgz -C "$FINAL_DIR"
}

# Generate NVIDIA bug report
sudo nvidia-bug-report.sh

# If nvidia-bug-report.log.gz exists, decompress it
if [ -f "nvidia-bug-report.log.gz" ]; then
    gunzip -c nvidia-bug-report.log.gz > "${FINAL_DIR}/nvidia-bug-report.log"
fi

# Generate system logs archive
tar -zcf system_logs.tgz $(ls /var/log/dmesg /var/log/kern.log /var/log/syslog /var/log/apt/history.log)
# Expand system_logs.tgz into the FINAL_DIR directory
tar -xzf system_logs.tgz -C "$FINAL_DIR"

# Collect other logs
sudo dmesg -Tl err > "${FINAL_DIR}/dmesg_errors.txt"
journalctl > "${FINAL_DIR}/journalctl.txt"

# Check for ibstat and install if not present
if ! command -v ibstat &> /dev/null; then
    echo "ibstat could not be found, attempting to install."
    sudo apt-get update && sudo apt-get install -y infiniband-diags
fi
ibstat > "${FINAL_DIR}/ibstat.txt"

# Check for ipmitool and install if not present
if ! command -v ipmitool &> /dev/null; then
    echo "ipmitool could not be found, attempting to install."
    sudo apt-get update && sudo apt-get install -y ipmitool
fi
sudo ipmitool sel elist > "${FINAL_DIR}/elist.txt"
sudo ipmitool sdr > "${FINAL_DIR}/sdr.txt"

# Collect other system information
df -hTP > "${FINAL_DIR}/df.txt"
cat /etc/fstab > "${FINAL_DIR}/fstab.txt"
cat /etc/default/grub > "${FINAL_DIR}/grub.txt"
lsmod > "${FINAL_DIR}/modules.txt"
dpkg -l > "${FINAL_DIR}/dpkg.txt"
pip -v list > "${FINAL_DIR}/pip_list.txt"
lshw > "${FINAL_DIR}/hw_list.txt"
ls /etc/apt/sources.list.d > "${FINAL_DIR}/listd_repos.txt"
grep -v '^#' /etc/apt/sources.list > "${FINAL_DIR}/sources_list.txt"

collect_drive_checks

# Compress all collected logs into a single file
tar -zcvf lambda-bug-report.tar.gz -C "$TMP_DIR" lambda-bug-report

# Cleanup
rm -rf "$TMP_DIR"

echo "All logs have been collected and compressed into lambda-bug-report.tar.gz."
