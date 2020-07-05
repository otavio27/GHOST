#!/bin/bash
#/**
# * @link      https://github.com/robsonalexandre/progressbar
# * @license   https://www.gnu.org/licenses/gpl-3.0.txt GNU GENERAL PUBLIC LICENSE
# * @author    Robson Alexandre <alexandrerobson@gmail.com>
# */
function ProgressBar.init() {
  shopt -s extglob
  tmp=$(mktemp -d)
  fifo=$(mktemp -u --tmpdir=$tmp)
#  log=$(mktemp --tmpdir=$tmp)
  mkfifo $fifo
  exec 3<>$fifo
#  exec 0<&3

  declare -g bar_txtcolor='\e[0;30m'
  declare -g bar_txtbg='\e[42m'
  declare -g bar_progresscolor=''
  declare -g bar_progressbg=''
  declare -g bar_nocolor='\e[0m'
  declare -g pid=
}

function ProgressBar.cleanup() {
  tput el
  echo -e "Concluído [100%]"
  tput cnorm
  [ -d "$tmp" ] && rm -fr $tmp
}
trap ProgressBar.cleanup EXIT KILL

function ProgressBar.setProgress() {
  [ $# -gt 0 ] && echo $@ >&3
}
export -f ProgressBar.setProgress

# Exemplos de progressbar
# estilo apt upgrade
# Progress: [ 60%] [#####################..............................]
# estilo wget
# linux-4.15.18.tar.xz  45%[============>        ] 44,18M 5,97MB/s eta 7s
function ProgressBar.print() {
  local partial=$1 \
        total=${2:-100} \
        msg=${3:-Progress:} \
        cols offset

  cols=$(tput cols)
  percento=$((partial*100/total))
  ((percento>100)) && percento=100
  offset=$((cols-${#msg}-10))
  strcompleto=$(printf "%0.s=" $(eval echo {1..$cols}))
  strcomplemento=$(printf "%0.s." $(eval echo {1..$cols}))
  intcompleto=$((percento*offset/total))
  intcomplemento=$((offset-intcompleto))
  printf "\r${bar_txtcolor}${bar_txtbg}%s [%3d%%]${bar_nocolor} [${bar_progresscolor}${bar_progressbg}%.*s%.*s${bar_nocolor}]\r" \
    "$msg" \
    $percento \
    $intcompleto $strcompleto \
    $intcomplemento $strcomplemento
}

function ProgressBar.run() {
  local msg total=100
  declare -i nivel=0
  declare -i n
  tput civis

  while :; do

    nivel=$(((++i%20)?nivel:nivel+1))

    read -t .1
    [[ $REPLY ]] && ProgressBar.setProgress "$REPLY"

    read -t .1 -u 3       # read espera string: "99|99 String caracteres"
    #n=${n:-$nivel}       # Caso read não receba de fd, continua incrementando de nivel

#   Parsing n vindo de fd
    str=${REPLY##+([0-9 ])}
    msg=${str:-$msg}

    : ${REPLY%% *}
    n=${_//[^0-9]}
    nivel=$((n>nivel?n:nivel))

#   Se processo em bg concluir, ou não tiver processo em bg e nivel chegar a 100,
#     termina barra de progresso
    ps -p ${pid:-1} > /dev/null 2>&1 || break
    [ -z "$pid" -a "$nivel" == 100 ] && break

    ProgressBar.print "$nivel" "$total" "$msg"
  done
  ProgressBar.cleanup
}

function ProgressBar.main() {
  ProgressBar.init $@
  if [ $# -gt 0 ]; then
    if [ -f "$1" ]; then
      "$*" &
    else
      "$*" &
    fi
    pid=$!
  fi
  ProgressBar.run
}

[ "${#BASH_SOURCE[@]}" -eq 1 ] && ProgressBar.main $@

# vim: sts=2:ts=2:sw=2:tw=0
