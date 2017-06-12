#!/bin/bash
#блок по портам
if [ "$(id -u)" != "0" ]
then
echo "Запуск возможен только с привилегиями root!"
exit 1
fi
nft_list() {
i=1
for ip in $(nft list ruleset -a | grep -E 'ip saddr.*reject comment \"snft_ban.*' | grep -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}')
do
if [[ "$i" = 1 ]]
then
echo "Список заблокированных IP-адресов:"
fi
echo $i: $ip
let i=i+1
done
if [[ -z "$ip" ]]
then
echo "Заблокированных IP-адресов нет."
fi
}
nft_block() {
if [[ -z $2 ]]
then
read -e -p "Введите через пробел список IP-адресов, которые необходимо заблокировать: " iplist
shift $#
else
while [[ ! ${1} =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]] && [[ -n "$1" ]]
do
shift
done
fi
for ip in $iplist ${@}
do
if [[ -n "$ip" ]] && [[ $ip =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]] && [[ $ip != $(nft list ruleset -a | grep -E 'ip saddr.*reject comment \"snft_ban.*' | grep -o $ip | uniq) ]]
then
nft insert rule inet filter input ip saddr $ip reject comment "snft_ban"
if [[ "$?" = 0 ]]
then
echo "IP-адрес $ip заблокирован."
else
echo "Произошла внутренняя ошибка при блокировке IP-адреса $ip. Вероятнее всего, у пользователя недостаточно прав."
break
fi
elif [[ -n "$ip" ]] && [[ ! $ip =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]]
then
echo "Ошибка! $ip не является IP-адресом."
elif [[ -n "$ip" ]] && [[ $ip =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]] && [[ $ip = $(nft list ruleset -a | grep -E 'ip saddr.*reject comment \"snft_ban.*' | grep -o $ip | uniq) ]]
then
echo "IP-адрес $ip уже заблокирован"
fi
done
if [[ -z "$ip" ]]
then
echo "Вы не ввели IP-адрес. Попробуйте еще раз."
fi
}
nft_unblock() {
if [[ -z $2 ]]
then
read -e -p "Введите через пробел список IP-адресов, которые необходимо разблокировать: " iplist
shift $#
else
while [[ ! ${1} =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]] && [[ -n "$1" ]]
do
shift
done
fi
for ip in $iplist ${@}
do
if [[ -n "$ip" ]] && [[ $ip =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]] && [[ $ip = $(nft list ruleset -a | grep -E 'ip saddr.*reject comment \"snft_ban.*' | grep -o $ip | uniq) ]]
then
for handle in $(nft list ruleset -a | grep $ip | grep -o 'handle.*' | sed 's/handle //')
do
nft delete rule inet filter input handle $handle
done
if [[ "$?" = 0 ]]
then
echo "IP-адрес $ip разблокирован."
else
echo "Произошла внутренняя ошибка при разблокировке IP-адреса $ip. Вероятнее всего, у пользователя недостаточно прав."
break
fi
elif [[ -n "$ip" ]] && [[ ! $ip =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]]
then
echo "Ошибка! $ip не является IP-адресом."
elif [[ -n "$ip" ]] && [[ $ip =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]] && [[ $ip != $(nft list ruleset -a | grep -E 'ip saddr.*reject comment \"snft_ban.*' | grep -o $ip | uniq) ]]
then
echo "IP-адрес $ip не является заблокированным."
fi
done
if [[ -z "$ip" ]]
then
echo "Вы не ввели IP-адрес. Попробуйте еще раз."
fi
}
nft_resetrules() {
while (( ${#} ))
do
if [[ "${1}" == "-f" || "${1}" == "--force" ]]
then
force=1
elif [[ "${1}" == "-b" || "${1}" == "--block" ]]
then
rule=snft_ban
elif [[ "${1}" == "-ba" || "${1}" == "--block-all" ]]
then
rule=snft_blockall
elif [[ "${1}" == "-d" || "${1}" == "--ddos" ]]
then
rule=snft_ddosblock
elif [[ "${1}" == "-a" || "${1}" == "--all" ]]
then
rule=snft_
fi
shift
done
if [[ -z "$rule" ]]
then
read -e -p "Выберите тип удаляемых правил: 
b   - удалить правила с заблокированными вручную IP-адресами,
ba  - удалить правило blockall,
d   - удалить правила, созданные параметром ddos,
a   - удалить все правила snft
Ваш выбор: " rule
case "$rule" in
    b)  
        rule=snft_ban
        ;;
    ba)  
        rule=snft_blockall
        ;;
    d)  
        rule=snft_ddosblock
        ;;
    a)  
        rule=snft_
        ;;
    *)
        echo "Не выбран тип удаляемых правил, ничего не было удалено!"
        exit 1
        ;;
esac
fi
if  [[ -z "$force" ]]
then
read -e -p "Вы уверены?: 
y     - да,
enter - завершить работу, 
Ваш выбор: " item
case "$item" in
    y)  
        ;;
    *)
        exit 1
        ;;
esac
fi
for handle in $(nft list ruleset -a | grep -E "comment \"$rule*" | grep -o 'handle.*' | sed 's/handle //')
do
nft delete rule inet filter input handle $handle
if [[ "$?" = 0 ]]
then
echo "Правило №$handle удалено."
else
echo "Произошла внутренняя ошибка при удалении правила $handle. Вероятнее всего, у пользователя недостаточно прав."
break
fi
done
if [[ -z "$handle" ]]
then
echo "Правил, созданных с помощью snf, нет."
fi
}
nft_blockall() {
while (( ${#} ))
do
if [[ "${1}" == "-f" || "${1}" == "--force" ]]
then
force=1
fi
shift
done
if  [[ -z "$force" ]]
then
read -e -p "Вы уверены?: 
y     - да,
enter - завершить работу, 
Ваш выбор: " item
case "$item" in
    y)  
        ;;
    *)
        exit 1
        ;;
esac
fi
nft insert rule inet filter input drop comment "snft_blockall"
nft insert rule inet filter input iifname lo accept comment "snft_blockall"
nft insert rule inet filter input ct state {established, related} accept comment "snft_blockall"
for ip in $(pinky | grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}(:[0-9]{1,5})?" | uniq)
do
nft insert rule inet filter input ip saddr $ip accept comment "snft_blockall"
done
echo "Готово. В настоящий момент заблокированы соединения со всех IP, кроме вашего."
}
nft_ddos() {
while (( ${#} ))
do
if [[ "${1}" = "-f" || "${1}" = "--force" ]]
then
force=1
elif [[ "${1}" =~ ^[1-9][0-9]*$ ]]
then
max=${1}
fi
shift
done
if [[ -z "$max" ]]
then
while [[ -z "$max" ]]
do
read -e -p "Введите порог соединений с IP-адресом, выше которого IP-адрес считается атакующим: " -i "30" max
if [[ ! "$max" =~ ^[1-9][0-9]*$ ]]
then
unset max
echo "Ошибка! Вы не ввели или ввели неверный порог соединений. Допустимые значения: [2-∞]"
fi
done
fi
for ip in $(netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}")
do
count=$(netstat -ntu | awk '{print $5}' | grep "$ip" | wc -l)
if [[ "$count" -ge "$max" && "$ip" -ne "127.0.0.1" && "$ip" -ne "8.8.8.8" && "$ip" -ne "8.8.4.4" ]]
then
if [[ -z "$force" ]]
then
if [[ -z "$attack" ]]
then
attack=0
fi
read -e -p "$count соединени(я|й) с $ip. Заблокировать данный IP?
y     - да,
enter - пропустить,
Ваш выбор: " item
case "$item" in
    y)  
        ;;
    *)  continue
        ;;
esac
#else
# Дополнительный скрипт для отправки сообщений при обнаружении атаки в автоматическом (force) режиме.
#if [ -f "/etc/sh/telegram.sh" ]
#then
#sh /etc/sh/telegram.sh "Обнаружена атака на $(uname -n). Заблокирован IP $ip"
#fi
fi
let attack=attack+1
nft insert rule inet filter input ip saddr $ip reject comment "snft_ddosblock"
if [[ "$?" = 0 ]]
then
echo "IP-адрес $ip заблокирован."
else
echo "Произошла внутренняя ошибка при блокировке IP-адреса $ip. Вероятнее всего, у пользователя недостаточно прав."
fi
fi
done
if [[ -z "$attack" ]]
then
echo "IP-адресов, с которыми установлено больше $max соединений, нет."
else
echo "Работа завершена, всего заблокировано $attack адрес(а|ов)."
fi
}
nft_help() {
echo "Использование: snft [команда] [параметры]
Доступные команды:
    -b,  --block          заблокировать IP-адрес,
         [IP-адрес1] [IP-адрес2] ...
    -u,  --unblock        разблокировать IP-адрес,
         [IP-адрес1] [IP-адрес2] ...
    -ba, --block-all      заблокировать все соединения, кроме текущего IP,
         -f, --force      не запрашивать подтверждение для действий,
    -d,  --ddos           найти и заблокировать соединения с IP-адресами, с которыми превышено указанное количество соединений,
         -f, --force      не запрашивать подтверждение для действий,
         [2-∞]            количество соединений с IP-адресом, выше которого IP-адрес считается атакующим,
    -l,  --list           список заблокированных IP-адресов,
    -rr, --reset-rules    сбросить правила snft,
         -f, --force      не запрашивать подтверждение для действий,
         -b, --block      удалить правила с заблокированными вручную IP-адресами,
         -ba, --block-all удалить правило blockall,
         -d,  --ddos      удалить правила, созданные параметром ddos,
         -a,  --all       удалить все правила snft
    -h,  --help         показать данную справку.
"
}
nft_menu() {
echo "Меню управления nft. Выберите действие: 
b   - заблокировать IP-адрес,
u   - разблокировать IP-адрес,
ba  - заблокировать все соединения, кроме текущего IP,
d   - найти и заблокировать соединения с IP-адресами, с которыми превышено указанное количество соединений,
l   - список заблокированных IP-адресов,
rr  - сбросить правила snft,
q   - завершить работу."
read -e -p "Ваш выбор: " menu
case "$menu" in
    b)
nft_block
;;
    u)
nft_unblock
;;
    l)
nft_list
;;
    rr)
nft_resetrules
;;
    ba)
nft_blockall
;;
    d)
nft_ddos
;;
    q)
exit 0
;;
    *)
nft_menu
;;
esac
}
nft_param() {
case "${1}" in
    -b|--block)
nft_block ${@}
;;
    -u|--unblock)
nft_unblock ${@}
;;
    -l|--list)
nft_list
;;
    -rr|--reset-rules)
nft_resetrules ${@}
;;
    -ba|--block-all)
nft_blockall ${@}
;;
    -d|--ddos)
nft_ddos ${@}
;;
    -h|--help)
nft_help
;;
    *)
echo "Ошибка, задан неверный параметр!"
nft_help
;;
esac
}
if [[ -z "${@}" ]]
then
nft_menu
else
nft_param ${@}
fi
