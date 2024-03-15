Lambda-Applications
A collection of applications, scripts and tools geared towardds Lambda Labs employees but useful for everyone. 

#### `lambda-bug-report.sh`
This script is intended to run on a Lambda machine and collects various system logs and information for diagnostic purposes.
It includes the use of NVIDIA's bug report script to gather detailed information about NVIDIA GPUs and other system info.
Note: This script consolidates system information, which may include sensitive data. User discretion advised.


`store_nvidia_report.sh`
Description: This script will take the nvidia-bug-report.log.gz file from the Downloads directory,
take the users input for the support ticket number related to the report, 
append the ticket number to the file name and store it in the nvidia_bug_reports directory
You can use -o when you run the script to open the file with Mark's check-nvidia-bug-report.sh script
