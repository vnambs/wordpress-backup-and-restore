#!/bin/bash

#
# Bash script for restoring backups of Wordpress.
#
# Version 1.0.2
#
# Usage:
#   - With backup directory specified in the script: ./WordpressRestore.sh <BackupName> (e.g. ./WordpressRestore.sh 20170910_132703)
#   - With backup directory specified by parameter: ./WordpressRestore.sh <BackupName> <BackupDirectory> (e.g. ./WordpressRestore.sh 20170910_132703 /media/hdd/wordpress_backup)
#

#
# IMPORTANT
# You have to customize this script (directories, users, etc.) for your actual environment.
# All entries which need to be customized are tagged with "TODO".
#

# Make sure the script exits when any command fails
set -Eeuo pipefail

# Variables
restore=${1:-} 
backupMainDir=${2:-} 

if [ -z "$backupMainDir" ]; then
	# TODO: The directory where you store the Wordpress backups (when not specified by args)
    backupMainDir='/media/hdd/wordpress_backup'
fi

echo "Backup directory: $backupMainDir"

currentRestoreDir="${backupMainDir}/${restore}"

# TODO: Set this to true, if the backup was created with compression enabled, otherwise false.
useCompression=true

# TOOD: The bare tar command for using compression.
# Use 'tar -xmpzf' if you want to use gzip compression.
compressionCommand="tar -I pigz -xmpf"

# TODO: The directory of your Wordpress installation (this is a directory under your web root)
wordpressFileDir='/var/www/wordpress'

# TODO: The service name of the web server. Used to start/stop web server (e.g. 'systemctl start <webserverServiceName>')
webserverServiceName='apache2'

# TODO: Your web server user
webserverUser='www-data'

# TODO: Your Wordpress database name
wordpressDatabase=$(grep DB_NAME /bitnami/wordpress/wp-config.php | awk -F\' '{print$4}')

# TODO: Your Wordpress database user
dbUser=$(grep DB_USER /bitnami/wordpress/wp-config.php | awk -F\' '{print$4}')

# TODO: The password of the Wordpress database user
dbPassword=$(grep DB_PASSWORD /bitnami/wordpress/wp-config.php | awk -F\' '{print$4}')

#TODO: you need to change the hostname
hostName='localhost'

# File name for backup file
# If you prefer other file names, you'll also have to change the WordpressBackup.sh script.
fileNameBackupFileDir='wordpress-filedir.tar'

if [ "$useCompression" = true ] ; then
	fileNameBackupFileDir='wordpress-filedir.tar.gz'
fi

# File name for database dump
fileNameBackupDb='wordpress-db.sql'

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

#
# Check if parameter(s) given
#
if [ $# != "1" ] && [ $# != "2" ]
then
    errorecho "ERROR: No backup name to restore given, or wrong number of parameters!"
    errorecho "Usage: WordpressRestore.sh 'BackupDate' ['BackupDirectory']"
    exit 1
fi

#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
    errorecho "ERROR: This script has to be run as root!"
    exit 1
fi

#
# Check if backup dir exists
#
if [ ! -d "${currentRestoreDir}" ]
then
	errorecho "ERROR: Backup ${restore} not found!"
    exit 1
fi

#
# Check if the commands for restoring the database are available
#
 if ! [ -x "$(command -v mysql)" ]; then
    errorecho "ERROR: MySQL/MariaDB not installed (command mysql not found)."
    errorecho "ERROR: No restore of database possible!"
    errorecho "Cancel restore"
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
# Delete old Wordpress directory
#

# File directory
echo "$(date +"%H:%M:%S"): Deleting old Wordpress file directory..."
rm -r "${wordpressFileDir}"
mkdir -p "${wordpressFileDir}"
echo "Done"
echo

#
# Restore file directory
#

# File directory
echo "$(date +"%H:%M:%S"): Restoring Wordpress file directory..."
if [ "$useCompression" = true ] ; then
    `$compressionCommand "${currentRestoreDir}/${fileNameBackupFileDir}" -C "${wordpressFileDir}"`
else
    tar -xmpf "${currentRestoreDir}/${fileNameBackupFileDir}" -C "${wordpressFileDir}"
fi
echo "Done"
echo

#
# Restore database
#
echo "$(date +"%H:%M:%S"): Dropping old Wordpress DB..."
 mysql -h "${hostName}" -u "${dbUser}" -p"${dbPassword}" -e "DROP DATABASE ${wordpressDatabase}"
echo "Done"
echo

echo "$(date +"%H:%M:%S"): Creating new DB for Wordpress..."
mysql -h "${hostName}" -u "${dbUser}" -p"${dbPassword}" -e "CREATE DATABASE ${wordpressDatabase}"
echo "Done"
echo

echo "$(date +"%H:%M:%S"): Restoring backup DB..."
mysql -h "${hostName}" -u "${dbUser}" -p"${dbPassword}" "${wordpressDatabase}" < "${currentRestoreDir}/${fileNameBackupDb}"
echo "Done"
echo

#
# Start web server
#
echo "$(date +"%H:%M:%S"): Starting web server..."
systemctl start "${webserverServiceName}"
echo "Done"
echo

#
# Set directory permissions
#
echo "$(date +"%H:%M:%S"): Setting directory permissions..."
chown -R "${webserverUser}":"${webserverUser}" "${wordpressFileDir}"
echo "Done"
echo

echo
echo "DONE!"
echo "$(date +"%H:%M:%S"): Backup ${restore} successfully restored."