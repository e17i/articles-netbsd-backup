#!/bin/sh

# comment to really do backups
TEST=echo

# define this when dump device must be mounted
DUMPDEV=afp://:${DUMPDEVPWD}@timecapsule/ 
DUMPMNT=/mnt/bkup

# unset if you dont want a snapshot
FSS=fss0
SRCDEV=/
SNAPSHOT=/root/snapshot

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

test -f ~/.backup.conf && . ~/.backup.conf
test -f ~/etc/backup.conf && . ~/etc/backup.conf

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
    new) ${TEST} fssconfig -c ${FSS} ${SRCDEV} ${SNAPSHOT}
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

makedump() {
  find_level

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

# backup [conf]
backup() {
  # check for custom conf
  test $# -gt 0 && test -f ${1} && . ${1}
  find_level

  snapshot new
  # backup_dev mount
  mount_backup
  makedump
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
