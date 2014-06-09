#!/bin/sh

# Glowny katalog backupu
BACKUPDIR="/mnt/backup/uberbackup"

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

# katalog_docelowy katalog_zrodlowy
backup_fs() {
	echo "Backing up ${2} to ${1}" | log
	mkdir -p "${1}${2}" 2>&1 | log
	${IONICE} rsync -aAX --delete "${2}" "${1}${2}" 2>&1 | log
	echo "Backup ${2} finished" | log
}

# katalog_docelowy login haslo [baza]
backup_mysql() {
	DBS=""
	if [ -z "${4}" ]
	then
		DBS="$(echo SHOW DATABASES | mysql --user="${2}" --password="${3}" -s)"
	else
		DBS="${4}"
	fi

	for DB in ${DBS}
	do
		echo "Backing up MySQL database ${DB}" | log

		if [ "$DB" = "mysql" ] || [ $DB = "information_schema" ] || [ "${DB}" = "performance_schema" ]
		then
			continue
		fi

		rm -f "${1}/mysql/${DB}.sql.bz2" 2>&1 | log
		rm -f "${1}/mysql/${DB}.sql" 2>&1 | log

		mkdir -p "${1}/mysql" 2>&1 | log
		TMPLOG="$(mktemp)"
		mysqldump --user="${2}" --password="${3}" "${DB}" > "${1}/mysql/${DB}.sql" 2> "${TMPLOG}"
		[ $? -ne 0 ] && rm "${1}/mysql/${DB}.sql" || bzip2 "${1}/mysql/${DB}.sql" 2>&1 | log
		cat "${TMPLOG}" | log
		rm -f "${TMPLOG}"
		if [ ! -s "${1}/mysql/${DB}.sql.bz2" ]
		then
			echo "ERROR: ${DB}.sql not bzipped!" | log
		fi
	done
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

#backup_fs "${BACKUPDIR}/${CURRENTDIR}" "/etc/"
#backup_fs "${BACKUPDIR}/${CURRENTDIR}" "/usr/local/"
#backup_fs "${BACKUPDIR}/${CURRENTDIR}" "/home/"

#backup_mysql "${BACKUPDIR}/${CURRENTDIR}" "backup" "***"

mail -s "UberBackup: finished on $(hostname)" "${MAILTO}" < "${LOGFILE}"
rm "${LOGFILE}"

