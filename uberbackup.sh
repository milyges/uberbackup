#!/bin/sh

# Glowny katalog backupu
BACKUPDIR="/mnt/backup/filesystem"

# Podkatalog na aktualny backup
CURRENTDIR="$(date '+%d-%m-%Y')"

# Ilosc trzymanych kopii
KEEP="7"

# Gdzie wysyłać logi
MAILTO=""

IONICE="/usr/bin/ionice -c 2 -n 7"
LOGFILE="$(mktemp)"

log() {
	while read LINE
	do
		NOW=$(date '+%H:%M %d-%m-%Y')
		echo "${NOW}: ${LINE}" >> "${LOGFILE}"
	done
}

# rotate katalog ilosc_kopii katalog_do_backupu
rotate() {
	LATESTDIR="$(ls -t "${1}" | head -n 1)"
	if [ -z "${LATESTDIR}" ]
	then
		echo "No backups, skipping rotate" | log
		mkdir "${1}/${3}" 2>&1 | log
		return
	fi

	echo "Latest backup: ${LATESTDIR}" 2>&1 | log
	ls -t ${1} | awk "NR >= ${2} { print \$0 }" | while read DIR
	do
		echo "Remove old backup directory ${DIR}" 2>&1 | log
		${IONICE} rm -rf "${1}/${DIR}" 2>&1 | log
	done

	echo "Linking ${LATESTDIR} -> ${3}" | log
	${IONICE} cp -al "${1}/${LATESTDIR}" "${1}/${3}" 2>&1 | log
	touch "${1}/${3}" 2>&1 | log
}

backup_fs() {
	echo "Starting backup of ${2} to ${1}" | log
	mkdir -p "${1}${2}" 2>&1 | log
	${IONICE} rsync -aAX --delete "${2}" "${1}${2}" 2>&1 | log
	echo "Backup ${2} finished" | log
}

echo "Starting backup on $(hostname)" | log

if [ ! -d "${BACKUPDIR}" ]
then
	echo "Fatal error: ${BACKUPDIR} does not exist" | log
	mail -s "UberBackup: failed on $(hostname)" "${MAILTO}" < "${LOGFILE}"
	rm "${LOGFILE}"
	exit 1
fi

rotate "${BACKUPDIR}" "${KEEP}" "${CURRENTDIR}"

backup_fs "${BACKUPDIR}/${CURRENTDIR}" "/etc/"
backup_fs "${BACKUPDIR}/${CURRENTDIR}" "/usr/local/"
backup_fs "${BACKUPDIR}/${CURRENTDIR}" "/home/"

mail -s "UberBackup: finished on $(hostname)" "${MAILTO}" < "${LOGFILE}"
rm "${LOGFILE}"

