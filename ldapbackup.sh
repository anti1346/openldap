#!/bin/bash

NOWH=`date +%Y%m%d%H`
RMDAY=`date -d '30 day ago'`

if [ ! -d $backup ]; then
    mkdir $backup
fi

slapcat -n 0 -l backup/$HOSTNAME-ldap_config_$NOWH.ldif
slapcat -n 2 -l backup/$HOSTNAME-ldap_data_$NOWH.ldif

echo "Backup Complete..... $RMDAY"
#find ./ -maxdepth 1 -mtime $RMDAY -exec rm {} \;
