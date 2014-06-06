#!/bin/sh

# Glowny katalog backupu
BACKUPDIR="/mnt/backup/filesystem"

# Podkatalog na aktualny backup
CURRENTDIR="$(date '+%d-%m-%Y')"

# Ilosc trzymanych kopii
KEEP="7"

# Gdzie wysyłać logi
MAILTO="gglinski@grupaeuro.pl"

IONICE="/usr/bin/ionice -c 2 -n 7"
LOGFILE="$(mktemp)"

log() {
	NOW=$(date '+%H:%M %d-%m-%Y')
	echo "${NOW}: ${1}"
}

# rotate katalog ilosc_kopii katalog_do_backupu
rotate() {
	LATESTDIR="$(ls -t "${1}" | head -n 1)"
	if [ -z "${LATESTDIR}" ]
	then
		log "No backups, skipping rotate" 2>&1 >> "${LOGFILE}"
		mkdir "${1}/${3}" 2>&1 >> "${LOGFILE}"
		return
	fi

	log "Latest backup: ${LATESTDIR}" 2>&1 >> "${LOGFILE}"
	ls -t ${1} | awk "NR >= ${2} { print \$0 }" | while read DIR
	do
		log "Remove old backup directory ${DIR}" 2>&1 >> "${LOGFILE}"
		${IONICE} rm -rf "${1}/${DIR}" 2>&1 >> "${LOGFILE}"
	done

	log "Linking ${LATESTDIR} -> ${3}" 2>&1 >> "${LOGFILE}"
	${IONICE} cp -al "${1}/${LATESTDIR}" "${1}/${3}" 2>&1 >> "${LOGFILE}"
	touch "${1}/${3}" 2>&1 >> "${LOGFILE}"
}

backup_fs() {
	log "Starting backup of ${2} to ${1}" 2>&1 >> "${LOGFILE}"
	mkdir -p "${1}${2}" 2>&1 >> "${LOGFILE}" 2>&1 >> "${LOGFILE}"
	${IONICE} rsync -aAX --delete "${2}" "${1}${2}" 2>&1 >> "${LOGFILE}"
	log "Backup ${2} finished" 2>&1 >> "${LOGFILE}"
}

log "Starting backup on $(hostname)" 2>&1 >> "${LOGFILE}"

if [ ! -d "${BACKUPDIR}" ]
then
	log "Fatal error: ${BACKUPDIR} does not exist" 2>&1 >> "${LOGFILE}"
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

