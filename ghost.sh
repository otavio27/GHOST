#!/usr/bin/env bash

#===============================================================#
# GHOST, programa de scanner de portas e varredura em rede.
# Este programa usa de comandos específicos do Nmap, Bully e
# Reaver para realizar suas tarefas.
#===============================================================#
#===============================================================#
# ghost.sh
#
# Autor: Otávio Will
# Email: <owtechdeveloper@gmail.com>
# GitHub: https://github.com/otavio27/GHOST
# License: https://www.gnu.org/licenses/gpl-3.0.txt GNU GENERAL PUBLIC LICENSE
#================================================================#
# progressbar.sh
#
# Autor: Robson Alexandre
# Email: <alexandrerobson@gmail.com>
# GitHub: https://github.com/robsonalexandre/progressbar
# License: https://www.gnu.org/licenses/gpl-3.0.txt GNU GENERAL PUBLIC LICENSE
#===============================================================#

#===============================================================#
# Resize do terminal corrente
#===============================================================#
ID=$(xdotool getactivewindow)
xdotool windowsize --usehints ${ID} 78 38
#===============================================================#

readonly APP=$(readlink -f "${BASH_SOURCE[0]}")
readonly APP_PATH=${APP%/*}
version="Versão: 3.0"

# Colors
Br="\e[37;1m"
Rd="\e[31;1m"
Red="\e[31;1;5m"
Vd="\e[32;1m"
Cy="\e[0;36m"
Fm="\e[0m"

source "$APP_PATH/logos.sh"
source "$APP_PATH/messages.sh"
source "$APP_PATH/ProgressBar.sh"

log="$APP_PATH/ghost-log.txt"

#===============================================================#
# Verifica se o usuário está logado como root
#===============================================================#
CheckRoot() {

  clear

  if [[ $EUID -ne 0 ]]; then
    printf "%b\n" ${Vd}"\nPARA EXECUTAR ESSE PROGRAMA, RODE${Fm} ${Rd}sudo ./ghost"${Fm}
    printf "%b\n" ${Red}"\nNÃO É POSSIVEL EXECUTAR SEM SUDO..."${Fm}
    sleep 1s && exit 1
  else
    printf "%b\n" ${Rd}"\n\t\t======[${Br}STARTANDO O PROGRAMA AGUARDE!${Rd}]======"${Fm}
    sleep 1s
  fi
}

#=================================================================#
# Verifica se existem dependências, e instala se nescessário.
#=================================================================#
CheckDependencies() {

  deps=(
    "nmap" "ipcalc" "net-tools" "git" "pixiewps" "xdotool" "fzf"
    "build-essential" "libpcap-dev" "aircrack-ng" "reaver" "ethtool"
  )

  declare -a missing

  for d in "${!deps[@]}"; do
    [[ -z $(sudo dpkg -l "${deps[$d]}" 2>/dev/null) ]] && missing+=(${deps[$d]})
  done

  if [[ ${#missing[@]} -ne 0 ]]; then
    printf "%b\n" ${Rd}"\n\tFALTAM AS DEPENDÊNCIAS:${Fm}${Cy} ${missing[@]}"${Fm}
    read -p $'\e[1;31m\n\t\tINSTALAR AS DEPENDÊNCIAS?\nR: \e[m' RES
    if [[ "${RES,,}" == @(s|sim) ]]; then
      sudo apt update -qq && sudo apt install ${missing[@]} -y -qq
      printf "%b\n" ${Vd}"\n\t\tTODAS AS DEPENDÊNCIAS FORAM INSTALADAS"${Fm}
      sleep 1s && Menu
    elif [[ "${RES,,}" == @(n|não) ]]; then
      printf "%b\n" ${Rd}"\n\t\tNÃO É POSSÍVEL PROSSEGUIR SEM INSTALAR AS DEPENDÊNCIAS"${Fm}
      sleep 3s && Thanks
    else
      printf "%b\n" ${Rd}"\n\t\tNÃO FOI POSSÍVEL INSTALAR AS DEPENDÊNCIAS ${missing[@]}"${Fm}
    fi
  else
    printf "%b\n" ${Vd}"\n\t\t  NÃO HÁ DEPENDÊNCIAS A SEREM INSTALADAS"${Fm}
    sleep 1s
  fi
}

LinePrint() {

  LINE=$(printf '%*s' "${columns:-$(tput cols)}" | tr ' ' "=")
  printf '%b\n' "${Rd}${LINE}${Fm}\n"
}

Retorno() {

  printf "%b\n" ${Rd}"\nRETORNAR PARA: NMAP${Fm}${Br} [N]${Fm}${Rd} WIFICRACK${Fm}${Br} [W]${Fm} ${Rd} MENU${Fm}${Br} [M]${Fm}"
  read -p $'\e[1;37mR: \e[m' RES
  case ${RES^^} in
    N)
      LAN=($(sudo ifconfig | grep 'wl' | awk '{print $1}'))
      sudo airmon-ng stop ${LAN%%:*} >/dev/null
      printf "%b\n" ${Rd}"\nRETORNANDO..."${Fm} && sleep 2s && MenuNmap
      ;;
    W)
      printf "%b\n" ${Rd}"\nRETORNANDO..."${Fm} && sleep 2s && MenuWificrack
      ;;
    M)
      printf "%b\n" ${Rd}"\nRETORNANDO..."${Fm} && sleep 2s && Menu
      ;;
  esac
}

Thanks() {

  printf "%b\n" ${Rd}"\nSAINDO...${Vd}\n\nOBRIGADO POR USAR O GHOST..."${Fm}
  sleep 2s && clear && exit
}

Exit() {

  if [[ -e $log ]]; then
    printf "%b\n" ${Rd}"\nEXCLUIR O ARQUIVO ${Cy}${log##*/}${Fm}${Rd}?${Fm}${Rd} [${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
    read -p $'\e[1;37mR: \e[m' RES
    if [[ "${RES}" == @(s|S) ]]; then
      sudo rm -rf "$log" && printf "%b\n" ${Vd}"\nARQUIVO EXCLUIDO COM SUCESSO!"${Fm} && Thanks
    else
      Thanks
    fi
  else
    printf "%b\n" ${Vd}"\nNÃO HÁ ARQUIVO DE LOG A SER EXCLUIDO!"${Fm} && Thanks
  fi
  clear
}

OptionExit() {

  printf "%b\n" ${Rd}"\nDESEJA SAIR DO GHOST?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\e[1;37mR: \e[m' RES
  [[ "${RES}" == @(n|N) ]] && Retorno || Exit
}

OpenLog() {

  tput cnorm -- normal
  printf "%b\n" "${Rd}\nABRIR O ARQUIVO${Fm}${Cy} ${log##*/}?${Fm} ${Rd}[${Fm}${Br}S/N${Rd}]${Fm}\n${Fm}R: ${Fm}"
  read RES
  [[ "${RES,,}" == @(s|sim) ]] && cat "$log" || Retorno
  printf "%b\n" ${Rd}"RETORNAR?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\e[1;37mR: \e[m' RES
  [[ "${RES}" == @(s|S) ]] && Retorno || Exit
}

ProgressBar() {
  #/**
  # * O comando sed formatará a saída de nmap --stats-every para o seguinte:
  # * "[0-9]+ Mensagem de texto"
  #**/
  sed -u -n -r '/About/s/([^:]+): About ([0-9]+).[0-9]+%.*/\2 \1/p' - | "$APP_PATH/ProgressBar.sh" -z
}

Nmap() {

  case ${dig} in
    1) NMAP_OPT="-f -sS -vv -T4 -Pn" ;;
    2) NMAP_OPT="-O -vv -Pn" ;;
    3) NMAP_OPT="-sS -sV -vv -O -T4 -Pn" ;;
    4) NMAP_OPT="-sS -vv -Pn -p $port" ;;
    5) NMAP_OPT="--script=mysql-brute " ;;
    6) NMAP_OPT="-sS -v -Pn -A --open --script=vuln" ;;
    7) NMAP_OPT="--script=asn-query,whois-ip,ip-geolocation-maxmind" ;;
    8) NMAP_OPT="-sU -A -PN -n -pU:19,53,123,161 --script=ntp-monlist,dns-recursion,snmp-sysdescr" ;;
    9) NMAP_OPT="--mtu 32" ;;
    10) NMAP_OPT="-v -sT -PN --spoof-mac 0" ;;
    11) NMAP_OPT="-sU" ;;
    12) NMAP_OPT="-n -D 192.168.1.1,10.5.1.2,172.1.2.4,3.4.2.1" ;;
    13) NMAP_OPT="--script ${OPT} --script-args=unsafe=1" ;;
  esac
  nmap $NMAP_OPT $IP -oN $log --stats-every 1s 2>&- | ProgressBar
}

NmapScanner() {

  clear
  tput civis -- invisible

  LinePrint
  # printf "%b\n" ${Rd}"\n\t\t\t[ ${Fm}${Br}GHOST${Fm}${Rd} ]"${Fm}
  if [[ ${dns} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    printf "%b\n" ${Rd}"\nDISPARANDO SCANNER NO ALVO: >>> [ "${FM}${Cy}"${IP}"${Fm}${Rd}" ]"${Fm}
    printf "%b\n" ${Vd}"\nESTE PROCESSO PODE DEMORAR, AGUARDE ATÉ O FIM."${Fm}
  else
    printf "%b\n" ${Rd}"\nDNS INFORMADO: >>> [ "${FM}${Cy}"${dns}"${Fm}${Rd}" ]"${Fm}
    printf "%b\n" ${Rd}"\nDISPARANDO SCANNER NO IP DO ALVO: >>> [ "${FM}${Cy}"${IP}"${Fm}${Rd}" ]"${Fm}
    printf "%b\n" ${Vd}"\nESTE PROCESSO PODE DEMORAR, AGUARDE ATÉ O FIM."${Fm}
  fi
  LinePrint

  Nmap ${dig}
}

Mask() {

  mask=$(ipcalc --class ${ip})

  if [[ "${mask}" = "invalid" ]]; then
    printf "%b\n" ${Rd}"\nO [ ${Fm}${Br}${ip}${Fm}${Rd} ] É UM IP INVÁLIDO!!!"${Fm}
    read -p $'\e[1;31m\nDIGITE UM IP VÁLIDO!.\nR: \e[m' ip && Mask
  else
    case ${mask} in
      [0-9] | [0-9][0-9]) # Metodo usado para suprir a nescessidade de colocar número ao lado de número.
        IP="${ip}/${mask}" && NmapScanner ${IP} ;;
      *) OptionExit ;;
    esac
  fi
  OpenLog
}

FullRange() {

  IFS='.' read C1 C2 C3 C4 <<<${ip}

  while :; do

    for X in {1..255}; do
      IP=$"$C1.${C2//*/$X}.${C3//*/0}.${C4//*/1}"
      NmapScanner ${IP} continue
    done
    for Y in {1..255}; do
      IP=$"$C1.${C2//*/$X}.${C3//*/$Y}.${C4//*/1}"
      NmapScanner ${IP} continue
    done
    for Z in {1..255}; do
      IP=$"$C1.${C2//*/$X}.${C3//*/$Y}.${C4//*/$Z}"
      NmapScanner ${IP} continue
    done
    break
  done
}

IPF() {

  [[ ${dig} -eq 4 ]] && read -p $'\e[1;31m\nDIGITE A PORTA OU PORTAS. Ex: 22 ou 22,80,443\nR: \e[m' port
  read -p $'\e[1;31m\nDIGITE SOMENTE O IP, OU URL.\nR: \e[m' dns

  if [[ "${dns}" =~ ^[[:alpha:]] ]]; then
    # Converte toda a URL passada, em IP
    read _ _ _ IP <<<$(host ${dns} | grep "address")
    if [[ ${IP} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      NmapScanner ${dig} && OpenLog
    else
      printf "%b\n" ${Rd}"\nO [ ${Fm}${Br}${dns}${Fm}${Rd} ] É INVÁLIDO!!!"${Fm} && IPF
    fi
  else
    # Tomada de decisão com responsabilidade de validação de IP
    if [[ ${dns} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      IP="${dns}" && NmapScanner ${dig} && OpenLog
    else
      printf "%b\n" ${Rd}"\nO [ ${Fm}${Br}${dns}${Fm}${Rd} ] É UM IP INVÁLIDO!!!"${Fm} && IPF
    fi
  fi
}

Rede() {

  read -p $'\e[1;31m\nDIGITE O IP OU URL.\nR: \e[m' dns
  [[ ${dig} -eq 4 ]] && read -p $'\e[1;31m\nDIGITE A PORTA OU PORTAS. Ex: 22 ou 22,80,443\nR: \e[m' port

  if [[ "${dns}" =~ ^[[:alpha:]] ]]; then
    read _ _ _ ip <<<$(host ${dns} | grep "address") # Converte toda a URL passada, em IP
    read -p $'\e[1;31m\nESCANEAR EM MODO FULL-RANGE?\nESTE MODO FAZ UM SCANNER DO XXX.0.0.1 ATÉ XXX.255.255.255\nR: \e[m' RES
    if [[ "${RES,,}" == @(s|sim) ]]; then
      FullRange && OpenLog
    else
      Mask
    fi
  else
    # Tomada de decisão com responsabilidade de validação de IP
    if [[ ${dns} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      ip="${dns}"
      read -p $'\e[1;31m\nESCANEAR EM MODO FULL-RANGE?\nESTE MODO FAZ UM SCANNER DO XXX.0.0.1 ATÉ XXX.255.255.255.\nR: \e[m' RES
      if [[ "${RES,,}" == @(s|sim) ]]; then
        FullRange && OpenLog
      else
        Mask
      fi
    else
      printf "%b\n" ${Rd}"\nO [ ${Fm}${Br}${dns}${Fm}${Rd} ] É UM IP INVÁLIDO!!!"${Fm} && Rede
    fi
  fi
}

Ghost() {

  case ${dig} in

    [1-9] | [0-9][0-9]) # Metodo usado para suprir a nescessidade de colocar numero ao lado de número.
      if [[ ${dig} -ge 14 ]]; then
        printf "%b\n" "${Rd}\nOPÇÃO INVÁLIDA!!!"${Fim}
        sleep 2s && MenuNmap
      else
        printf "%b\n" ${Rd}"\nESCANEAR IP OU REDE?${Fm}${Br} [I/R]"${Fm}
        printf "%b\n" ${Rd}"\nTODAS AS SAÍDAS SERÃO DIRECIONADAS PARA O ARQUIVO:${Fm}${Cy} $log"${Fm}
        read -p $'\e[1;37mR: \e[m' RES
        [[ "${RES}" == @(i|I) ]] && IPF ${dig} || [[ "${RES}" == @(r|R) ]] && Rede ${dig} || OptionExit
      fi ;;
    0) Exit ;;
    *) OptionExit ;;
  esac
}

ScriptsNmap() {

  sudo nmap --script-updatedb* 2>&-

  cd /usr/share/nmap/scripts/
  OPT=$(fzf --color fg:124,bg:16,hl:202,fg+:214,bg+:52,hl+:231 \
    --reverse -i -e --tiebreak=begin --height=27 
  )
  Ghost ${OPT}
}

MenuNmap() {

  clear
  while true; do

    LinePrint
  
    for X in "${!NMAP[@]}"; do
      printf "%b\n" ${Vd}"\t\t ${NMAP[$X]}"${Fm}
      sleep 0.05s
    done

    printf "%b\n" ${Cy}"                               ${version}${Fm}"

    LinePrint

    dig=$(
      fzf --color fg:124,bg:16,hl:202,fg+:214,bg+:52,hl+:231 \
      --reverse -i -e --tiebreak=begin --height=20 \
      <<<$(for i in "${!nmapwrite[@]}"; do echo "$i-${nmapwrite[$i]}"; done)
    )
    dig="${dig%%-*}"

    case ${dig} in
      0) Menu ;;
      13) ScriptsNmap ;;
      *) Ghost ${dig} ;;
    esac
  done
}

AirmonStop() {

  printf "%b\n" ${Vd}"DESABILITANDO A PLACA DE REDE DO MODO MONITOR"${Fm}
  sleep 2s
  sudo airmon-ng stop ${LAN[$P]%%:*}mon
  Thanks
}

Airmon() {

  clear
  LAN=($(sudo ifconfig | grep 'wl' | awk '{print $1}'))

  printf "%b\n" ${Rd}"\nBUSCANDO PLACAS DE REDE WIRELESS..."${Fm}
  sleep 2s
  printf "%b\n" ${Rd}"\nPLACAS DE REDE WIRELESS DISPONÍVEIS:\n"${Fm}

  for X in "${!LAN[@]}"; do
    printf "%b\n" ${Rd}" [${Cy}$X${Rd}]${Br} ${Vd}${LAN[$X]%%:*}"${Fm}
  done

  read -p $'\e[31;1m\nDIGITE O NÚMERO DA PLACA ESCOLHIDA R: \e[m' P

  printf "%b\n" ${Rd}"\nCOLOCANDO A PLACA WIFI EM MODO MONITOR"${Fm}
  sleep 2s
  sudo airmon-ng start ${LAN[$P]%%:*} >/dev/null && clear
  printf "%b\n" ${Rd}"OBTENDO REDES WIFI DISPONIVEIS, O PROCESSO LEVARÁ ALGUNS SEGUNDOS\n"${Fm}
}

Wash() {

  sudo timeout --preserve-status 30 wash -i ${LAN[$P]%%:*}mon | tee MACS.txt
  MACS=($(cat MACS.txt | grep ':' | awk '{print $1" "$2}'))

  printf "%b\n" ${Rd}"\nESCOLHA UMA REDE PARA ATAQUE\n"${Fm}

  for ((X = 0; X < ${#MACS[@]}; X = X + 2)); do
    printf "%b\n" ${Rd}"[$X] MAC:${Fm} ${Vd}${MACS[$X]}"${Fm}
  done

  read -p $'\e[31;1m\nDIGITE O ÍNDICE DA REDE ESCOLHIDA R: \e[m' I
  printf "%b\n" ${Cy}"\nESTE PROCESSO PODE DEMORAR VÁRIOS MINUTOS\nAGUARDE O FIM DO PROCESSO...\n"${Fm}
}

Bully() {

  Airmon
  Wash
  bully ${LAN[$P]%%:*}mon -b${MACS[$I]} -c${MACS[$I + 1]} -d -A -F -B -l 5
  printf "%b\n" ${Rd}"RETORNAR?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\e[1;37mR: \e[m' RES
  [[ "${RES}" == @(s|S) ]] && Retorno || AirmonStop ${LAN[$P]%%*}mon
}

Reaver() {

  Airmon
  Wash
  reaver -c${MACS[$I + 1]} -b${MACS[$I]} -vv -i ${LAN[$P]%%:*}mon -L -Z -K 1
  printf "%b\n" ${Rd}"RETORNAR?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\e[1;37mR: \e[m' RES
  [[ "${RES}" == @(s|S) ]] && Retorno || AirmonStop ${LAN[$P]%%:*}mon
}

MenuWificrack() {

  clear
  while true; do

    LinePrint

    for X in "${!WIFI[@]}"; do
      printf "%b\n" ${Cy}"\t${WIFI[$X]}"${Fm}
      sleep 0.05s
    done
    
    printf "%b\n" ${Cy}"                               ${version}${Fm}"

    LinePrint

    dig=$(
      fzf --color fg:124,bg:16,hl:202,fg+:214,bg+:52,hl+:231 \
      --reverse -i -e --tiebreak=begin --height=20 \
      <<<$(for i in "${!words[@]}"; do echo "$i-${words[$i]}"; done)
    )
    dig="${dig%%-*}"

    case ${dig} in
      0) Menu ;;
      1) Reaver ;;
      2) Bully ;;
      *)
      printf "%b\n" "${Rd}\nOPÇÃO INVÁLIDA!!!"${Fim}
      sleep 2s && MenuWificrack
      ;;
    esac
  done
}

Menu() {

  clear
  while true; do

    LinePrint

    for X in "${!GHOST[@]}"; do
      printf "%b\n" ${Rd}"\t\t${GHOST[$X]}"${Fm}
      sleep 0.05s
    done

    printf "%b\n" ${Cy}"                               ${version}${Fm}"
    LinePrint

    dig=$(
      fzf --color fg:124,bg:16,hl:202,fg+:214,bg+:52,hl+:231 \
      --reverse -i -e --tiebreak=begin --height=20 \
      <<<$(for i in "${!MenuWords[@]}"; do echo "$i-${MenuWords[$i]}"; done)
    )
    dig="${dig%%-*}"

    case ${dig} in
      0) Exit ;;
      1) MenuNmap ;;
      2) MenuWificrack ;;
      *) printf "%b\n" "${Rd}\nOPÇÃO INVÁLIDA!!!"${Fim} && sleep 2s && Menu ;;
    esac
  done
}
CheckRoot
CheckDependencies
Menu
#=============================================================[FIM]==================================================================#
