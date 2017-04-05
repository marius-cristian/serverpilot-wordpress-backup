#!/bin/bash 
#bash script that will create backups for skywalkrs digital ocean serverpilot stack on users-databases/ users-wordpress/
#cron can be set daily, weekly, monthly
#connects to vultr; checks subfolder path and clears
#written by cm@skywalkr.io
#
#Note: to be registered as root privilege
#Designed to be a cronjob
#needs to rsync without promptin a password therefore add ssh keys on host and remote
#https://blogs.oracle.com/jkini/entry/how_to_scp_scp_and

#variables for sql dump
FILENAME="`date +mysqldump-%Y-%m-%d-%H:%M:%S`.sql"
LOCALFILE="/mysqlbackup/$FILENAME"
LOCKFILE="/tmp/sqlbackup.lock"

#LOGFILE
LOGFILE="/logs/`date +backuplog-%Y-%m-%d-%H:%M:%S`.log"

#hardcoded remote ip
remote=10.10.10.10

#get current hostname
servername=$HOSTNAME
backuppath=/backups/servername/latest

#hardcoded path of users directory
userdir=/srv/users
echo "Log started: remote:$remote; host:$servername; backuppath:$backuppath" > $LOGFILE
#iterate through users
for username in $(ls "$userdir"); do
	apps="$userdir/$username/apps"
	echo "First Level loop: $username"
	#iterate through apps
	#checks if apps folder exists
	if [ -d "$apps" ]; then
		echo "$apps exists">>$LOGFILE
		for appname in $(ls "$apps/"); do
			echo "second level loop $appname"
			spath="$apps/$appname/public"
			echo "$spath"
			#checks if app has appropriate folder
			if [ -d "$spath" ]; then
				echo "Before 3rd level loop"
				if [ -d "$spath/wp-content" ]; then
					wpcontent="$spath/wp-content"
					htacces="$spath/.htaccess"
					wpconfig="$spath/wp-config.php"
					version="$spath/wp-includes/version.php"
					#take database name, user, password, local db or not
					dbname=""
					dbuser=""
					dbpassword=""
					dbhost=""
					#take name user pwd host
					for line in $(grep "DB_" $wpconfig| awk -F\' '{print $2 $4}' | xargs -n2); do
						#echo "$line"
						if [ "${line/DB_NAME}" != $line ]; then
							dbname="${line/DB_NAME}"
						fi
						if [ "${line/DB_USER}" != $line ]; then
							dbuser="${line/DB_USER}"
						fi
						if [ "${line/DB_PASSWORD}" != $line ]; then
							dbpassword="${line/DB_PASSWORD}"
						fi
						if [ "${line/DB_HOST}" != $line ]; then
							dbhost="${line/DB_HOST}"
						fi
						#complicated
						#echo "3rd level loop"
					done
					echo "$dbname, $dbuser, $dbpassword, $dbhost"

					#rsync and create folder structure in case it doenst exist
					#for wp-content
					rsync -a --relative $wpcontent root@$remote:/backups/$servername/latest/
					if [ $? -eq 0 ]; then
        				echo "wpcontent rsync was succesfull" >> $LOGFILE
					else
        				echo "$wpcontent  failed to sync" >> $LOGFILE
					fi

					#for htacces
					rsync -a --relative $htacces root@$remote:/backups/$servername/latest/
					#for wpconfig
					rsync -a --relative $wpconfig root@$remote:/backups/$servername/latest/
					#for version
					rsync -a --relative $version root@$remote:/backups/$servername/latest/



					#dumping database
					echo "Dumping the DBs..."
					mysqldump -u$dbuser -p$dbpassword $dbname > $LOCALFILE
					if [ $? -eq 0 ]; then
        				echo 'mysqldump was successful' >> $LOGFILE
					else
        				echo 'mysqldump failed' >> $LOGFILE
					fi

					#sync dump
					rsync -a --relative $LOCALFILE root@$remote:/backups/$servername/latest/srv/users/$username/apps/$appname

					#removelocal mysqldump
					rm -vf $LOCALFILE

				else
					echo "$spath is not a wordpress, sync everything" >>$LOGFILE
					rsync -a --relative $apps/$appname root@$remote:/backups/$servername/latest/
				fi
			else
				echo "$appname has no public directory" >>$LOGFILE
				rsync -a --relative $apps/$appname root@$remote:/backups/$servername/latest/
			fi
	
		done
	else
		echo "$username has no apps" >>$LOGFILE
	fi

done

echo "Log finished" >> $LOGFILE

rsync -a --relative $LOGFILE root@$remote:/backups/$servername/latest/