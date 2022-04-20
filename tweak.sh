#!/usr/bin/env sh

CLenv=./colorenv.sh

_init() { [ -t 0 ] && ./rebase16.sh ${theme:-default-dark}; } # or cat
 init() { eval export $(_init | $CLenv "$@"); }
array() { sed -n '/^[0-9]/{s/^[^=]*=//;p}'; }
  cap() { ./colorenv.sh -l | array; }
 save() { pastel -m off format | ./colorenv.sh "$@"; }
apply() { save -a "$@"; }
Past='pastel -m 24bit'

lines() {
  local seq
  [ "$1" -gt 0 ] || return 1
  for seq in $(seq 1 "$1"); do read line; echo $line; done
}

Sel='eval exec 30>&1 && sel'
sel() {
  local hi lo size nxt
  [ $# -gt 0 ] || { cat; return; }
  [ ${1%%[!0-9]*} -ge 0 ] || { cat >&30; return; }
  
  hi=-1   # zero index
  while [ $# -gt 0 ]; do
    nxt=${1%%[!0-9]*}
    size=$(("$nxt" - "$hi" - 1)) \
    &&  [ "$size" -gt 0 ]        \
    &&  lines "$size" >&30

    lo=${1%[!0-9]*}  hi=${1#*[!0-9]}
    size=$(("$hi" - "$lo" + 1)) \
    &&  [ "$size" -gt 0 ]       \
    &&  lines "$size"

    shift
  done
}

BRI_COL=9-14 BRI_ALL=8-15
REG_COL=1-6  REG_ALL=0-7
REG_BLK=0    REG_WHT=7
BRI_BLK=8    BRI_WHT=15
COL="$REG_COL $BRI_COL"
BLK="$REG_BLK $BRI_BLK"
WHT="$REG_WHT $BRI_WHT"
COL_WHT="$REG_COL $REG_WHT $BRI_COL $BRI_WHT"

exe() {
  [ "$op" = set ] && op="set $prop"
  eval export $(cap | $Sel $SEL \| $Past $op $sign$val | save)
}

selsplit() {
  local IFS s; IFS=, ; set -- "$@"; IFS=
  sel=
  for s; do
    case "$s" in  *[!0-9-]*);;  *) sel="$sel $s";  continue ;; esac
    s=$(echo $s | (while read -N1 c; do echo $c; done))
    sel="$sel $s"
  done
}

Cmd() {
  local SEL sel prop op val sign s t

  while [ $# -gt 0 ]; do
    sel=${1%%:*}  prop=${1#*:}  val=${1##*[+=x/-]}
    [ ${#sel} -eq  ${#1} ]  && sel=
    [ ${#val} -eq  ${#1} ]  && val=
    prop=${prop%$val} sign=
    [ ${#prop} -gt 1 ] && { sign=${prop#?}; prop=${prop%$sign}; }

    s= t= SEL=
    selsplit "$sel"
    for s in  $sel; do
      case "$s" in *[!0-9-]*);; *) SEL="$SEL $s"; continue ;; esac
      case "$s" in
       k|K) t=0  ;;  # black
       w|W) t=7  ;;  # white
       r|R) t=1  ;;  # red
       g|G) t=2  ;;  # green
       y|Y) t=3  ;;  # yellow
       b|B) t=4  ;;  # blue
       m|M) t=5  ;;  # magenta
       c|C) t=6  ;;  # cyan
      esac
      [ "$s" \> Z ] || t=$((t + 8))
      SEL="$SEL $t"
    done
    
    SEL=$(for wrd in $SEL; do echo $wrd; done | sort -g | uniq)
    op=
    [ "$sign" = '=' ] && op=set && sign=
    case "$prop" in
     H) prop=hsl-hue        op=${op:-rotate}   SEL=${SEL:-$COL} ;;
     S) prop=hsl-saturation op=${op:-saturate} SEL=${SEL:-$COL} ;;
     L) prop=hsl-lightness  op=${op:-lighten}  ;;
     R) prop=red    op=set  SEL=${SEL:-$COL}   ;;
     G) prop=green  op=set  SEL=${SEL:-$COL}   ;;
     B) prop=blue   op=set  SEL=${SEL:-$COL}   ;;
     X) op=mix ;;
     *) false  ;;
    esac  &&  exe;  shift
  done
}

[ "$1" = -t ]  &&  theme=$2  &&  shift 2
init; Cmd "$@"; cap | apply -D
