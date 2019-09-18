#!/bin/bash

#variables

# Source directory for store tar and sql
ncServerTempDir="$HOME/"
# Main directory
BackupMainDir="$HOME/nextcloud_backup"
# Current date
DATE=`date +"%Y%m%d-%H%M%S"`
# Your web server user
webServerUser="www-data"
# The directory of your Nextcloud installation
ncServerDir="/usr/share/nginx/nextcloud/"
# The directory of your Nextcloud data
ncServerData="/usr/share/nginx/nextcloud-data/"
# Your Nextcloud database name
dbName="nextcloud"
# Your Nextcloud database user
dbUser="nextclouduser"
# The password of the Nextcloud database user
dbPass="your-password"
# Location of your Nextcloud data folder backup
ncDataFolderBackup="${BackupMainDir}/nc_data"
# Location of your Nextcloud database backup
ncDbFolderBackup="${BackupMainDir}/nc_db"
# Location of your Nextcloud installation folder backup
ncServerBackupDir="${BackupMainDir}/nc_server"
# Your Nextcloud server address
ncServer="root@192.168.15.68"

# Functions

EnableMaintenanceMode () {
    echo "Set maintenance mode for Nextcloud..."
    ssh ${ncServer} "sudo -u ${webServerUser} php ${ncServerDir}/occ maintenance:mode --on"
    echo "Done"
    echo
}
DisableMaintenanceMode () {
    echo "Switching off maintenance mode..."
    ssh ${ncServer} "sudo -u ${webServerUser} php ${ncServerDir}/occ maintenance:mode --off"
    echo "Done"
    echo
}
backup_server ()
{
    echo "Backing up webfolder"
    sleep 1
    if [[ ! -e ${ncServerBackupDir} ]]; then mkdir -p ${ncServerBackupDir}; fi
    ssh ${ncServer} "tar -cpzf ${ncServerTempDir}/nc_server_${DATE}.tar.gz -C ${ncServerDir} ."
    scp -p ${ncServer}:${ncServerTempDir}/nc_server_${DATE}.tar.gz ${ncServerBackupDir}/
    sleep 1
    ssh ${ncServer} "rm -f ${ncServerTempDir}/nc_server_${DATE}.tar.gz"
    echo "Backup webfolder is done"
    sleep 3
}

backup_data ()
{
    echo "Backing up data folder"
    sleep 3
    if [[ ! -e "${ncDataFolderBackup}/Latest" ]]; then
        mkdir -p ${ncDataFolderBackup}/Latest
    fi
    rsync -axv --delete --link-dest=${ncDataFolderBackup}/Latest ${ncServer}:${ncServerData} ${ncDataFolderBackup}/Processing-${DATE}
    sleep 1
    mv ${ncDataFolderBackup}/Processing-${DATE} ${ncDataFolderBackup}/${DATE} && \
    rm -rf ${ncDataFolderBackup}/Latest && ln -sr ${ncDataFolderBackup}/${DATE} ${ncDataFolderBackup}/Latest
    echo "Backup data folder is done"
    sleep 1
}

backup_db ()
{
    echo "Backing up database"
    sleep 1
    ssh ${ncServer} "if [[ ! -e ${ncServerTempDir} ]]; then mkdir -p ${ncServerTempDir}; fi"
    ssh ${ncServer} "mysqldump --single-transaction -h localhost -u${dbUser} -p${dbPass} ${dbName} > ${ncServerTempDir}/nc_db_${DATE}.sql"
    if [[ ! -e ${ncDbFolderBackup} ]]; 
        then mkdir -p ${ncDbFolderBackup};
    fi
    scp ${ncServer}:${ncServerTempDir}/nc_db_${DATE}.sql ${ncDbFolderBackup}/nc_db_${DATE}.sql
    echo "Backup database is done"
    sleep 1
    ssh ${ncServer} "rm -r ${ncServerTempDir}/nc_db_${DATE}.sql"
}

# Main
# Check for root
if [ "$(id -u)" != "0" ]
    then
    echo "ERROR: This script has to be run as root!" 1>&2
    exit 1
fi

EnableMaintenanceMode
backup_data
backup_server
backup_db
DisableMaintenanceMode
echo "All done"

