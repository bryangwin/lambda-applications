#!/bin/bash

# Description: This script will take the nvidia-bug-report.log.gz file from the Downloads directory,
# take the users input for the support ticket number related to the report, 
# apend the ticket number to the file name and store it in the nvidia_bug_reports directory
# You can use -o when you run the script to open the file with Mark's check-nvidia-bug-report.sh script

# Author: Bryan Gwin
# Date: 28 Aug 2023

# Change your source and target directories here:
SOURCE_DIR=~/Downloads
TARGET_DIR=~/nvidia_bug_reports

# Flag to determine if it should open the file with the check-nvidia-bug-report.sh script
OPEN_REPORT=false

# Function to open the bug report. This assumes you have check-nvidia-bug-report.sh in your path
open_bug_report() {
    log_files=$(find "$TARGET_DIR" -type f -name "nvidia-bug-report-$1*.log" | sort -V)
    latest_log_file=$(echo "$log_files" | tail -n 1)
    if [ -n "$latest_log_file" ]; then
        cd "$TARGET_DIR" && check-nvidia-bug-report.sh "$latest_log_file"
    fi
}


while getopts "o" opt; do
    case $opt in
        o)
            OPEN_REPORT=true
            ;;
        \?)
            echo "Use -o if you'd like to open the file with the parsing script" >&2
            exit 
            ;;
    esac
done

# Check if the target directory exists, if not, create it
if [[ ! -d "$TARGET_DIR" ]]; then
    mkdir "$TARGET_DIR"
fi

# Identify latest nvidia-bug-report.log.gz file in the source directory
latest_file=$(ls "$SOURCE_DIR"/nvidia-bug-report*.log.gz 2> /dev/null | sort -V | tail -n 1)

if [[ -f "$latest_file" ]]; then
    # Prompt the user for the ticket number
    while true; do
        echo -n "Enter the ticket number: "
        read ticket_number

        # Check if the ticket number is a valid 5-digit number
        if [[ "$ticket_number" =~ ^[0-9]{5}$ ]]; then
            break
        else
            echo "Please enter a valid 5-digit ticket number."
        fi
    done

    target_file="$TARGET_DIR"/nvidia-bug-report-${ticket_number}.log.gz

    # Check if target file exists, if it does, append with a version
    version=1
    while [[ -f "$target_file" || -f "${target_file%.gz}" ]]; do
        target_file="$TARGET_DIR"/nvidia-bug-report-${ticket_number}-v${version}.log.gz
        version=$((version+1))
    done
    
    mv "$latest_file" "$target_file"

    gunzip "$target_file"

    # Apply -o option if user specified and open with check-nvidia-bug-report.sh
    if $OPEN_REPORT; then
        open_bug_report $ticket_number
    else
        echo "Success! $(basename "${target_file%.gz}") created in $TARGET_DIR"
    fi

else
    echo "Error: nvidia-bug-report.log.gz not found in $SOURCE_DIR"
fi

