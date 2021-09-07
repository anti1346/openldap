#!/bin/bash

# ./91ldapGroupAddv3.sh ID GID

if [ ! -d .tmp ];
then
     mkdir .tmp
fi

echo "dn: cn=$1,ou=Groups,dc=ldap,dc=4wxyz,dc=com
changetype: add
objectClass: top
objectClass: posixGroup
#objectClass: groupOfUniqueNames
gidNumber: $2
cn: $1
# uniqueMember: <DN of member>
#memberUid: 1502
description: memo" > .tmp/$1.ldif

ldapmodify -a -x -D cn=Manager,dc=ldap,dc=4wxyz,dc=com -H ldap://127.0.0.1 -w "passwd1!" -f .tmp/$1.ldif
