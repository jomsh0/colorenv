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

Sel='eval exec 30>&1 && _Sel'
_Sel() {
  local hi lo size nxt
  [ $# -gt 0 ] || { cat; return; }
  [ ${1%%[!0-9]*} -ge 0 ] || { cat >&30; return; }
  
  hi=-1   # zero index
  while [ $# -gt 0 ]; do
    nxt=${1%%[!0-9]*}
    size=$(($nxt - $hi - 1)) \
    &&  [ "$size" -gt 0 ]    \
    &&  lines "$size" >&30

    lo=${1%[!0-9]*}  hi=${1#*[!0-9]}
    size=$(($hi - $lo + 1)) \
    &&  [ "$size" -gt 0 ]   \
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
  local IFS s; IFS=$IFS,; set -- $@; IFS=${IFS%,}
  for s; do
    case "$s" in
     *[!0-9-]*) echo $s | { while read -n1 c; do echo $c; done; };;
             *) echo $s ;;
    esac
  done
}

seldecode() {
  local ansi
  for sel in $(selsplit $@); do
    # numeric range case
    case "$sel" in *[!0-9-]*);; *) echo $sel; continue ;; esac

    ansi=  # color initial cases
    case "$sel" in
     k|K) ansi=0  ;;  # black
     w|W) ansi=7  ;;  # white
     r|R) ansi=1  ;;  # red
     g|G) ansi=2  ;;  # green
     y|Y) ansi=3  ;;  # yellow
     b|B) ansi=4  ;;  # blue
     m|M) ansi=5  ;;  # magenta
     c|C) ansi=6  ;;  # cyan
       *) false   ;;
    esac  &&
        { [ "$sel" \> Z ] || ansi=$((ansi + 8))
          echo $ansi; continue; }
    
    # wildcard cases
    case "$sel" in
     %) echo 0-15 ;;
     @) echo 1-6  ;;
     ^) echo 9-14 ;;
     =) echo 1-6; echo 9-14 ;;
     _) echo 0; echo 7-8; echo 15 ;;
    esac
  done
}

error() { echo '[error] ' "$@" >&2; return 1; }

Cmd() {
  local SEL sel prop op val work sign

  while [ $# -gt 0 ]; do
    SEL= op= sign=  sel=${1##*[:0-9]} work=${1#?}
    prop=${1%$work} work=${work%$sel}
    val=${work#?}   sign=${work%%[!=+-]*}
    val=${val%:}

    if ! [ ${#prop} -eq 1  -a  ${#sign} -eq 1 ]; then
      error "couldn't parse $1"; shift; continue
    fi

    [ "$sign" = '=' ]  &&  { op=set; sign=; }
    SEL=$(seldecode $sel | sort -g | uniq)
    
    case "$prop" in S|L)
      case "$val" in
        0.*|.*)       ;;
           100) val=1 ;;
          ??|?) val=$(printf .%02d $val) ;;
      esac ;;
    esac

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
