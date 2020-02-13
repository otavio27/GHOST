#!/usr/bin/env bash

#===============================================================#
# GHOST, programa de scanner de portas e varredura em rede.
# Este programa usa de comandos específicos do Nmap para realizar
# suas tarefas.
#===============================================================#

#===============================================================#
# Autor: Otávio Will
# Email: <otaviowill81@gmail.com>
# Versão: 2.1
#===============================================================#

#=======================================================================================#
# Data: 24/11/2019
# Implementações da versão 2.0
#
# Implementado a condição de instalar as dependências
# sem precisar sair do programa. E também implementada a verificação
# se exixte o arquivo.log antes de perguntar ao usuário se quer excluir.
#
# Foi alterado na função rede, a parte onde o usuário era obrigado a
# digitar o IP sem o ultimo range. Dando agora a opção de digitar o IP
# completo, sem haver preocupação do que se trata o termo "range".
#
# Implementado a validação do IP digitado, caso o usuário passe um IP
# inválido, o programa informará sobre o ocorrido, e pedirá que passe
# um IP válido novamete.
#
# Data: 09/12/2019
# Implementações da versão 2.1
# 
# A função loop_func foi deletada e uma nova dependência inserida, "ipcalc".
# Duas novas funções foram criadas.
# A mask_func, e essa recebe a responsabilidade
# de detectar qual mascara o IP se encontra.E assim facilatar o scanner
# à detectar quais hosts estão ativos. E com isso, a saída do log.txt
# fica mais limpa. 
# A função full_range tem a finalidade de ser possivél escanear uma enorme gama de IP's.
# Essa função é muito útil quando se precisa saber quais IP's tem uma determidana porta 
# aberta. 
#
# Data: 05/02/2020
# Implementações da versão 2.5
#
# Foi adicionado ao programa, funções que permitem a quebra de senhas wi-fi com reaver e 
# bully. Sendo que a função bully, funciona com perfeição nas distribuições Kali Linux e 
# WifiSlax.
# Também foi separado os menús, cada um agora corresponde as suas funções. Sendo o menú 
# principal para a escolha das ferramentas, e os submenús para a escolha das tarefas de
# cada ferramenta.
#=======================================================================================#

#======================================================================#
# Obs: Não foi comentado muitas linhas, pois o programa está modulado
# por funções. E cada função recebeu o nome mais próximo do que ela é
# destinada. Sendo assim, qualquer eventual "BUG" que aparecer, poderá
# ser procurado na respctiva função.
#======================================================================#

version="Versão: 2.5"

# Colors
Br="\033[37;1m"
Cz="\033[0;37m"
Rd="\033[31;1m"
Red="\033[31;1;5m"
Vd="\033[32;1m"
Cy="\033[0;36m"
Fm="\e[0m"

source logos.sh

#===============================================================#
# Verifica se o usuário está logado como root
#===============================================================#
checkroot_func() {

  clear

  if [[ $EUID -ne 0 ]]; then
    echo -e ${Vd}"\nPARA EXECUTAR ESSE PROGRAMA, RODE${Fm} ${Rd}sudo ./ghost"${Fm}
    echo -e ${Red}"\nNÃO É POSSIVEL EXECUTAR SEM ESTAR COMO ROOT..."${Fm}
    sleep 2s && exit 1 
  else
    echo -e ${Rd}"\n===[${Fm}${Br}STARTANDO O PROGRAMA AGUARDE!${Fm}${Rd}]==="${Fm}
    sleep 1s
  fi
}

#=================================================================#
# Verifica se existem dependências, e instalando-as se nescessário
#=================================================================#
checkdependencias() {

  deps=("nmap" "ipcalc" "net-tools" "git" "pixiewps"
  "build-essential" "libpcap-dev" "aircrack-ng" "reaver")

  declare -a missing

  for d in "${!deps[@]}"; do

    [[ -z $(sudo dpkg -l "${deps[$d]}" 2> /dev/null) ]] && missing+=(${deps[$d]})

  done 

  if [[ ${#missing[@]} -ne 0 ]]; then
    echo -e ${Rd}"\nFALTAM AS DEPENDÊNCIAS:${Fm}${Cy} ${missing[@]}"${Fm}
    read -p $'\033[1;31m\nINSTALAR AS DEPENDÊNCIAS?\nR: \033[m' RES

    if [[ "${RES,,}" == @(s|sim) ]]; then
      sudo apt update && sudo apt install ${missing[@]} -y
      echo -e ${Vd}"\nTODAS AS DEPENDÊNCIAS FORAM INSTALADAS"${Fm}
      sleep 1s && retorno_func
    elif [[ "${RES,,}" == @(n|não) ]]; then
      echo -e ${Rd}"\nNÃO É POSSÍVEL PROSSEGUIR SEM INSTALAR AS DEPENDÊNCIAS"${Fm}
      sleep 3s && thanks_func
    else
      echo -e ${Rd}"\nNÃO FOI POSSÍVEL INSTALAR AS DEPENDÊNCIAS ${missing[@]}"${Fm}
    fi

  else
    echo -e ${Vd}"\nNÃO HÁ DEPENDÊNCIAS A SEREM INSTALADAS"${Fm}
    sleep 1s
  fi
}

retorno_func() {

  echo -e ${Rd}"\nRETORNANDO..."${Fm}
  sleep 2s && Menu
}

thanks_func() {

    echo -e ${Rd}"\nSAINDO...${Vd}\n\nOBRIGADO POR USAR O GHOST..."${Fm}
    sleep 2s && clear && exit
}

exit_func() {

  if [[ -e ghost-log.txt ]]; then
    echo -e ${Rd}"\nEXCLUIR O ARQUIVO ${Cy}ghost-log.txt${Fm}${Rd}?${Fm}${Rd} [${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
    read -p $'\033[1;37mR: \033[m' RES
    if [[ "$RES" == @(s|S) ]]; then
      sudo rm -rf ghost-log.txt && echo -e ${Vd}"\nARQUIVO EXCLUIDO COM SUCESSO!"${Fm} && thanks_func
    else
      thanks_func
    fi
  else
    echo -e ${Vd}"\nNÃO HÁ ARQUIVO DE LOG A SER EXCLUIDO!"${Fm} && thanks_func
  fi
}

optionexit_func() {

  echo -e ${Rd}"\nDESEJA SAIR DO GHOST?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\033[1;37mR: \033[m' RES
  [[ "$RES" == @(n|N) ]] && retorno_func || exit_func
}

open_log() {

  tput cnorm -- normal
  echo -ne "\n${Rd}ABRIR O ARQUIVO${Fm}${Cy} ghost-log.txt?${Fm} ${Rd}[${Fm}${Br}S/N${Rd}]${Fm}\n${Fm}R: ${Fm}"
  read RES

  [[ "${RES,,}" == @(s|sim) ]] && cat ghost-log.txt || retorno_func

  echo -e ${Rd}"RETORNAR?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\033[1;37mR: \033[m' RES

  [[ "$RES" == @(s|S) ]] && retorno_func || exit_func
}

nmap_func() {

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

nmap_scanner() {

  clear

  tput civis -- invisible

  echo -e ${Rd}"\n========================[${Fm}${Br}GHOST${Fm}${Rd}]======================="${Fm}

  echo -e ${Rd}"\nDISPARANDO SCANNER NO ALVO: >>> [ "${FM}${Cy}"$IP"${Fm}${Rd}" ]"${Fm}

  echo -e ${Vd}"\nESTE PROCESSO PODE DEMORAR, AGUARDE ATÉ O FIM."${Fm}

  echo -e ${Rd}"\n======================================================"${Fm}

  nmap_func $dig >> ghost-log.txt

}

mask_func() {

  mask=$(ipcalc --class $ip)

  if [[ "$mask" = "invalid" ]]; then
    echo -e ${Rd}"\nO [ ${Fm}${Br}${ip}${Fm}${Rd} ] É UM IP INVÁLIDO!!!"${Fm}
    read -p $'\033[1;31m\nDIGITE UM IP VÁLIDO!.\nR: \033[m' ip && mask_func
  else
    case $mask in
      [0-9]|[0-9][0-9]) # Metodo usado para suprir a nescessidade de colocar número ao lado de número.
      IP="${ip}/$mask" && nmap_scanner $IP ;;
      *) optionexit_func ;;
    esac
  fi
  open_log
}

full_range() {

  IFS='.' read C1 C2 C3 C4 <<< $ip
  
  while : ; do 

    for X in {1..255}; do IP=$"$C1.${C2//*/$X}.${C3//*/0}.${C4//*/1}"; nmap_scanner $IP continue; done
    for Y in {1..255}; do IP=$"$C1.${C2//*/$X}.${C3//*/$Y}.${C4//*/1}"; nmap_scanner $IP continue; done
    for Z in {1..255}; do IP=$"$C1.${C2//*/$X}.${C3//*/$Y}.${C4//*/$Z}"; nmap_scanner $IP continue; done
    
    break

  done
}

ip_func() {

  [[ $dig -eq 4 ]] && read -p $'\033[1;31m\nDIGITE A PORTA OU PORTAS. Ex: 22 ou 22,80,443\nR: \033[m' port
  read -p $'\033[1;31m\nDIGITE SOMENTE O IP, OU URL.\nR: \033[m' dns

  if [[ "$dns" =~ ^[[:alpha:]] ]]; then
    # Converte toda a URL passada, em IP
    read _ _ _ IP <<< $( host $dns | grep "address" ) && nmap_scanner $dig && open_log
  else
    # Tomada de decisão com responsabilidade de validação de IP
    if [[ $dns =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      IP="$dns" && nmap_scanner $dig && open_log
    else
      echo -e ${Rd}"\nO [ ${Fm}${Br}${dns}${Fm}${Rd} ] É UM IP INVÁLIDO!!!"${Fm} && ip_func
    fi
  fi
}

rede_func() {

  read -p $'\033[1;31m\nDIGITE O IP OU URL.\nR: \033[m' dns
  
  [[ $dig -eq 4 ]] && read -p $'\033[1;31m\nDIGITE A PORTA OU PORTAS. Ex: 22 ou 22,80,443\nR: \033[m' port

  if [[ "$dns" =~ ^[[:alpha:]] ]]; then
    read _ _ _ ip <<< $( host $dns | grep "address" ) # Converte toda a URL passada, em IP
    read -p $'\033[1;31m\nESCANEAR EM MODO FULL-RANGE?\nESTE MODO FAZ UM SCANNER DO XXX.0.0.0 ATÉ XXX.255.255.255\nR: \033[m' RES
    if [[ "${RES,,}" == @(s|sim) ]]; then
      full_range 
    else
      mask_func 
    fi
  else
    # Tomada de decisão com responsabilidade de validação de IP
    if [[ $dns =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      ip="$dns" 
      read -p $'\033[1;31m\nESCANEAR EM MODO FULL-RANGE?\nESTE MODO FAZ UM SCANNER DO XXX.0.0.0 ATÉ XXX.255.255.255.\nR: \033[m' RES
      if [[ "${RES,,}" == @(s|sim) ]]; then
        full_range 
      else
        mask_func
      fi
    else
        echo -e ${Rd}"\nO [ ${Fm}${Br}${dns}${Fm}${Rd} ] É UM IP INVÁLIDO!!!"${Fm} && rede_func
      fi
  fi
}

ghost_fun() {

  case $dig in

    [1-9]|[0-9][0-9]) # Metodo usado para suprir a nescessidade de colocar numero ao lado de número.

      echo -e ${Rd}"\nESCANEAR IP OU REDE?${Fm}${Br} [I/R]"${Fm}
      echo -e ${Rd}"\nTODAS AS SAÍDAS SERÃO DIRECIONADAS PARA O ARQUIVO:${Fm}${Cy} ghost-log.txt"${Fm}
      read -p $'\033[1;37mR: \033[m' RES

      [[ "$RES" == @(i|I) ]] && ip_func $dig || [[ "$RES" == @(r|R) ]] && rede_func $dig || optionexit_func ;;

    0) exit_func ;;

    *) optionexit_func; retorno_func ;;
  esac
}

MenuNmap_func() {

  clear
  while true; do

    echo -e ${Rd}"==============================================================================\n"${Fm}
    
    for X in "${!LOGO2[@]}"; do
      echo -e ${Vd}"\t\t\t${LOGO2[$X]}"${Fm}
      sleep 0.1s
    done

    echo -e ${Rd}"\n=============================================================================="${Fm}
    echo -e ${Rd}" [0]"${Fm}${Br}" Para sair"${Fm}
    echo -e ${Rd}" [1]"${Fm}${Br}" Informações somente de portas abertas"${Fm}
    echo -e ${Rd}" [2]"${Fm}${Br}" Informações de qual Sistema Operacional"${Fm}
    echo -e ${Rd}" [3]"${Fm}${Br}" Informações do sistema Operacional, versões dos serviços e portas"${Fm}
    echo -e ${Rd}" [4]"${Fm}${Br}" Informações somente de uma porta, ou portas em específico"${Fm}
    echo -e ${Rd}" [5]"${Fm}${Br}" Bruteforce MYSQL? Use com responsabilidade!!!"${Fm}
    echo -e ${Rd}" [6]"${Fm}${Br}" Detectar falhas em servidores, saída do tipo verbose -v"${Fm}
    echo -e ${Rd}" [7]"${Fm}${Br}" Realizar pesquisas sobre alvos"${Fm}
    echo -e ${Rd}" [8]"${Fm}${Br}" Buscar falhas de DDoS"${Fm}
    echo -e ${Rd}" [9]"${Fm}${Br}" Scan de firewall com fragmentos de pacotes"${Fm}
    echo -e ${Rd}" [10]"${Fm}${Br}" Scan de firewall com MAC spoofing"${Fm}
    echo -e ${Rd}" [11]"${Fm}${Br}" Scan de host utilizando serviços UDP"${Fm}
    echo -e ${Rd}" [12]"${Fm}${Br}" Scan decoys (camufla o ip)"${Fm}
    echo -e ${Rd}"=============================================================================="${Fm}

    echo -e ${Red}"ESCOLHA UMA DAS OPÇÕES DO MENU ACIMA"${Fm}

    read -p $'\033[37;1mR: \033[m' dig

    if [[ "$dig" =~ ^[[:alpha:]] ]]; then
      echo -ne "\n${Rd}OPÇÃO INVÁLIDA!!!\nSÓ É ACEITO NÚMEROS!\n\n${Br}RETORNAR AO NMAP?${Fm} \
      ${Rd}[${Fm}${Br}S/N${Rd}]${Fm}\n${Fm}R: ${Fm}"
      read inicio
      [[ "${inicio,,}" == @(s|sim) ]] && MenuNmap_func || exit_func
    else
      ghost_fun $dig
    fi

  done

}

airmonstop_func() {

  echo -e ${Vd}"DESABILITANDO A PLACA DE REDE DO MODO MONITOR"${Fm}
  sleep 2s
  sudo airmon-ng stop ${LAN[$P]%%:*}mon
  thanks_func
}

airmon_func() {

  clear

  LAN=($(sudo ifconfig | grep 'wl' | awk '{print $1}'))

  echo -e ${Rd}"\nBUSCANDO PLACAS DE REDE WIRELESS..."${Fm}
  sleep 3s
  echo -e ${Rd}"\nPLACAS DE REDE WIRELESS DISPONÍVEIS:\n"${Fm}

  for X in "${!LAN[@]}"; do

    echo -e ${Rd}"[$X]${Fm} ${Vd}${LAN[$X]%%:*}"${Fm}

  done

  read -p $'\033[31;1m\nDIGITE O NÚMERO DA PLACA ESCOLHIDA R: \033[m' P

  echo -e ${Rd}"\nCOLOCANDO A PLACA WIFI EM MODO MONITOR"${Fm}
  sleep 3s
  sudo airmon-ng start ${LAN[$P]%%:*} && clear
  echo -e ${Rd}"OBTENDO REDES WIFI DISPONIVEIS, O PROCESSO LEVARÁ 30 SEGUNDOS\n"${Fm}

}

wash_func() {

  sleep 2s
  sudo timeout --preserve-status 30 wash -i  ${LAN[$P]%%:*}mon 
  read -p $'\033[31;1m\nCOPIE E COLE O MAC DA REDE ESCOLHIDA R: \033[m' mac
  read -p $'\033[31;1m\nDIGITE O CANAL QUE CORRESPONDE AO MAC DA REDE ESCOLHIDA R: \033[m' canal
  echo -e ${Cy}"\nESTE PROCESSO PODE DEMORAR VÁRIOS MINUTOS\nAGUARDE O FIM DO PROCESSO...\n"${Fm}
}

bully_func() {

  airmon_func
  wash_func
  bully ${LAN[$P]%%:*}mon -b$mac -c$canal -d -A -F -B -l 5
  echo -e ${Rd}"RETORNAR?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\033[1;37mR: \033[m' RES

  [[ "$RES" == @(s|S) ]] && retorno_func || airmonstop_func ${LAN[$P]%%*}mon
}

reaver_func() {

  airmon_func
  wash_func
  reaver -c$canal -b$mac -vv -i ${LAN[$P]%%:*}mon -L -Z -K 1
  echo -e ${Rd}"RETORNAR?"${Fm}${Rd} "[${Fm}${Br}S/N${Fm}${Rd}]"${Fm}
  read -p $'\033[1;37mR: \033[m' RES

  [[ "$RES" == @(s|S) ]] && retorno_func || airmonstop_func ${LAN[$P]%%:*}mon
}

MenuWificrack_func() {

  clear
  while true; do
  
    echo -e ${Rd}"==============================================================================\n"${Fm}

    for X in "${!LOGO1[@]}"; do
      echo -e ${Cy}"\t${LOGO1[$X]}"${Fm}
      sleep 0.1s
    done

    echo -e ${Rd}"\n=============================================================================="${Fm}
    echo -e ${Rd}" [0]"${Fm}${Br}" Para sair"${Fm}
    echo -e ${Rd}" [1]"${Fm}${Br}" Quebra do PIN WPS com REAVER"${Fm}
    echo -e ${Rd}" [2]"${Fm}${Br}" Quebra do PIN WPS com BULLY"${Fm}
    echo -e ${Rd}"=============================================================================="${Fm}
    echo -e ${Red}"ESCOLHA UMA DAS OPÇÕES DO MENU ACIMA"${Fm}

    read -p $'\033[37;1mR: \033[m' dig

    if [[ "$dig" =~ ^[[:alpha:]] ]]; then
      echo -ne "\n${Rd}OPÇÃO INVÁLIDA!!!\nSÓ É ACEITO NÚMEROS!\n\n${Br}RETORNAR AO WIFICRACK?${Fm} \
      ${Rd}[${Fm}${Br}S/N${Rd}]${Fm}\n${Fm}R: ${Fm}"
      read inicio
      [[ "${inicio,,}" == @(s|sim) ]] && MenuWificrack_func || exit_func
    else
      case $dig in
        0) exit_func ;;
        1) reaver_func ;;
        2) bully_func ;;
      esac
    fi
  
  done
}

Menu() {

  clear
  while true; do

    echo -e ${Rd}"==============================================================================\n"${Fm}

    for X in "${!LOGO[@]}"; do
      echo -e ${Rd}"\t\t${LOGO[$X]}"${Fm}
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
      ${Rd}[${Fm}${Br}S/N${Rd}]${Fm}\n${Fm}R: ${Fm}"
      read inicio
      [[ "${inicio,,}" == @(s|sim) ]] && retorno_func || exit_func
    else
      case $dig in
        0) exit_func ;;
        1) MenuNmap_func ;;
        2) MenuWificrack_func ;;
      esac
    fi

  done
}
checkroot_func
checkdependencias
Menu
#=============================================================[FIM]==================================================================#
