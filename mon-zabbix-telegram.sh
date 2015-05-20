#!/bin/bash -e

# ToDO: v1.0 with out checks
# Готовность
#  + получить данные и путь к данным (Zabbix API: 2.2.9)
#     - проверка работоспособности zabbix API
#  + рассортировать блоками (triggerid,eventid,etc)
#  + распарсить отдельно triggerid":|"eventid":|"description":|"url":|"hostid":|"host
#  - работаем с SQL
#     + добавить event SQL в trigget_id
#     + добавить статусы event SQL в priority
#        + таблица ID-priority-host
#        + хранить все данные соотвтетствия триггеров-хостов и их приоритетов
#     - добавить временную таблицу
#  + отправить в telegram
#  + если "новые_данные_нет"
#    + проверить приоритет аларма
#      - если приоритет HIGH/MAX - алармить
#      - если LOW/MIN - промолчать
#  - проверка базы SQL
#    - вывалиться с эксепшеном, если нет пользователя
#    - залить БД, если нету
#  + добавить новое событие
#    + установить приоритет 4 событию
#  - проверить приоритет события
#     - новое (приортиет 4) + аларм
#  + аларм в телегу
#     - алармить одним сообщением
#
# ToDO2: написать добавлялку/убиралку алармов из теблицы приоритетов

# Переменные программы:
# Параметры DB
DBuser=zabbixmon
DBpass=zabbixmon
DBname=zabbixmon
DBhost=127.0.0.1
# путь и имя скрипта с запросом в Zabbix API для получения сырых данных
zabbixapi="../zabbix/api/api.sh"

# telegram.me
# вреенный файл для отправки многострочного сообщения в telegram
TMPFILE=/tmp/tg-cli.txt
TGCLIPATH=/data/Programs/Telegram-bot/tg/bin/telegram-cli
TGCLIPARAM="-C -R -D -E -l 0 -k /data/Programs/Telegram-bot/telegram-bot/tg/server.pub"
# отправлять персонально user#51218806 или в группу chat#23467410
TGDEST='chat#23467410'

#  таблица приоритетов:
#  0-reserverd
#  1-ignore - не алармить
#  2-low - алармить каждый 4 раз
#  3-reserverd
#  4-normal - алармить, если новое и переводить в 2-low
#  5-HIGH - алармить каждый раз
#  6-MAX - алармить каждый раз
#  7-reserverd
#  8-disaster - ппц
#  9-reserverd

#  таблица TMP:
#   triggerid < main (он же ID события)
#   description
#   url
#   priority (zabbix_priority)
#   comments
#   templateid
#     hosts:
#       hostid
#       host < main
#         lastEvent:
#           eventid < main
#           objectid

# анализируем уровень триггера
alarming_subsystem() {
  if [ $TRIGGERPRIORITY = "2" ]; then
    true
  fi
  # Ленивая оповещалка (алармим каждое 25 срабатывание)
  if [ $TRIGGERPRIORITY = "3" ]; then
     # Проверить счётчик, если 1, то
     if [ $TRIGGERCOUNT = "1" ]; then
        # выставить счётчик count в 25
        echo 'UPDATE priority SET count = "25" WHERE triggerid = '$triggerid'' | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname
        # Алармить
        send_alarm_to_telegram
     else
        # Уменьшить счётчик на 1
        newtc=$(expr $TRIGGERCOUNT - 1)
        #echo newtc=$newtc
        echo 'UPDATE priority SET count = '$newtc' WHERE triggerid = '$triggerid'' | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname
     fi
  fi
  # Стандартная оповещалка (алармим каждое 4 срабатывание)
  if [ $TRIGGERPRIORITY = "4" ]; then
     # Проверить счётчик, если 1, то
     if [ $TRIGGERCOUNT = "1" ]; then
        # выставить счётчик count в 5
        echo 'UPDATE priority SET count = "5" WHERE triggerid = '$triggerid'' | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname
        # Алармить
        send_alarm_to_telegram
     else
        # Уменьшить счётчик на 1
        newtc=$(expr $TRIGGERCOUNT - 1)
        #echo newtc=$newtc
        echo 'UPDATE priority SET count = '$newtc' WHERE triggerid = '$triggerid'' | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname
     fi
  fi
  if [ $TRIGGERPRIORITY = "5" ]; then
    send_alarm_to_telegram
  fi
  if [ $TRIGGERPRIORITY = "6" ]; then
    send_alarm_to_telegram
  fi
}

# отправляем аларм в телеграм
send_alarm_to_telegram() {
  # перед отправкой многострочного сообщения в телеграм необходимо его записать в файл
  echo -e "EVENT:$eventid:TRIGGER:$triggerid:PRIO:$TRIGGERPRIORITY\nHOST: $host\nDESCR: $description\nURL: $url" > $TMPFILE
  $TGCLIPATH $TGCLIPARAM -e "send_text $TGDEST $TMPFILE" > /dev/null
}

# определяем приоритет триггера и счётчик события
check_priority() {
  TRIGGERPRIORITY=$(echo "SELECT priority FROM priority WHERE triggerid=$triggerid" | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname)
  TRIGGERCOUNT=$(echo "SELECT count FROM priority WHERE triggerid=$triggerid" | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname)
}

# сверить: "новое_событыие_да", "новое_событие_нет"
check_is_it_new_event() {
  CHECKNEW=`echo "SELECT eventid FROM trigger_id WHERE eventid=$eventid" | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname`
  # echo check_is_it_new_event CHECKNEW=$CHECKNEW
  # "новый_да"
  if [ -z $CHECKNEW ]; then
    # добовляем новое событие
    EVENTEXIST=0
    echo 'INSERT INTO `'$DBname'`.`trigger_id` (`triggerid`, `eventid`, `description`, `url`, `hostid`, `host`) VALUES '"("\'$triggerid\', \'$eventid\', \'$description\', \'$url\', \'$hostid\', \'$host\'");" | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname
    # проверяем существование триггера на новое событие
    CHECKNEWTRIGGER=$(echo "SELECT triggerid FROM priority WHERE triggerid=$triggerid" | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname)
    if [ -z $CHECKNEWTRIGGER ]; then
       TRIGGERPRIORITY=4
       TRIGGERCOUNT=4
      echo 'INSERT INTO `'$DBname'`.`priority` (`triggerid`, `eventid`, `priority`, `count`) VALUES '"("\'$triggerid\', \'reserved\', \'4\', \'4\'");" | MYSQL_PWD=$DBpass mysql -s -h$DBhost -u$DBuser $DBname
    fi
  else
    # Если есть событие то взять TRIGGERPRIORITY и TRIGGERCOUNT
    # check_priority
    EVENTEXIST=1
  fi
}

## получить данные и положить во временную таблицу
## GET raw DATA
getrawdata() {
  result=$($zabbixapi)
  # список событий
  TGList=$(echo "$result" | egrep '("triggerid":|"eventid":|"description":|"url":|"hostid":|"host":)' | sed 's/[",]//g' | cat | awk '{ if ($1=="triggerid:") {print $2} }')
  # убрать лишее
  datasrc=`echo "$result" | egrep '("triggerid":|"eventid":|"description":|"url":|"hostid":|"host":)' | sed 's/[",]//g' | sed 's/  //g'`
}


## echo "=== MAIN start ==="
## MAIN start
mainprogram() {

  getrawdata

  for i in $TGList; do
    # распарсили данные
    sorted=`echo "$datasrc" | sed -n "/^triggerid: $i/,/^eventid:/p" | sed 's/: /=/g' | sed 's/ /_/g'`
    for str in `echo "$sorted" | sed 's/^ *//' | egrep -v '^$|^#'`; do
        eval $(echo "$str"|sed 's/ *=/=/;s/= */=/');
    done
    if [ -z $url ]; then url=none ; fi

#    echo "     === DEBUG ===
#           triggerid $triggerid
#           description $description
#           url $url
#           hostid $hostid
#           host $host
#           eventid $eventid
#         "

    # Проверяем на "новое_событие" и поределяем приоритет
    check_is_it_new_event

    # берём приоритет события и счётчик события
    if [ $EVENTEXIST = "0" ]; then
       # событие новое
       send_alarm_to_telegram
    else
       # событие не новое
       # берём из таблицы приоритет триггера(TRIGGERPRIORITY) и счётчик события(TRIGGERPRIORITY)
       check_priority
    fi

  # анализируем алармы и отправляем алярмы
  alarming_subsystem

  done
}

mainprogram

