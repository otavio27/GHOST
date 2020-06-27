#!/usr/bin/env bash

#===============================================================#
# GHOST, programa de scanner de portas e varredura em rede.
# Este programa usa de comandos específicos do Nmap, Bully e 
# Reaver para realizar suas tarefas.
#===============================================================#
#===============================================================#
# Autor: Otávio Will
# Email: <owtechdeveloper@gmail.com>
# Versão: 2.7
#===============================================================#

version="Versão: 2.7"

# Colors
Br="\033[37;1m"
Cz="\033[0;37m"
Rd="\033[31;1m"
Red="\033[31;1;5m"
Vd="\033[32;1m"
Cy="\033[0;36m"
Fm="\e[0m"

source logos.sh

readonly nmapwrite=(
  "Para retornar ao menu principal"
  "Informações somente de portas abertas"
  "Informações de qual Sistema Operacional"
  "Informações do sistema Operacional, versões dos serviços e portas"
  "Informações somente de uma porta, ou portas em específico"
  "Bruteforce MYSQL? Use com responsabilidade!!!"
  "Detectar falhas em servidores, saída do tipo verbose -v"
  "Realizar pesquisas sobre alvos"
  "Buscar falhas de DDoS"
  "Scan de firewall com fragmentos de pacotes"
  "Scan de firewall com MAC spoofing"
  "Scan de host utilizando serviços UDP"
  "Scan decoys (camufla o ip)"
)

#===============================================================#
# Verifica se o usuário está logado como root
#===============================================================#
CheckRoot() {

  clear

  if [[ $EUID -ne 0 ]]; then
    echo -e ${Vd}"\nPARA EXECUTAR ESSE PROGRAMA, RODE${Fm} ${Rd}sudo ./ghost"${Fm}
    echo -e ${Red}"\nNÃO É POSSIVEL EXECUTAR SEM ESTAR COMO ROOT..."${Fm}
    sleep 2s && exit 1
  else
    echo -e ${Rd}"\n\t\t======[${Fm}${Br}STARTANDO O PROGRAMA AGUARDE!${Fm}${Rd}]======"${Fm}
    sleep 1s
  fi
}

#=================================================================#
# Verifica se existem dependências, e instala se nescessário.
#=================================================================#
CheckDependencies() {

  deps=(
    "nmap" "ipcalc" "net-tools" "git" "pixiewps"
    "build-essential" "libpcap-dev" "aircrack-ng" "reaver" "ethtool"
  )

  declare -a missing

  for d in "${!deps[@]}"; do
    [[ -z $(sudo dpkg -l "${deps[$d]}" 2>/dev/null) ]] && missing+=(${deps[$d]})
  done

  if [[ ${#missing[@]} -ne 0 ]]; then
    echo -e ${Rd}"\n\tFALTAM AS DEPENDÊNCIAS:${Fm}${Cy} ${missing[@]}"${Fm}
    read -p $'\033[1;31m\n\t\tINSTALAR AS DEPENDÊNCIAS?\nR: \033[m' RES
    if [[ "${RES,,}" == @(s|sim) ]]; then
      sudo apt update && sudo apt install ${missing[@]} -y
      echo -e ${Vd}"\n\t\tTODAS AS DEPENDÊNCIAS FORAM INSTALADAS"${Fm}
      sleep 1s && Retorno
    elif [[ "${RES,,}" == @(n|não) ]]; then
      echo -e ${Rd}"\n\t\tNÃO É POSSÍVEL PROSSEGUIR SEM INSTALAR AS DEPENDÊNCIAS"${Fm}
      sleep 3s && Thanks
    else
      echo -e ${Rd}"\n\t\tNÃO FOI POSSÍVEL INSTALAR AS DEPENDÊNCIAS ${missing[@]}"${Fm}
    fi
  else
    echo -e ${Vd}"\n\t\tNÃO HÁ DEPENDÊNCIAS A SEREM INSTALADAS"${Fm}
    sleep 1s
  fi
}

Retorno() {

  echo -e ${Rd}"\nRETORNAR PARA: NMAP${Fm}${Br} [N]${Fm}${Rd} WIFICRACK${Fm}${Br} [W]${Fm} ${Rd} MENU${Fm}${Br} [M]${Fm}"
  read -p $'\033[1;37mR: \033[m' RES
  case $RES in
    n | N)
      LAN=($(sudo ifconfig | grep 'wl' | awk '{print $1}'))
      sudo airmon-ng stop ${LAN%%:*} >/dev/null
      echo -e ${Rd}"\nRETORNANDO..."${Fm} && sleep 2s && MenuNmap 
    ;;
    w | W) echo -e ${Rd}"\nRETORNANDO..."${Fm} && sleep 2s && MenuWificrack 
    ;;
    m | M) echo -e ${Rd}"\nRETORNANDO..."${Fm} && sleep 2s && Menu 
    ;;
  esac
}

Thanks() {

  echo -e ${Rd}"\nSAINDO...${Vd}\n\nOBRIGADO POR USAR O GHOST..."${Fm}
  sleep 2s && clear && exit
}

Exit() {

  if [[ -e ghost-log.txt ]]; then
    echo -e ${Rd}"\nEXCLUIR O ARQUIVO ${Cy}ghost-log.txt${Fm}${Rd}?${Fm}${Rd} [${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
    read -p $'\033[1;37mR: \033[m' RES
    if [[ "$RES" == @(s|S) ]]; then
      sudo rm -rf ghost-log.txt && echo -e ${Vd}"\nARQUIVO EXCLUIDO COM SUCESSO!"${Fm} && Thanks
    else
      Thanks
    fi
  else
    echo -e ${Vd}"\nNÃO HÁ ARQUIVO DE LOG A SER EXCLUIDO!"${Fm} && Thanks
  fi
}

OptionExit() {

  echo -e ${Rd}"\nDESEJA SAIR DO GHOST?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\033[1;37mR: \033[m' RES
  [[ "$RES" == @(n|N) ]] && Retorno || Exit
}

OpenLog() {

  tput cnorm -- normal
  echo -ne "\n${Rd}ABRIR O ARQUIVO${Fm}${Cy} ghost-log.txt?${Fm} ${Rd}[${Fm}${Br}S/N${Rd}]${Fm}\n${Fm}R: ${Fm}"
  read RES
  [[ "${RES,,}" == @(s|sim) ]] && cat ghost-log.txt || Retorno
  echo -e ${Rd}"RETORNAR?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\033[1;37mR: \033[m' RES
  [[ "$RES" == @(s|S) ]] && Retorno || Exit
}

Nmap() {

  case $dig in
    1) nmap -f -sS -vv -T4 -Pn $IP | grep "Discovered open port" 2>&- ;;
    2) nmap -O -vv -Pn $IP | grep "OS CPE:" 2>&- ;;
    3) nmap -sS -sV -vv -O -T4 -Pn $IP | grep -E "Discovered open port|OS CPE:|OS details:" 2>&- ;;
    4) nmap -sS -vv -Pn -p $port $IP | grep "Discovered open port" | awk '{print $2, $4, $5, $6}' 2>&- ;;
    5) nmap --script=mysql-brute $IP 2>&- ;;
    6) nmap -sS -v -Pn -A --open --script=vuln $IP 2>&- ;;
    7) nmap --script=asn-query,whois-ip,ip-geolocation-maxmind $IP 2>&- ;;
    8) nmap -sU -A -PN -n -pU:19,53,123,161 --script=ntp-monlist,dns-recursion,snmp-sysdescr $IP 2>&- ;;
    9) nmap --mtu 32 $IP 2>&- ;;
    10) nmap -v -sT -PN --spoof-mac 0 $IP 2>&- ;;
    11) nmap -sU $IP 2>&- ;;
    12) nmap -n -D 192.168.1.1,10.5.1.2,172.1.2.4,3.4.2.1 $IP 2>&- ;;
  esac
}

NmapScanner() {

  clear
  tput civis -- invisible

  echo -e ${Rd}"\n========================[${Fm}${Br}GHOST${Fm}${Rd}]======================="${Fm}

  echo -e ${Rd}"\nDISPARANDO SCANNER NO ALVO: >>> [ "${FM}${Cy}"$IP"${Fm}${Rd}" ]"${Fm}

  echo -e ${Vd}"\nESTE PROCESSO PODE DEMORAR, AGUARDE ATÉ O FIM."${Fm}

  echo -e ${Rd}"\n======================================================"${Fm}

  Nmap $dig >> ghost-log.txt
}

Mask() {

  mask=$(ipcalc --class $ip)

  if [[ "$mask" = "invalid" ]]; then
    echo -e ${Rd}"\nO [ ${Fm}${Br}${ip}${Fm}${Rd} ] É UM IP INVÁLIDO!!!"${Fm}
    read -p $'\033[1;31m\nDIGITE UM IP VÁLIDO!.\nR: \033[m' ip && Mask
  else
    case $mask in
      [0-9] | [0-9][0-9]) # Metodo usado para suprir a nescessidade de colocar número ao lado de número.
        IP="${ip}/$mask" && NmapScanner $IP ;;
      *) OptionExit ;;
    esac
  fi
  OpenLog
}

FullRange() {

  IFS='.' read C1 C2 C3 C4 <<<$ip

  while :; do

    for X in {1..255}; do
      IP=$"$C1.${C2//*/$X}.${C3//*/0}.${C4//*/1}"
      NmapScanner $IP continue
    done
    for Y in {1..255}; do
      IP=$"$C1.${C2//*/$X}.${C3//*/$Y}.${C4//*/1}"
      NmapScanner $IP continue
    done
    for Z in {1..255}; do
      IP=$"$C1.${C2//*/$X}.${C3//*/$Y}.${C4//*/$Z}"
      NmapScanner $IP continue
    done
    break
  done
}

IPF() {

  [[ $dig -eq 4 ]] && read -p $'\033[1;31m\nDIGITE A PORTA OU PORTAS. Ex: 22 ou 22,80,443\nR: \033[m' port
  read -p $'\033[1;31m\nDIGITE SOMENTE O IP, OU URL.\nR: \033[m' dns

  if [[ "$dns" =~ ^[[:alpha:]] ]]; then
    # Converte toda a URL passada, em IP
    read _ _ _ IP <<<$(host $dns | grep "address") && NmapScanner $dig && OpenLog
  else
    # Tomada de decisão com responsabilidade de validação de IP
    if [[ $dns =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      IP="$dns" && NmapScanner $dig && OpenLog
    else
      echo -e ${Rd}"\nO [ ${Fm}${Br}${dns}${Fm}${Rd} ] É UM IP INVÁLIDO!!!"${Fm} && IPF
    fi
  fi
}

Rede() {

  read -p $'\033[1;31m\nDIGITE O IP OU URL.\nR: \033[m' dns
  [[ $dig -eq 4 ]] && read -p $'\033[1;31m\nDIGITE A PORTA OU PORTAS. Ex: 22 ou 22,80,443\nR: \033[m' port

  if [[ "$dns" =~ ^[[:alpha:]] ]]; then
    read _ _ _ ip <<<$(host $dns | grep "address") # Converte toda a URL passada, em IP
    read -p $'\033[1;31m\nESCANEAR EM MODO FULL-RANGE?\nESTE MODO FAZ UM SCANNER DO XXX.0.0.1 ATÉ XXX.255.255.255\nR: \033[m' RES
    if [[ "${RES,,}" == @(s|sim) ]]; then
      FullRange && OpenLog
    else
      Mask
    fi
  else
    # Tomada de decisão com responsabilidade de validação de IP
    if [[ $dns =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      ip="$dns"
      read -p $'\033[1;31m\nESCANEAR EM MODO FULL-RANGE?\nESTE MODO FAZ UM SCANNER DO XXX.0.0.1 ATÉ XXX.255.255.255.\nR: \033[m' RES
      if [[ "${RES,,}" == @(s|sim) ]]; then
        FullRange && OpenLog
      else
        Mask
      fi
    else
      echo -e ${Rd}"\nO [ ${Fm}${Br}${dns}${Fm}${Rd} ] É UM IP INVÁLIDO!!!"${Fm} && Rede
    fi
  fi
}

Ghost() {

  case $dig in

  [1-9] | [0-9][0-9]) # Metodo usado para suprir a nescessidade de colocar numero ao lado de número.
    echo -e ${Rd}"\nESCANEAR IP OU REDE?${Fm}${Br} [I/R]"${Fm}
    echo -e ${Rd}"\nTODAS AS SAÍDAS SERÃO DIRECIONADAS PARA O ARQUIVO:${Fm}${Cy} ghost-log.txt"${Fm}
    read -p $'\033[1;37mR: \033[m' RES
    [[ "$RES" == @(i|I) ]] && IPF $dig || [[ "$RES" == @(r|R) ]] && Rede $dig || OptionExit
    ;;
  0) Exit ;;

  *) OptionExit && Retorno ;;
  esac
}

MenuNmap() {

  clear
  while true; do

    echo -e ${Rd}"==============================================================================\n"${Fm}

    for X in "${!NMAP[@]}"; do
      echo -e ${Vd}"\t\t\t${NMAP[$X]}"${Fm}
      sleep 0.1s
    done

    echo -e ${Rd}"\n=============================================================================="${Fm}

    for N in "${!nmapwrite[@]}"; do
      echo -e ${Rd}" [$N]"${Fm} ${Br}"${nmapwrite[$N]}"${Fm}
      sleep 0.05s
    done

    echo -e ${Rd}"=============================================================================="${Fm}

    echo -e ${Red}"ESCOLHA UMA DAS OPÇÕES DO MENU ACIMA"${Fm}

    read -p $'\033[37;1mR: \033[m' dig

    if [[ "$dig" =~ ^[[:alpha:]] ]]; then
      echo -ne "\n${Rd}OPÇÃO INVÁLIDA!!!\nSÓ É ACEITO NÚMEROS!\n\n${Br}RETORNAR AO NMAP?${Fm} \
      ${Rd}[${Fm}${Br}S/N${Fm}${Rd}]\n${Fm}R: ${Fm}"
      read inicio
      [[ "${inicio,,}" == @(s|sim) ]] && MenuNmap
    else
      case $dig in
      0) Menu ;;
      *) Ghost $dig ;;
      esac
    fi
  done

}

AirmonStop() {

  echo -e ${Vd}"DESABILITANDO A PLACA DE REDE DO MODO MONITOR"${Fm}
  sleep 2s
  sudo airmon-ng stop ${LAN[$P]%%:*}mon
  Thanks
}

Airmon() {

  clear
  LAN=($(sudo ifconfig | grep 'wl' | awk '{print $1}'))

  echo -e ${Rd}"\nBUSCANDO PLACAS DE REDE WIRELESS..."${Fm}
  sleep 2s
  echo -e ${Rd}"\nPLACAS DE REDE WIRELESS DISPONÍVEIS:\n"${Fm}

  for X in "${!LAN[@]}"; do
    echo -e ${Rd}"[$X]${Fm} ${Vd}${LAN[$X]%%:*}"${Fm}
  done

  read -p $'\033[31;1m\nDIGITE O NÚMERO DA PLACA ESCOLHIDA R: \033[m' P

  echo -e ${Rd}"\nCOLOCANDO A PLACA WIFI EM MODO MONITOR"${Fm}
  sleep 2s
  sudo airmon-ng start ${LAN[$P]%%:*} >/dev/null && clear
  echo -e ${Rd}"OBTENDO REDES WIFI DISPONIVEIS, O PROCESSO LEVARÁ ALGUNS SEGUNDOS\n"${Fm}

}

Wash() {

  sudo timeout --preserve-status 30 wash -i ${LAN[$P]%%:*}mon | tee MACS.txt
  MACS=($(cat MACS.txt | grep ':' | awk '{print $1" "$2}'))

  echo -e ${Rd}"\nESCOLHA UMA REDE PARA ATAQUE\n"${Fm}

  for ((X = 0; X < ${#MACS[@]}; X = X + 2)); do
    echo -e ${Rd}"[$X] MAC:${Fm} ${Vd}${MACS[$X]}"${Fm}
  done

  read -p $'\033[31;1m\nDIGITE O ÍNDICE DA REDE ESCOLHIDA R: \033[m' I
  echo -e ${Cy}"\nESTE PROCESSO PODE DEMORAR VÁRIOS MINUTOS\nAGUARDE O FIM DO PROCESSO...\n"${Fm}
}

Bully() {

  Airmon
  Wash
  bully ${LAN[$P]%%:*}mon -b${MACS[$I]} -c${MACS[$I + 1]} -d -A -F -B -l 5
  echo -e ${Rd}"RETORNAR?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\033[1;37mR: \033[m' RES
  [[ "$RES" == @(s|S) ]] && Retorno || AirmonStop ${LAN[$P]%%*}mon
}

Reaver() {

  Airmon
  Wash
  reaver -c${MACS[$I + 1]} -b${MACS[$I]} -vv -i ${LAN[$P]%%:*}mon -L -Z -K 1
  echo -e ${Rd}"RETORNAR?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\033[1;37mR: \033[m' RES
  [[ "$RES" == @(s|S) ]] && Retorno || AirmonStop ${LAN[$P]%%:*}mon
}

MenuWificrack() {

  clear
  while true; do

    echo -e ${Rd}"==============================================================================\n"${Fm}

    for X in "${!WIFI[@]}"; do
      echo -e ${Cy}"\t${WIFI[$X]}"${Fm}
      sleep 0.1s
    done

    echo -e ${Rd}"\n=============================================================================="${Fm}
    echo -e ${Rd}" [0]"${Fm}${Br}" Para retornar ao menu principal"${Fm}
    echo -e ${Rd}" [1]"${Fm}${Br}" Quebra do PIN WPS com REAVER"${Fm}
    echo -e ${Rd}" [2]"${Fm}${Br}" Quebra do PIN WPS com BULLY"${Fm}
    echo -e ${Rd}"=============================================================================="${Fm}
    echo -e ${Red}"ESCOLHA UMA DAS OPÇÕES DO MENU ACIMA"${Fm}

    read -p $'\033[37;1mR: \033[m' dig

    if [[ "$dig" =~ ^[[:alpha:]] ]]; then
      echo -ne "\n${Rd}OPÇÃO INVÁLIDA!!!\nSÓ É ACEITO NÚMEROS!\n\n${Br}RETORNAR AO WIFICRACK?${Fm} \
      ${Rd}[${Fm}${Br}S/N${Fm}${Rd}]\n${Fm}R: ${Fm}"
      read inicio
      [[ "${inicio,,}" == @(s|sim) ]] && MenuWificrack || Exit
    else
      case $dig in
      0) Menu ;;
      1) Reaver ;;
      2) Bully ;;
      esac
    fi
  done
}

Menu() {

  clear
  while true; do

    echo -e ${Rd}"==============================================================================\n"${Fm}

    for X in "${!GHOST[@]}"; do
      echo -e ${Rd}"\t\t${GHOST[$X]}"${Fm}
      sleep 0.1s
    done

    echo -e ${Cy}"                               ${version}"${Fm}
    echo -e ${Rd}"=============================================================================="${Fm}
    echo -e ${Rd}" [0]"${Fm}${Br}" Para sair"${Fm}
    echo -e ${Rd}" [1]"${Fm}${Br}" Scanner usando o nmap"${Fm}
    echo -e ${Rd}" [2]"${Fm}${Br}" Quebra de senha wifi com WifiCrack"${Fm}
    echo -e ${Rd}"=============================================================================="${Fm}

    echo -e ${Red}"ESCOLHA UMA DAS OPÇÕES DO MENU ACIMA"${Fm}

    read -p $'\033[37;1mR: \033[m' dig

    if [[ "$dig" =~ ^[[:alpha:]] ]]; then
      echo -ne "\n${Rd}OPÇÃO INVÁLIDA!!!\nSÓ É ACEITO NÚMEROS!\n\n${Br}RETORNAR AO INICIO?${Fm} \
      ${Rd}[${Fm}${Br}S/N${Fm}${Rd}]\n${Fm}R: ${Fm}"
      read inicio
      [[ "${inicio,,}" == @(s|sim) ]] && Retorno || Exit
    else
      case $dig in
      0) Exit ;;
      1) MenuNmap ;;
      2) MenuWificrack ;;
      esac
    fi
  done
}
CheckRoot
CheckDependencies
Menu
#=============================================================[FIM]==================================================================#
