#!/bin/bash

# Ceilometer API monitoring script for Sensu / Nagios
#
# Copyright © 2013 eNovance <licensing@enovance.com>
#
# Author: Guillaume Abrioux <guillaume.abrioux@enovance.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Requirement: curl
#
set -e

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

usage ()
{
    echo "Usage: $0 [OPTIONS]"
    echo " -h               Get help"
    echo " -H <Auth URL>    URL for obtaining an auth token. Ex: http://localhost"
    echo " -T <tenant>      Tenant to use to get an auth token"
    echo " -U <username>    Username to use to get an auth token"
    echo " -P <password>    Password to use ro get an auth token"
}

while getopts 'h:H:U:T:P:' OPTION
do
    case $OPTION in
        h)
            usage
            exit 0
            ;;
        H)
            export OS_AUTH_URL=$OPTARG
            ;;
        T)
            export OS_TENANT=$OPTARG
            ;;
        U)
            export OS_USERNAME=$OPTARG
            ;;
        P)
            export OS_PASSWORD=$OPTARG
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

if ! which curl >/dev/null 2>&1
then
    echo "curl is not installed."
    exit $STATE_UNKNOWN
fi

TOKEN=$(curl -s -X 'POST' ${OS_AUTH_URL}:5000/v2.0/tokens -d '{"auth":{"passwordCredentials":{"username": "'$OS_USERNAME'", "password":"'$OS_PASSWORD'" ,"tenant":"'$OS_TENANT'"}}}' -H 'Content-type: application/json' |sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}'|awk 'NR==2'|awk '{print $2}'|sed -n 's/.*"\([^"]*\)".*/\1/p')
TENANT_ID=$(curl -s -H "X-Auth-Token: $TOKEN" ${OS_AUTH_URL}:5000/v2.0/tenants |sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}'|grep id|awk 'NR==1'|awk '{print $2}'|sed -n 's/.*"\([^"]*\)".*/\1/p')
TOKEN2=$(curl -s -X 'POST' ${OS_AUTH_URL}:5000/v2.0/tokens -d '{"auth":{"passwordCredentials":{"username": "'$OS_USERNAME'", "password":"'$OS_PASSWORD'"} ,"tenantId":"'$TENANT_ID'"}}' -H 'Content-type: application/json' |sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}'|awk 'NR==2'|awk '{print $2}'|sed -n 's/.*"\([^"]*\)".*/\1/p')

if [ -z "$TOKEN2" ]; then
    echo "Unable to get a token from Keystone API"
    exit $STATE_CRITICAL
fi

RES=$(curl -s -H "X-Auth-Token: $TOKEN2" -H 'Content-Type: application/json' ${OS_AUTH_URL}:8777/v1/meters | grep -o user_id | wc -l)

echo "Ceilometer API is working with $RES meters."