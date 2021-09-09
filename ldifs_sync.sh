#!/bin/bash

### ENV
export $(grep -v '^#' .env | xargs)

rsync -avz --delete ${ldapIp1}::ldap_config /root/openldap
