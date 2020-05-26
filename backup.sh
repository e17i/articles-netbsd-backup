#!/usr/pkg/bin/bash

# copy and adapt the config vars into ~/etc/backup.conf
# put auth info like DUMPDEVPWD into ~/.backup.conf
# and set it chmod 400 and chflags nodump
# install as root crontab like this:
# # daily backups
# 0       1       *       *       *       /usr/pkg/bin/bash -c '. /root/bin/backup.sh && backup /root/etc/backup-var.conf' 2>&1 | tee /var/log/backup-var.out | sendmail -t
# 30      1       *       *       *       /usr/pkg/bin/bash -c '. /root/bin/backup.sh && backup' 2>&1 | tee /var/log/backup.out | sendmail -t

# uncomment to test backup config
#TEST=echo

# define this when dump device must be mounted
DUMPDEV=afp://:${DUMPDEVPWD}@timecapsule/ 
DUMPMNT=/mnt/bkup

# unset if you dont want a snapshot
FSS=fss0
SRCDEV=/
SNAPSHOT=/tmp/snapshot

# mountpoint of fs to backup
SRCMNT=/mnt/dev

# backup device or file
BACKUP=${DUMPMNT}/client/dump
#BACKUP=

# backup levels for each day of month
LEVELS=(- 0 3 2 5 4 7 6 1 3 2 5 4 7 6 1 3 2 5 4 7 6 1 3 2 5 4 7 6 1 3 2)

dumpcmd() {
  ${TEST} dump $*
}

restorecmd() {
  ${TEST} restore $*
}

export PATH=$PATH:/usr/pkg/bin

# absolute paths to use in root crontab
test -f /root/.backup.conf && . /root/.backup.conf
test -f /root/etc/backup.conf && . /root/etc/backup.conf

backup_dev() {
  if [ "${DUMPMNT}-" != "-" ]; then
    case "$1" in
    mount) ${TEST} mount_afp ${DUMPDEV} ${DUMPMNT}
           ;;
    unmount) ${TEST} afp_client unmount ${DUMPMNT}
             ;;
    esac
  fi
}

# when the time capsule needs to spin up, mount seems to fail
# so a second try is done
mount_backup() {
  backup_dev mount
  if [ $? -eq 2 ]; then
    backup_dev mount
  fi
}

snapshot() {
  if [ "${FSS}-" != "-" ]; then
    case $1 in
    new) ${TEST} fssconfig -c ${FSS} ${SRCDEV} ${SNAPSHOT} 512 10485760
         ${TEST} mount -r /dev/${FSS} ${SRCMNT}
         ;;
    rm) ${TEST} umount ${SRCMNT}
        ${TEST} fssconfig -u ${FSS}
        ${TEST} rm -f ${SNAPSHOT}
        ;;
    esac
  fi
}

find_level() {
  # find level for today
  LEV=${LEVELS[`date '+%e'`]}
  if [ "${1}-" != "-" ]; then
    LEV=${1}
  fi
  if [ "${BACKUP}-" != "-" ]; then
    BACKUPFILE=${BACKUP}.${LEV}
    BOUT=
  else
    BACKUPFILE=
    BOUT=-
  fi
}

# makedump lev
makedump() {
  find_level ${1}

  # save prev lev 0 dump as prevmonth
  if [ ${LEV} -eq 0 ];then
    test -f ${BACKUPFILE}.prevmonth && rm ${BACKUPFILE}.prevmonth
    test "${BACKUPFILE}-" != "-" && test -f ${BACKUPFILE} && mv ${BACKUPFILE} ${BACKUPFILE}.prevmonth
  fi

  # save prev lev 1 dump as prevweek
  if [ ${LEV} -eq 1 ];then
    test -f ${BACKUPFILE}.prevweek && rm ${BACKUPFILE}.prevweek
    test "${BACKUPFILE}-" != "-" && test -f ${BACKUPFILE} && mv ${BACKUPFILE} ${BACKUPFILE}.prevweek
  fi

  # and dump
  dumpcmd ${LEV}ua -h 0 -f ${BACKUPFILE}${BOUT} ${SRCMNT} 
}

mailheader() {
  echo "To: root"
  printf "Subject: %s backup dump output for %s\n\n" `hostname` "`date`"
}

# backup [conf [lev]]
backup() {
  mailheader
  # check for custom conf
  test $# -gt 0 && test -f ${1} && . ${1}
  # check for lev
  test $# -gt 1 && LEV=${2} || LEV=
  find_level $LEV

  snapshot new
  # backup_dev mount
  mount_backup
  makedump $LEV
  backup_dev unmount
  snapshot rm
}

# restoredump [conf [args [lev]]]
restoredump() {
  # check for custom conf
  test $# -gt 0 && test -f ${1} && . ${1}

  # check for args
  test $# -gt 1 && ARGS=${2}

  # check for lev
  test $# -gt 2 && LEV=${3} || LEV=
  find_level $LEV

  # backup_dev mount
  mount_backup
  restorecmd ${ARGS} -f ${BACKUPFILE}${BOUT}
  backup_dev unmount
}
