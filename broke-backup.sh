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
# This script is designed to maintain a tree-style .txt backup of specified folders.
# By default, it will keep daily backups for 14 days and archive monthly backups indefinitely (as .tar.xz).
# On the first of the month it will email a .tar.xz archive as an extra backup location. 
#
# File modification times will be set to 00:00 of the current day for ease of backup directory maintenance.
#
####################
# Required Dependencies:
# - tree
# - mutt
# - xz-utils
####################
#
# User Defined Variables
#
####################
# Set backup directory: "/example/location/backup"
BACKUP="/path/to/backup/directory"
# Recipient email
EMAIL=mail@example.com
# Email subject
SUBJECT="Your Backup Has Arrived! 💾"
# Folders to backup. Add as many as needed; including full path for each.
# One per line, and each enclosed in quotes                  "/example/folder/1" \
# All but last line need to end with a space and backslash   "/example/folder/2" \
# Last line ends in closing parenthesis                      "/example/folder/3")
FOLDERS=(\
"/example/Media/TV Shows" \
"/example/Media/Movies" \
"/example/Media/ISOs")
# Depth of tree output for each folder defined above, in order, seperated by spaces.
# Ex. for 3 folders: (1 1 3)
DEPTH=(1 2 1)
# Monthly email body (Enclosed in quotes; '\n' for a new line)
MONTHLY="Another month, another set of backups:"
# Forced email body
FORCED="Monthly emails aren't enough for you?!\nHere's your backup:"

####################
#
# Advanced Custom Options
#
####################
# Use custom tree options per folder (TRUE/FALSE)
# If you're not sure what this is, leave set to 'FALSE'
# Enabling this will overwrite DEPTH settings above
USE_CUSTOM=FALSE
# Separated by spaces, enclosed in quotes '("-d -L 1" "-a" "-a -L 4")'
CUSTOM_OPTIONS=("-d -L 1" "-d" "-d" "-d" "-d" "-d")

####################
#
# System Variables
#
####################
TODAY=$(date +"%Y-%m-%d")
PURGED=FALSE
ARCHIVED=FALSE

####################
#
# Functions
#
####################
send_email () {
	tar -cJf "$BACKUP/$TODAY.tar.xz" -C $BACKUP "$TODAY"
	echo -e "$BODY" | mutt -s "$SUBJECT" -a "$BACKUP/$TODAY.tar.xz" -- $EMAIL && echo "Email sent to $EMAIL"
	rm -r "$BACKUP/$TODAY.tar.xz"
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
# If today's folder already exists, skip backup and force email.
# Otherwise complete backup and send email if first of the month.
if [ -d "$BACKUP/$TODAY" ]; then
	echo "Today's backup already created, skipping. Forcing email:"
	BODY="$FORCED"
	send_email
else
	set_tree_options
	mkdir "$BACKUP/$TODAY"
	x=0
	for i in "${FOLDERS[@]}"; do
		FOLDER="${i##*/}"
		tree "$i" ${OPTIONS[$x]} >"$BACKUP/$TODAY/$FOLDER.txt" && echo "$FOLDER Completed"
		((x++))
	done
	touch --date= "$BACKUP/$TODAY"
	if [ "$(date +"%d")" = 01 ]; then
		BODY="$MONTHLY"
		send_email
	fi
fi
	
####################
#
# Clean Up
#
####################
# Find 1st of month backups, archive as DATE.tar.xz, delete originals
while read -r fname; do
	find "$BACKUP/$fname" -printf "%P\n" | tar -cJf "$BACKUP/$fname".tar.xz -C "$BACKUP/$fname"/ --remove-files -T -
	mv "$BACKUP/$fname".tar.xz "$BACKUP/Archive" && echo "Packed '$fname' into Archives/$fname.tar.xz, removed originals"
	rmdir "$BACKUP/${fname:?}" && ARCHIVED=TRUE
done < <(find $BACKUP -maxdepth 1 -mtime +13 -type d -iname "****-**-01*" -printf "%P\n")
if [ $ARCHIVED = TRUE ]; then
	echo "Archive completed"
else
	echo "No archive required"
fi

# Find and delete files older than 13 days
while read -r fclean; do
	rm -r "$BACKUP/$fclean" && PURGED=TRUE
	echo "Removed $fclean - Reason: older than 2 weeks"
done < <(find $BACKUP -maxdepth 1 -mtime +13 -type d -iname "****-**-**" -printf "%P\n")
if [ $PURGED = TRUE ]; then
	echo "Purge completed"
else
	echo "No purge required"
fi

# Cleanup Completion
if [ $PURGED = TRUE -o $ARCHIVED = TRUE ]; then
	echo "All cleanup tasks completed" 
else
	echo "No cleanup tasks required"
fi
