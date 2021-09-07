#!/bin/bash

# ./92ldapUserAddv3.sh ID "NAME" UID

if [ ! -d .tmp ];
then
     mkdir .tmp
fi

echo "dn: cn=$1,ou=Groups,dc=ldap,dc=4wxyz,dc=com
changetype: add
objectClass: top
objectClass: posixGroup
gidNumber: $3
cn: $1
description: Group Description

dn: uid=$1,ou=People,dc=ldap,dc=4wxyz,dc=com
uid: $1
cn: $2 
sn: $2
objectClass: top
objectClass: person
objectClass: posixAccount
objectClass: inetOrgPerson
objectClass: shadowAccount
objectClass: organizationalPerson
givenName: $2
mail: $1@4wxyz.com
gecos: $1
loginShell: /bin/bash
uidNumber: $3
gidNumber: $3
homeDirectory: /home/$1
shadowMin: 0
shadowMax: 99999
shadowWarning: 7
shadowLastChange: 18474
userPassword: {SSHA}NHQ2+tv/xha5LpjEFCn9eJb1wCll5p8f" > .tmp/$1.ldif

ldapmodify -a -x -D cn=Manager,dc=ldap,dc=4wxyz,dc=com -H ldap://127.0.0.1 -w "passwd1!" -f .tmp/$1.ldif


echo "dn: uid=$1,ou=People,dc=ldap,dc=4wxyz,dc=com
changetype: modify
add: pwdReset
pwdReset: TRUE" > .tmp/mod-$1.ldif

ldapmodify -a -x -D cn=Manager,dc=ldap,dc=4wxyz,dc=com -H ldap://127.0.0.1 -w "passwd1!" -f .tmp/mod-$1.ldif
