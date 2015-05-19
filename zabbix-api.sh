#!/bin/bash

# change parametrs:
# HTTP_LOGIN:HTTP_PASS
# MY_ZABBIX_USER_HERE MY_ZABBIX_PASSWORD_HERE

# Get AUTH Token
api=`curl -s -q -u HTTP_LOGIN:HTTP_PASS -i -X GET -H 'Content-Type:application/json' -d'{
"jsonrpc": "2.0",
"method": "user.login",
"params": {
             "user": "MY_ZABBIX_USER_HERE",
             "password": "MY_ZABBIX_PASSWORD_HERE"
},
"id": 1
}' http://zabbix2.dultonmedia.com/api_jsonrpc.php`

APIAuth=`echo "$api" | grep result | json_reformat | grep result | awk '{print $2}' | sed 's/[",]//g'`

##echo APIAuth = $APIAuth

# trigger.get
#      "selectGroups":"extend",
#      "selectFunctions": "extend",
request=`curl -s -q -u HTTP_LOGIN:HTTP_PASSWORD -i -X GET -H 'Content-Type:application/json' -d'{
"jsonrpc": "2.0",
"method": "trigger.get",
"params": {
      "output":"extend",
      "monitored":"true",
      "min_severity":"1",
      "selectHosts":"extend",
      "selectLastEvent":"extend",
      "maintenance":"false",
      "filter":{ "value":"1" }
},
"id": 1,
"auth": "'$APIAuth'"
}' http://zabbix2.dultonmedia.com/api_jsonrpc.php`
##echo " === processing 0 === result"
result=`echo "$request" | grep result | json_reformat`

echo "$result"

