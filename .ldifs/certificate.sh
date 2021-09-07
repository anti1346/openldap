#!/bin/bash

openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out /etc/openldap/certs/ldap.4wxyz.com.crt -keyout /etc/openldap/certs/ldap.4wxyz.com.key -subj "/C=KR/ST=Seoul/L=Jongno-gu/O=MoneyToday/OU=Infrastructure Team/CN=ldap.4wxyz.com"
