#!/bin/bash

# DEBUG очистка таблиц

# Переменные программы:
# Параметры DB
DBuser=zabbixmon
DBpass=zabbixmon
DBname=zabbixmon
DBhost=127.0.0.1


echo 'TRUNCATE TABLE `priority`' | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname
echo 'TRUNCATE TABLE `trigger_id`' | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname

