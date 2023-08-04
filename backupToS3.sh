#!/bin/bash

#
# Bash script for creating backups of Wordpress.
#
# Version 1.0.0
#
# Usage:
# 	- With backup directory specified in the script:  ./backuptoS3.sh
# 	- With backup directory specified by parameter: ./backuptoS3.sh <backupDirectory> (e.g. ./backuptoS3.sh /media/hdd/wordpress_backup)
#

#
# IMPORTANT
# You have to customize this script (directories, users, etc.) for your actual environment.
# All entries which need to be customized are tagged with "TODO".
#

# Make sure the script exits when any command fails
set -Eeuo pipefail

# Variables
backupMainDir=${1:-} 

if [ -z "$backupMainDir" ]; then
    # TODO: The directory where you store the Wordpress backups (when not specified by args)
    backupMainDir='/bitnami/wordpress_backup'
fi

# TODO: Use compression for Wordpress installation dir
# When this is the only script for backups, it's recommend to enable compression.
# If the output of this script is used in another (compressing) backup (e.g. borg backup), 
# you should probably disable compression here and only enable compression of your main backup script.
useCompression=true

# TOOD: The bare tar command for using compression.
# Use 'tar -cpzf' if you want to use gzip compression.
compressionCommand="tar -cpzf"

echo "Backup directory: $backupMainDir"

currentDate=$(date +"%Y%m%d_%H%M%S")

# The actual directory of the current backup - this is a subdirectory of the main directory above with a timestamp
backupDir="${backupMainDir}/${currentDate}"

# TODO: The directory of your Wordpress installation (this is a directory under your web root)
wordpressFileDir='/bitnami/wordpress'

# TODO: The service name of the web server. Used to start/stop web server (e.g. 'systemctl start <webserverServiceName>')
webserverServiceName='apache2'

# TODO: Your Wordpress database name
wordpressDatabase=$(grep DB_NAME /bitnami/wordpress/wp-config.php | awk -F\' '{print$4}')

# TODO: Your Wordpress database user
dbUser=$(grep DB_USER /bitnami/wordpress/wp-config.php | awk -F\' '{print$4}')

# TODO: The password of the Wordpress database user
dbPassword=$(grep DB_PASSWORD /bitnami/wordpress/wp-config.php | awk -F\' '{print$4}')

# TODO: The maximum number of backups to keep (when set to 0, all backups are kept)
maxNrOfBackups=1
# TODO: bucket aws name
bucket_name='your bucket name'
# TODO: if you want to send the backup to S3 AWS
send_backup=true
#TODO: you need to change the hostname
hostName='localhost'

# File name for file backup
# If you prefer another file name, you'll also have to change the WordpressRestore.sh script.
fileNameBackupFileDir='wordpress-filedir.tar'

if [ "$useCompression" = true ] ; then
	fileNameBackupFileDir='wordpress-filedir.tar.gz'
fi

# File name for database dump
fileNameBackupDb='wordpress-db.sql'

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

# Capture CTRL+C
trap CtrlC INT

function CtrlC() {
	echo "Backup cancelled."
	exit 1
}

#send mail to your account

function send_email() {
    local subject="$1"
    local message="$2"
    #TODO: change mail recipients to yours
    local recipient="your_email@example.com"  

    echo -e "${message}" | mail -s "${subject}" "${recipient}"
}


#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
	errorecho "ERROR: This script has to be run as root!"
	exit 1
fi

#
# Check if backup dir already exists
#
if [ ! -d "${backupDir}" ]
then
	mkdir -p "${backupDir}"
else
	errorecho "ERROR: The backup directory ${backupDir} already exists!"
	exit 1
fi

#
# Stop web server
#
echo "$(date +"%H:%M:%S"): Stopping web server..."
systemctl stop "${webserverServiceName}"
echo "Done"
echo

#
# Backup file directory
#
echo "$(date +"%H:%M:%S"): Creating backup of Wordpress file directory..."
if [ "$useCompression" = true ] ; then
	`$compressionCommand "${backupDir}/${fileNameBackupFileDir}" -C "${wordpressFileDir}" .`
else
	tar -cpf "${backupDir}/${fileNameBackupFileDir}" -C "${wordpressFileDir}" .
fi
echo "Done"
echo
echo "upload file to AWS S3"
#send the backup offsite
if [ "$send_backup" = true ] ; then
    cmd="aws s3 cp $backupDir/$fileNameBackupFileDir s3://$bucket_name/$backupDir/ --only-show-errors"
    if $cmd ; then
        msg="Offsite backup successful."
        printf "\n%s\n\n" "$msg"
    else
        msg="Something went wrong while sending offsite backup."
        printf "\n%s\n\n" "$msg"
    fi
fi
#
# Backup DB
#
echo "$(date +"%H:%M:%S"): Backup Wordpress database..."

if ! [ -x "$(command -v mysqldump)" ]; then
    errorecho "ERROR: MySQL/MariaDB not installed (command mysqldump not found)."
    errorecho "ERROR: No backup of database possible!"
else
    mysqldump --single-transaction -h "${hostName}" -u "${dbUser}" -p"${dbPassword}" "${wordpressDatabase}" > "${backupDir}/${fileNameBackupDb}"
fi

echo "Done"
echo
echo "upload file to AWS S3"
#send the backup offsite
if [ "$send_backup" = true ] ; then
    cmd="aws s3 cp $backupDir/$fileNameBackupDb s3://$bucket_name/$backupDir/ --only-show-errors"
    if $cmd ; then
        msg="Offsite backup successful."
        printf "\n%s\n\n" "$msg"
    else
        msg="Something went wrong while sending offsite backup."
        printf "\n%s\n\n" "$msg"
    fi
fi


#
# Start web server
#
echo "$(date +"%H:%M:%S"): Starting web server..."
systemctl start "${webserverServiceName}"
echo "Done"
echo


#
# Delete old backups
#
if [ ${maxNrOfBackups} != 0 ]
then
	nrOfBackups=$(ls -l ${backupMainDir} | grep -c ^d)

	if [[ ${nrOfBackups} > ${maxNrOfBackups} ]]
	then
		echo "$(date +"%H:%M:%S"): Removing old backups..."
		ls -t ${backupMainDir} | tail -$(( nrOfBackups - maxNrOfBackups )) | while read -r dirToRemove; do
			echo "${dirToRemove}"
			rm -r "${backupMainDir}/${dirToRemove:?}"
			echo "Done"
			echo
		done
	fi
fi

echo
echo "DONE!"
echo "$(date +"%H:%M:%S"): Backup created: ${backupDir}"

#
# Send mail on success or failure
#
if [ "$send_backup" = true ] ; then
    if [ $? -eq 0 ]; then
        success_msg="Offsite backup successful.\nBackup directory: ${backupDir}"
        send_email "Backup Successful" "$success_msg"
    else
        error_msg="Something went wrong while sending offsite backup.\nBackup directory: ${backupDir}"
        send_email "Backup Failed" "$error_msg"
    fi
fi