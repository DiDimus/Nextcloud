#!/bin/bash


# Variables
RestoreDate=$1
BackupMainDir=$2

if [ -z ${BackupMainDir} ]; then
	# The directory where you store the Nextcloud backups (when not specified by args)
    BackupMainDir="$HOME/nextcloud_backup/"
fi

# The directory of your Nextcloud installation
ncServerDir="/usr/share/nginx/nextcloud"

# The directory of your Nextcloud data directory (outside the Nextcloud file directory)
# If your data directory is located under Nextcloud's file directory (somewhere in the web root), the data directory should not be restored separately
ncServerData="/usr/share/nginx/nextcloud-data/"

# Your web server user
webServerUser="www-data"

# Your Nextcloud database name
dbName="nextcloud"

# Your Nextcloud database user
dbUser="nextclouduser"

# The password of the Nextcloud database user
dbPass="your-password"

# Your Nextcloud server address
ncServer="root@192.168.15.68"

# Web Server name (nginx, apache etc.)
WebServerServiceName="nginx"
# File names for backup files
# If you prefer other file names, you'll also have to change the NextcloudBackup.sh script.
dirNameBackupServer="${BackupMainDir}/nc_server/"
dirNameBackupData="${BackupMainDir}/nc_data/"
dirNameBackupDb="${BackupMainDir}/nc_db/"
fileNameBackupServer="nc_server_${RestoreDate}.tar.gz"
fileNameBackupDataDir="${RestoreDate}/"
fileNameBackupDb="nc_db_${RestoreDate}.sql"

#
# Check if parameter(s) given
#
if [ $# != "1" ] && [ $# != "2" ]
then
    echo "ERROR: No backup name to restore given, or wrong number of parameters!"
    echo "Usage: NextcloudRestore.sh 'BackupDate' ['BackupDirectory']"
    exit 1
fi

#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
    echo "ERROR: This script has to be run as root!"
    exit 1
fi

#
# Check if backup dir exists
#
check_exists() {
if [[ ! -e "${dirNameBackupServer}/${fileNameBackupServer}" || 
! -e ${dirNameBackupData}/${fileNameBackupDataDir} || 
! -e ${dirNameBackupDb}/${fileNameBackupDb} ]]
then
	echo "ERROR: Backup ${RestoreDate} not found!"
    exit 1
fi
}

enableMaintenanceMode () {
    echo "Set maintenance mode for Nextcloud..."
    ssh ${ncServer} "sudo -u ${webServerUser} php ${ncServerDir}/occ maintenance:mode --on"
    echo "Done"
    echo
}

disableMaintenanceMode () {
    echo "Switching off maintenance mode..."
    ssh ${ncServer} "sudo -u ${webServerUser} php ${ncServerDir}/occ maintenance:mode --off"
    echo "Done"
    echo
}

#
# Delete old Nextcloud directories
#
delete_server() {
# File directory
echo "Deleting old Nextcloud file directory..."
ssh ${ncServer} "rm -r ${ncServerDir}"
ssh ${ncServer} "mkdir -p ${ncServerDir}"
echo "Done"
echo
}

delete_data() {
# Data directory
echo "Deleting old Nextcloud data directory..."
ssh ${ncServer} "rm -r ${ncServerData}"
ssh ${ncServer} "mkdir -p ${ncServerData}"
echo "Done"
echo
}

delete_database() {
echo "Dropping old Nextcloud DB..."
ssh ${ncServer} "mysql -h localhost -u ${dbUser} -p${dbPass} -e \"DROP DATABASE ${dbName}\""
echo "Done"
echo
}

#
# Restore file and data directory
#
restore_server() {
# File directory
echo "Restoring Nextcloud server directory..."
scp -p ${dirNameBackupServer}/${fileNameBackupServer} ${ncServer}:$HOME/
ssh ${ncServer} "tar -xpzf $HOME/${fileNameBackupServer} -C ${ncServerDir}; sleep 1; rm -rf $HOME/${fileNameBackupServer}"
echo "Done"
echo
}

restore_data() {
# Data directory
echo "Restoring Nextcloud data directory..."
rsync -axv ${dirNameBackupData}/${fileNameBackupDataDir} ${ncServer}:${ncServerData} 
echo "Done"
echo
}

restore_database() {
echo "Creating new DB for Nextcloud..."
scp ${dirNameBackupDb}/${fileNameBackupDb} ${ncServer}:$HOME/
# Use this if the database from the backup uses UTF8 with multibyte support (e.g. for emoijs in filenames):
#ssh ${ncServer} "mysql -h localhost -u ${dbUser} -p${dbPass} -e \"CREATE DATABASE ${dbName} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci\""
# Use this if the database from the backup DOES NOT use UTF8 with multibyte support (e.g. for emoijs in filenames):
ssh ${ncServer} "mysql -h localhost -u ${dbUser} -p${dbPass} -e \"CREATE DATABASE ${dbName}\""
echo "Done"
echo
echo "Restoring backup DB..."
ssh ${ncServer} "mysql -h localhost -u ${dbUser} -p${dbPass} ${dbName} < $HOME/${fileNameBackupDb}"
echo "Done"
echo
}


#
# Stop web server
#
stop_web_server() {
echo "Stoping web server..."
ssh ${ncServer} "systemctl stop ${WebServerServiceName}"
echo "Done"
echo
}

#
# Start web server
#
start_web_server() {
echo "Starting web server..."
ssh ${ncServer} "systemctl start ${WebServerServiceName}"
echo "Done"
echo
}


#
# Update the system data-fingerprint (see https://docs.nextcloud.com/server/16/admin_manual/configuration_server/occ_command.html#maintenance-commands-label)
#
update_fingerprint() {
echo "Updating the system data-fingerprint..."
ssh ${ncServer} "sudo -u ${webServerUser} php ${ncServerDir}/occ maintenance:data-fingerprint"
echo "Done"
echo
}

# Main
check_exists
enableMaintenanceMode
stop_web_server
delete_server
delete_data
delete_database
restore_server
restore_data
restore_database
start_web_server
update_fingerprint
disableMaintenanceMode


echo
echo "DONE!"
echo "Backup ${RestoreDate} successfully restored."
