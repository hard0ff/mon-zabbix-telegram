#!/bin/bash -e

# установка приоритета в таблице


exitwitherror() {
  echo "Missing params: $0 <trigger_id> <new_priority>"
  exit 1
}

if [ -z $1 ]; then
exitwitherror
else
  if [ -z $2 ]; then
    exitwitherror
  fi
fi



# Переменные программы:
# Параметры DB
DBuser=zabbixmon
DBpass=zabbixmon
DBname=zabbixmon
DBhost=127.0.0.1


chechexist=$(echo 'SELECT triggerid FROM priority WHERE triggerid = '$1'' | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname)
if [ -z $chechexist ]; then
   echo Trigger $1 NOT FOUND
   exit 1
fi

echo 'UPDATE priority SET priority = "'$2'" WHERE triggerid = '$1'' | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname

echo DONE
