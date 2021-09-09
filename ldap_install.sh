#!/bin/bash

### ENV
export $(grep -v '^#' .env | xargs)

### 호스트 네임 등록
echo -e "\033[0;31m호스트 네임 등록"
echo -e "\033[0m\c"
if [[ -z `grep ldap /etc/hosts` ]];
then
cat <<EOF >> /etc/hosts
$ldapIp1	$ldapHostname1  $ldapFqdn1
$ldapIp2	$ldapHostname2  $ldapFqdn2
EOF
fi
echo -e "\033[0m"


### SELINUX 끄기 ###
echo -e "\033[0;31mSELINUX 끄기"
echo -e "\033[0m\c"
if [ -f /usr/sbin/setenforce ];
then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    /usr/sbin/setenforce 0
fi
echo -e "\033[0m"


### 방화벽 끄기 ###
echo -e "\033[0;31m방화벽 끄기"
echo -e "\033[0m\c"
if [[ `firewall-cmd --state` = running ]];
then
    systemctl stop firewalld
    systemctl disable firewalld
fi
echo -e "\033[0m"


### 타임존(TimeZone) 설정 ###
echo -e "\033[0;31m타임존(TimeZone) 설정"
echo -e "\033[0m\c"
timedatectl set-timezone Asia/Seoul
echo -e "\033[0m"


############################################################################
############################################################################
############################################################################
echo -e "\033[0;31mOPENVPN 패키지 설치 및 데몬 기동 START"
echo -e "\033[0m\c"
if [[ -z `rpm -qa | grep openldap-server` ]];
then
    yum reinstall -y --quiet compat-openldap \
     openldap openldap-servers openldap-clients \
     openldap-servers-sql openldap-devel
else
    systemctl stop slapd
    rm -rf /etc/openldap \
     /var/lib/ldap \
     /run/openldap \
     /usr/lib64/openldap \
     /usr/libexec/openldap \
     /usr/share/doc/openldap-* \
     /usr/share/openldap-servers
    yum reinstall -y --quiet compat-openldap \
     openldap openldap-servers openldap-clients \
     openldap-servers-sql openldap-devel
fi
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
chown -R ldap:ldap /var/lib/ldap/DB_CONFIG
systemctl restart slapd
echo -e "\033[0;31mOPENVPN 패키지 설치 및 데몬 기동 END"
echo -e "\033[0m"
############################################################################
############################################################################
############################################################################

### LDIF Directory 생성
echo -e "\033[0;31mTemporary($ldifDirectory) 디렉토리 생성"
echo -e "\033[0m\c"
if [ ! -d $ldifDirectory ]; then
    mkdir $ldifDirectory
fi
echo -e "\033[0m"


echo -e "\033[0;31mchrootpw.ldif"
echo -e "\033[0m\c"
cat <<EOF > ${ldifDirectory}/chrootpw.ldif
dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcRootPW
#replace: olcRootPW
olcRootPW: ${OLolcRootPW}
EOF
ldapadd -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/chrootpw.ldif


echo -e "\033[0;31m기본 스키마 적용"
echo -e "\033[0m\c"
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/core.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/ppolicy.ldif

ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/collective.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/misc.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/duaconf.ldif


echo -e "\033[0;31mdb.ldif"
echo -e "\033[0m\c"
cat <<EOF > ${ldifDirectory}/db.ldif
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: ${OLolcSuffix}

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=Manager,${OLolcSuffix}

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: ${OLolcRootPW}
EOF
ldapmodify -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/db.ldif


###certs
echo -e "\033[0;31mcerts 생성"
echo -e "\033[0m\c"
cat <<EOF > ${ldifDirectory}/certificate.sh
#!/bin/bash
openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes \
-out /etc/openldap/certs/${OLDomain}.crt \
-keyout /etc/openldap/certs/${OLDomain}.key \
-subj "/C=KR/ST=Seoul/L=Jongno-gu/O=4wxyz/OU=Infrastructure Team/CN=${OLDomain}"
EOF
chmod +x ${ldifDirectory}/certificate.sh
sh ${ldifDirectory}/certificate.sh
chown -R ldap:ldap /etc/openldap/certs/${OLDomain}.*
chmod o-r /etc/openldap/certs/${OLDomain}.key

cat <<EOF > ${ldifDirectory}/certs.ldif
dn: cn=config
changetype: modify
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/openldap/certs/${OLDomain}.key

dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/openldap/certs/${OLDomain}.crt
EOF
ldapmodify -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/certs.ldif

cat <<EOF > ${ldifDirectory}/certs.ldif
dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/openldap/certs/${OLDomain}.crt

dn: cn=config
changetype: modify
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/openldap/certs/${OLDomain}.key
EOF
ldapmodify -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/certs.ldif
sed -i 's/SLAPD_URLS=\"ldapi:\/\/\/\ ldap:\/\/\/\"/SLAPD_URLS=\"ldapi:\/\/\/\ ldap:\/\/\/ ldaps:\/\/\/\"/' /etc/sysconfig/slapd


###rsyslog(slapd)
echo -e "\033[0;31mRSYSLOG 설정"
echo -e "\033[0m\c"
cat <<EOF > ${ldifDirectory}/rsyslog.ldif
dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: stats
EOF
ldapmodify -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/rsyslog.ldif
if [[ -z `grep slapd.log /etc/rsyslog.conf` ]];
then
    echo -e "\n# LDAP log" >> /etc/rsyslog.conf
    echo -e "local4.*\t\t\t\t\t\t/var/log/slapd.log" >> /etc/rsyslog.conf
    systemctl restart rsyslog
fi
systemctl restart slapd


echo -e "\033[0;31mmonitor.ldif"
echo -e "\033[0m\c"
cat <<EOF > ${ldifDirectory}/monitor.ldif
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read
  by dn.base="cn=Manager,${OLolcSuffix}" read by * none
EOF
ldapmodify -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/monitor.ldif


echo -e "\033[0;31macl.ldif"
echo -e "\033[0m\c"
cat <<EOF > ${ldifDirectory}/acl.ldif
dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange by
  dn="cn=Manager,${OLolcSuffix}" write by anonymous auth by self write by * none
olcAccess: {1}to dn.base="" by * read
olcAccess: {2}to * by dn="cn=Manager,${OLolcSuffix}" write by * read
EOF
ldapmodify -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/acl.ldif


echo -e "\033[0;31mbaseTop.ldif"
echo -e "\033[0m\c"
cat <<EOF > ${ldifDirectory}/baseTop.ldif
dn: ${OLolcSuffix}
dc: ldap
objectClass: top
objectClass: dcObject
objectclass: organization
o: ${OLDomain} Corporation

dn: cn=Manager,${OLolcSuffix}
cn: Manager
objectClass: organizationalRole
description: Directory Manager
EOF
ldapadd -x -D cn=Manager,${OLolcSuffix} -w ${OLolcRootPPW} -f ${ldifDirectory}/baseTop.ldif


echo -e "\033[0;31mbaseOu.ldif"
echo -e "\033[0m\c"
cat <<EOF > ${ldifDirectory}/baseOu.ldif
dn: ou=People,${OLolcSuffix}
ou: People
objectClass: organizationalUnit

dn: ou=Groups,${OLolcSuffix}
ou: Groups
objectClass: organizationalUnit
EOF
ldapadd -x -D cn=Manager,${OLolcSuffix} -w ${OLolcRootPPW} -f ${ldifDirectory}/baseOu.ldif


###PPOLICY
echo -e "\033[0;31mPPOLICY"
echo -e "\033[0m\c"
cat <<EOF > ${ldifDirectory}/ppolicy-module.ldif
dn: cn=module{0},cn=config
cn: module
objectClass: olcModuleList
olcModuleLoad: ppolicy.la
olcModulePath: /usr/lib64/openldap
EOF
ldapadd -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/ppolicy-module.ldif

cat <<EOF > ${ldifDirectory}/ppolicy-ou.ldif
dn: ou=Policies,${OLolcSuffix}
ou: Policies
objectClass: top
objectClass: extensibleObject
objectClass: organizationalUnit
EOF
ldapmodify -a -x -D cn=Manager,${OLolcSuffix} -w ${OLolcRootPPW} -f ${ldifDirectory}/ppolicy-ou.ldif

cat <<EOF > ${ldifDirectory}/ppolicy-overlay.ldif
dn: olcOverlay=ppolicy,olcDatabase={2}hdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcPpolicyConfig
olcOverlay: ppolicy
olcPPolicyDefault: cn=default,ou=Policies,${OLolcSuffix}
olcPPolicyUseLockout: FALSE
olcPPolicyHashCleartext: TRUE
EOF
ldapadd -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/ppolicy-overlay.ldif

cat <<EOF > ${ldifDirectory}/ppolicy-password.ldif
dn: cn=default,ou=Policies,${OLolcSuffix}
objectClass: top
objectClass: device
objectClass: pwdPolicy
objectClass: pwdPolicyChecker
cn: default
pwdAttribute: userPassword
pwdCheckQuality: 0
pwdMinAge: 0
pwdMaxAge: 0
pwdMinLength: 8
pwdInHistory: 5
pwdMaxFailure: 3
pwdFailureCountInterval: 0
pwdLockout: TRUE
pwdLockoutDuration: 0
pwdAllowUserChange: TRUE
pwdExpireWarning: 0
pwdGraceAuthNLimit: 0
pwdMustChange: FALSE
pwdSafeModify: FALSE
EOF
ldapadd -x -D cn=Manager,${OLolcSuffix} -w ${OLolcRootPPW} -f ${ldifDirectory}/ppolicy-password.ldif


###syncprov
echo -e "\033[0;31msyncprov"
echo -e "\033[0m\c"
if [ "$1" == "slave" ];
then
cat <<EOF > ${ldifDirectory}/syncrepl-slave-replication.ldif
dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcSyncRepl
olcSyncRepl: rid=300
  provider=ldap://${ldapIp1}:389/
  bindmethod=simple
  binddn="uid=replicator,${OLolcSuffix}"
  credentials=qwER12#$
  searchbase="${OLolcSuffix}"
  scope=sub
  schemachecking=on
  type=refreshAndPersist
  retry="30 5 300 3"
  interval=00:00:05:00
EOF
    ldapadd -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/syncrepl-slave-replication.ldif
    echo -e "\033[0;33msyncprov slave\n"
else
cat <<EOF > ${ldifDirectory}/syncrepl-master-replicator.ldif
dn: uid=replicator,${OLolcSuffix}
uid: replicator
objectclass: account
objectClass: simpleSecurityObject
description: Replication User
userPassword: qwER12#$
EOF
    ldapadd -x -D cn=Manager,${OLolcSuffix} -w ${OLolcRootPPW} -f ${ldifDirectory}/syncrepl-master-replicator.ldif

cat <<EOF > ${ldifDirectory}/syncrepl-master-module.ldif
dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModulePath: /usr/lib64/openldap
olcModuleLoad: syncprov.la
EOF
    ldapadd -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/syncrepl-master-module.ldif

cat <<EOF > ${ldifDirectory}/syncrepl-master-syncprov.ldif
dn: olcOverlay=syncprov,olcDatabase={2}hdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpSessionLog: 100
EOF
    ldapadd -Y EXTERNAL -H ldapi:/// -f ${ldifDirectory}/syncrepl-master-syncprov.ldif
    echo -e "\033[0;33msyncprov master\n"
fi


echo -e "\033[0;36m"
ldapsearch -Q -LLL -Y EXTERNAL -H ldapi:/// -b cn=schema,cn=config dn
echo -e "\033[0;32m"
ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" -LLL -Q "olcDatabase=*" dn
echo -e "\033[0m"