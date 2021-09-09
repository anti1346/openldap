#!/bin/bash

### ENV
export $(grep -v '^#' .env | xargs)

if [ ! -d ldifs/.tmp ];
then
     mkdir -p ldifs/.tmp
fi

cat <<\EOF > ldifs/ldapGroupAdd.sh
#!/bin/bash
# ./ldapGroupAdd.sh ID GID

### ENV
export $(grep -v '^#' ../.env | xargs)

if [ ! -d .tmp ];
then
     mkdir .tmp
fi

echo "dn: cn=$1,ou=Groups,${OLolcSuffix}
changetype: add
objectClass: top
objectClass: posixGroup
#objectClass: groupOfUniqueNames
gidNumber: $2
cn: $1
# uniqueMember: <DN of member>
#memberUid: 1502
description: memo" > .tmp/$1.ldif

ldapmodify -a -x -D cn=Manager,${OLolcSuffix} -H ldap://127.0.0.1 -w "${OLolcRootPPW}" -f .tmp/$1.ldif
EOF

cat <<\EOF > ldifs/ldapUserAdd.sh
#!/bin/bash
# ./ldapUserAdd.sh ID "NAME" UID

### ENV
export $(grep -v '^#' ../.env | xargs)

if [ ! -d .tmp ];
then
     mkdir .tmp
fi

echo "dn: cn=$1,ou=Groups,${OLolcSuffix}
changetype: add
objectClass: top
objectClass: posixGroup
gidNumber: $3
cn: $1
description: Group Description

dn: uid=$1,ou=People,${OLolcSuffix}
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
userPassword: ${OLolcInitialPW}" > .tmp/$1.ldif

ldapmodify -a -x -D cn=Manager,${OLolcSuffix} -H ldap://127.0.0.1 -w "${OLolcRootPPW}" -f .tmp/$1.ldif


echo "dn: uid=$1,ou=People,${OLolcSuffix}
changetype: modify
add: pwdReset
pwdReset: TRUE" > .tmp/mod-$1.ldif

ldapmodify -a -x -D cn=Manager,${OLolcSuffix} -H ldap://127.0.0.1 -w "${OLolcRootPPW}" -f .tmp/mod-$1.ldif
EOF

cat <<\EOF > ldifs/ldapsearch.sh
#!/bin/bash
# ./ldapsearch.sh

### ENV
export $(grep -v '^#' ../.env | xargs)

echo "Group ID :"
ldapsearch -h 127.0.0.1 -x -b "${OLolcSuffix}" "(cn=*)" | egrep 'gidNumber' | sort -r | uniq
echo ""
echo "User ID :"
ldapsearch -h 127.0.0.1 -x -b "${OLolcSuffix}" "(cn=*)" | egrep 'uidNumber' | sort -r | uniq
EOF

chmod +x ldifs/*.sh
