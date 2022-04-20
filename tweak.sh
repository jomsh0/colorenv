#!/usr/bin/env sh

CLenv=./colorenv.sh

_init() { [ -t 0 ] && ./rebase16.sh ${theme:-default-dark}; } # or cat
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
    && [ "$size" -gt 0 ]         \
    && lines "$size" >&30

    lo=${1%[!0-9]*}  hi=${1#*[!0-9]}
    size=$(("$hi" - "$lo" + 1)) \
    && [ "$size" -gt 0 ]        \
    && lines "$size"

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

bright() { $Past lighten ${1:-0.1}; }
 desat() { $Past desaturate ${1:-0.15}; }
darken() { $Past darken ${1:-0.15}; }
   mix() { $Past mix "$@"; }

init() { eval export $(_init | $CLenv "$@"); }
exe() {
  local Cmd; Cmd=$1; shift
  eval export $(cap | $Sel $SEL \| $Cmd "$@" | save)
}

Cmd() {
  local SEL
  case "$OPTARG" in *[a-zA-Z0-9]*);; *) OPTARG=;; esac
  case "$opt" in
   t) theme=$OPTARG ;;
   D) SEL=$COL        exe desat  $OPTARG ;;
   d) SEL=$WHT        exe darken $OPTARG ;;
   m) SEL=            exe mix    $OPTARG ;;
   B) SEL=$BRI_COL    exe bright $OPTARG ;;
   :) opt=$OPTARG OPTARG= Cmd ;;
  esac
}

init; unset OPTIND OPTARG
while getopts ':t:D:d:m:B:' opt; do Cmd; done
# shift $(($OPTIND - 1))
cap | apply -D
