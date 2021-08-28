#!/bin/bash
#  _               _               _                _                     _
# | |             | |             | |              | |                   | |
# | |__  _ __ ___ | | _____ ______| |__   __ _  ___| | ___   _ _ __   ___| |__
# | '_ \| '__/ _ \| |/ / _ \______| '_ \ / _` |/ __| |/ / | | | '_ \ / __| '_ \
# | |_) | | | (_) |   <  __/      | |_) | (_| | (__|   <| |_| | |_) |\__ \ | | |
# |_.__/|_|  \___/|_|\_\___|      |_.__/ \__,_|\___|_|\_\\__,_| .__(_)___/_| |_|
#                                                             | |
#                                                             |_|
# Version 1.1
#
# This script is designed to maintain a tree-style .txt backup of specified directories.
# By default, it will keep 14 daily backups and archive monthly backups indefinitely (as .tar.xz).
# On the first of the month it will email a .tar.xz archive as an extra backup location. 
#
# Folder modification times will be set to 00:00 for ease of backup directory maintenance.
# This allows the cleanup function to operate correctly despite inconsistences in script run times. 
#
# Required dependencies:
# - tree
# - mutt (with working configuration)
# - xz-utils
################################################################################
#
# User Config
#
####################
recipient_email="mail@example.com"
email_subject="Your Backup Has Arrived! 💾"
monthly_email_body="Another month, another set of backups:"
forced_email_body="Monthly emails aren't enough for you?!\nHere's your backup:"
# Set backup output directory: "/example/location/backup"
output_dir="/path/to/output/directory"
# Directories to backup. Add as many as needed; including full path for each
# Numbering begins at 0, eg. SOURCES[0]="/example/Media/ISOs"
SOURCES[0]="/example/Media/TV Shows"
SOURCES[1]="/example/Media/Movies"
SOURCES[2]="/example/Media/ISOs"
# Depth of tree output for each source defined above, eg. DEPTH[0]=1
DEPTH[0]=1
DEPTH[1]=2
DEPTH[2]=1

####################
#
# Advanced Options
#
####################
# Use custom tree options per folder (TRUE/FALSE)
# If you're not sure what this is, leave set to 'FALSE'
# Enabling this will overwrite DEPTH settings above
USE_CUSTOM=FALSE
# Tree options for each source defined above, eg. CUSTOM_OPTIONS[0]="-d -L 1"
CUSTOM_OPTIONS[0]="-d -L 1"
CUSTOM_OPTIONS[1]="-a"
CUSTOM_OPTIONS[2]="-a -L 4"

################################################################################ END OF CONFIGURATION
#
# System Variables
#
####################
today=$(date +"%Y-%m-%d")
purged=FALSE
archived=FALSE

####################
#
# Functions
#
####################
#TODO - migrate to passing $BODY to the function, instead of declaring $BODY prior to calling function
send_mail () {
	tar -cJf "$output_dir/$today.tar.xz" -C $output_dir "$today"
	echo -e "$email_body" | mutt -s "$email_subject" -a "$output_dir/$today.tar.xz" -- $recipient_email && echo "Email sent to $recipient_email"
	rm -r "$output_dir/$today.tar.xz"
}
set_tree_options () {
	if [ $USE_CUSTOM = TRUE ]; then
		OPTIONS=("${CUSTOM_OPTIONS[@]}")
	else
		x=0
		for i in "${DEPTH[@]}"; do
			OPTIONS[$x]="-L $i"
			((x++))
		done
	fi
}

####################
#
# Tree Backup
#
####################
# If today's directory already exists, skip backup and force email.
# Otherwise complete backup and send email if first of the month.
if [ -d "$output_dir/$today" ]; then
	echo "today's backup already created, skipping. Forcing email:"
	BODY="$forced_email_body"
	BODY="$FORCED"
	send_mail
else
	mkdir "$output_dir/$today"
	set_tree_options
	x=0
	for i in "${SOURCES[@]}"; do
		source="${i##*/}"
		tree "$i" ${OPTIONS[$x]} >"$output_dir/$today/$source.txt" && echo "$source Completed"
		((x++))
	done
	touch --date= "$output_dir/$today"
	if [ "$(date +"%d")" = 01 ]; then
		email_body="$monthly_email_body"
		send_mail
	fi
fi
	
####################
#
# Clean Up
#
####################
#TODO - move cleanup tasks to functions (cleanup_tasks; archive_monthly, purge_old)
# Find 1st of month backups, archive as DATE.tar.xz, delete originals
#TODO - change to better name for $fname
#TODO - do we need the `:?` in the rmdir command?
#TODO - add mv && echo to previous line (find | tar) as && 
while read -r fname; do
	find "$BACKUP_DIR/$fname" -printf "%P\n" | tar -cJf "$BACKUP_DIR/$fname".tar.xz -C "$BACKUP_DIR/$fname"/ --remove-files -T -
	mv "$BACKUP_DIR/$fname".tar.xz "$BACKUP_DIR/Archive" && echo "Packed '$fname' into Archives/$fname.tar.xz, removed originals"
	rmdir "$BACKUP_DIR/${fname:?}" && archived=TRUE
done < <(find $BACKUP_DIR -maxdepth 1 -mtime +13 -type d -iname "****-**-01*" -printf "%P\n")
if [ $archived = TRUE ]; then
	echo "Archive completed"
else
	echo "No archive required"
fi

# Find and delete backups older than 13 days
#TODO - change to better name for $fclean
while read -r fclean; do
	rm -r "$BACKUP_DIR/$fclean" && purged=TRUE
	echo "Removed $fclean - Reason: older than 2 weeks"
done < <(find $BACKUP_DIR -maxdepth 1 -mtime +13 -type d -iname "****-**-**" -printf "%P\n")
if [ $purged = TRUE ]; then
	echo "Purge completed"
else
	echo "No purge required"
fi

# Cleanup Completion
if [ $purged = TRUE -o $archived = TRUE ]; then
	echo "All cleanup tasks completed" 
else
	echo "No cleanup tasks required"
fi
