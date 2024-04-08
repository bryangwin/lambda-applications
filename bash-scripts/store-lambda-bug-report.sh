#!/bin/bash

# Description: This script will find the lambda-bug-report.tar.gz file
# from the SOURCE_DIR directory, prompt the user for a ticket number,
# extract the file into TARGET_DIR directory with the ticket number and current date/time.

# You can use -o when you run the script to open the file with Mark's check-nvidia-bug-report.sh script.
# NOTE: This assumes the check-nvidia-bug-report.sh script is in your path.

# Author: Bryan Gwin
# Date: April 2023

# Set your source and target directories:
SOURCE_DIR=~/Downloads
TARGET_DIR=~/lambda-bug-reports

# Flag for opening the report
OPEN_REPORT=false

# Function to open the bug report with check-nvidia-bug-report.sh
open_bug_report() {
    # Find the latest directory matching the ticket number
    latest_log_dir=$(ls "$TARGET_DIR" | grep "lambda-bug-report-$1" | sort -V | tail -n 1)
    if [[ -n "$latest_log_dir" ]]; then
        if command -v check-nvidia-bug-report.sh &>/dev/null; then
            (cd "$TARGET_DIR/$latest_log_dir" && check-nvidia-bug-report.sh nvidia-bug-report.log)
        else
            echo "check-nvidia-bug-report.sh not found in your path."
            return
        fi
    else
        echo "No matching log directory found."
    fi
}

# Process flags
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

# Ensure the target directory exists
mkdir -p "$TARGET_DIR"

# Find the latest lambda-bug-report.tar.gz in the source directory
latest_file=$(ls "$SOURCE_DIR"/lambda-bug-report*.tar.gz | sort -V | tail -n 1)

if [[ ! -f "$latest_file" ]]; then
    echo "Error: lambda-bug-report.tar.gz not found in $SOURCE_DIR"
    exit 1
fi

# Prompt for the ticket number
while true; do
    echo -n "Enter the ticket number: "
    read -r ticket_number

    if [[ "$ticket_number" =~ ^[0-9]{5}$ ]]; then
        break
    else
        echo "Please enter a valid 5-digit ticket number."
    fi
done

# Add version number to the directory name
version=1
highest_version=$(find "$TARGET_DIR" -type d -name "lambda-bug-report-${ticket_number}v*-*-*-*-*:*" |
    awk -F'v|-' '{print $(NF-4)}' |
    sort -nr |
    head -n1)

if [[ -n "$highest_version" && "$highest_version" -gt 0 ]]; then
    version=$((highest_version + 1))
fi

# Prepare the directory name with the ticket number, including its version, and the current datetime
ticket_number_with_version="${ticket_number}v${version}"
current_datetime=$(date +"%Y-%m-%d-%H:%M")
dir_name="lambda-bug-report-${ticket_number_with_version}-${current_datetime}"

# Extract the tar.gz file into the target directory with the correct name
tar -xf "$latest_file" -C "$TARGET_DIR"
mv "$TARGET_DIR/lambda-bug-report" "$TARGET_DIR/$dir_name"

# Open the report if requested
if $OPEN_REPORT; then
    open_bug_report "$ticket_number"
else
    echo "Success! Report stored in $TARGET_DIR/$dir_name"
fi
