#!/bin/bash
#блок по портам
if [ "$(id -u)" != "0" ]
then
echo "Запуск возможен только с привилегиями root!"
exit 1
fi
nft_list() {
i=1
for ip in $(nft list ruleset -a | grep -E 'ip saddr.*reject' | grep -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}')
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
if [[ -n "$ip" ]] && [[ $ip =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]] && [[ $ip != $(nft list ruleset -a | grep -E 'ip saddr.*reject' | grep -o $ip | uniq) ]]
then
nft insert rule inet filter input ip saddr $ip reject
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
elif [[ -n "$ip" ]] && [[ $ip =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]] && [[ $ip = $(nft list ruleset -a | grep -E 'ip saddr.*reject' | grep -o $ip | uniq) ]]
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
if [[ -n "$ip" ]] && [[ $ip =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]] && [[ $ip = $(nft list ruleset -a | grep -E 'ip saddr.*reject' | grep -o $ip | uniq) ]]
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
elif [[ -n "$ip" ]] && [[ $ip =~ (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3} ]] && [[ $ip != $(nft list ruleset -a | grep -E 'ip saddr.*reject' | grep -o $ip | uniq) ]]
then
echo "IP-адрес $ip не является заблокированным."
fi
done
if [[ -z "$ip" ]]
then
echo "Вы не ввели IP-адрес. Попробуйте еще раз."
fi
}
nft_unblockall() {
while (( ${#} ))
do
if [[ "${1}" == "-f" || "${1}" == "--force" ]]
then
break
elif  [[ -z "${2}" ]]
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
shift
done
for ip in $(nft list ruleset -a | grep -E 'ip saddr.*reject' | grep -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}')
do
for handle in $(nft list ruleset -a | grep $ip | grep -o 'handle.*' | sed 's/handle //')
do
nft delete rule inet filter input handle $handle
if [[ "$?" = 0 ]]
then
echo "IP-адрес $ip разблокирован."
else
echo "Произошла внутренняя ошибка при разблокировке IP-адреса $ip. Вероятнее всего, у пользователя недостаточно прав."
break
fi
done
done
if [[ -z "$ip" ]]
then
echo "Заблокированных IP-адресов нет."
fi
}
nft_blockall() {
while (( ${#} ))
do
if [[ "${1}" == "-f" || "${1}" == "--force" ]]
then
break
elif  [[ -z "${2}" ]]
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
shift
done
nft insert rule inet filter input drop
for ip in $(pinky | grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}(:[0-9]{1,5})?" | uniq)
do
nft insert rule inet filter input ip saddr $ip accept
done
echo "Готово. В настоящий момент заблокированы все соединения, кроме вашего."
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
if [[ "$count" -ge "$max" ]]
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
fi
let attack=attack+1
nft insert rule inet filter input ip saddr $ip reject
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
    -b,  --block        заблокировать IP-адрес,
         [IP-адрес1] [IP-адрес2] ...
    -u,  --unblock      разблокировать IP-адрес,
         [IP-адрес1] [IP-адрес2] ...
    -l,  --list         список заблокированных IP-адресов,
    -ua, --unblock-all  разблокировать все IP-адреса из списка заблокированных,
         -f, --force    не запрашивать подтверждение для действий,
    -ba, --block-all    заблокировать все соединения, кроме текущего IP,
         -f, --force    не запрашивать подтверждение для действий,
    -d,  --ddos         найти и заблокировать соединения с IP-адресами, с которыми превышено указанное количество соединений,
         -f, --force    не запрашивать подтверждение для действий,
         [2-∞]          количество соединений с IP-адресом, выше которого IP-адрес считается атакующим,
    -h,  --help         показать данную справку.
"
}
nft_menu() {
echo "Меню управления nft. Выберите действие: 
b   - заблокировать IP-адрес,
u   - разблокировать IP-адрес,
l   - список заблокированных IP-адресов,
ua  - разблокировать все IP-адреса из списка заблокированных,
ba  - заблокировать все соединения, кроме текущего IP,
d   - найти и заблокировать соединения с IP-адресами, с которыми превышено указанное количество соединений,
r   - перезагрузить службы nft и fail2ban (сбросить ручные правила),
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
    ua)
nft_unblockall
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
    -ua|--unblock-all)
nft_unblockall ${@}
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
