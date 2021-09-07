#!/bin/bash

echo "Group ID :"
ldapsearch -h 127.0.0.1 -x -b "dc=ldap,dc=4wxyz,dc=com" "(cn=*)" | egrep 'gidNumber' | sort -r | uniq
echo ""
echo "User ID :"
ldapsearch -h 127.0.0.1 -x -b "dc=ldap,dc=4wxyz,dc=com" "(cn=*)" | egrep 'uidNumber' | sort -r | uniq
