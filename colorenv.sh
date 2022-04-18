#!/usr/bin/env sh

set -e -o pipefail

Blurb="\
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Semper
risus in hendrerit gravida rutrum. Praesent tristique magna sit amet
"
ANSI_ORDER='black red green yellow blue magenta cyan white'

pfx_=CLenv_

envKeys() {
    local count clr
    set -- $ANSI_ORDER
    for seq in $(seq 0 7); do
        eval clr=\$$((1+$seq))
        echo ${pfx_}r${seq}_$clr
        echo ${pfx_}b${seq}_b_$clr
    done
    echo ${pfx_}tty_FG ${pfx_}tty_BG
}

regex() {
    local IFS
    IFS='|'
    echo "$*" && unset IFS
}

ENV_KEYS=$(envKeys)

unsetEnv() { echo unset $ENV_KEYS; }

error() {
    echo '[colorenv]' ERROR: "$@" >&2
    return 1
}

_validGrep() { grep -soE '^[0-1a-f]{6}$'; }
_validVal() { [ "$1" ] && echo "$1" | _validGrep >/dev/null 2>&1; }
validVal() {
    local val
    echo "${1###}" | _validGrep \
        && return

    echo "${1###}" | sed -e '1{ s|/||g; y/A-F/a-f/ }' | _validGrep \
        && return

    val=$(pastel format hex "$1") && echo "${val###}"
}

_setEnv() {
    local Name Val evnName

    for Name; do
        case "$Name" in
         *=*)  Val=${Name#*=}; Name=${Name%%=*};;
           *)  error 'colors need to be in name=value format'; return 1;;
        esac

        Val=$(validVal "$Val") || error "invaid color value: $Val"
        envName=$(matchName "$Name") || error "invalid color name: $Name"

        echo $envName=$Val
    done
}

setEnv() {
    envStr=$(_setEnv "$@") && echo "$envStr" && return;
    error "problem setting environment. no changes made."
}

fmt_sh() { echo "$1=$2"; }
fmt_pretty() { echo "${1##*_} = #$2"; }
fmt_parse() {
    local base name st num
    name=${1##*_} base=${1#$pfx_}
    base=${base%%_*}
    st=${base%?} num=${base#?}

    case "$st:$num" in [rb]:[0-7]) ;;
      *) return 1 ;;
    esac
    echo $st $num $name $2
}

listEnv() {
    local key val fmtcmd opt all

    while getopts 'apm' opt; do
    case "$opt" in
       p) fmtcmd=fmt_pretty ;;
       m) fmtcmd=fmt_parse  ;;
       a) all=all           ;;
    esac
    done
    for key in $ENV_KEYS; do
        eval val=\$$key
        _validVal "$val" || [ "$all" ] || continue
        ${fmtcmd:-fmt_sh} "$key" "$val"
    done
}

matchName() {
    local br clr key
    echo "$1" | grep -qi bright && br=1
    clr=$(echo "$1" | grep -sioE "$(regex $ANSI_ORDER purple)") || return 1
    clr=$(echo "$clr" | tr '[:upper:]' '[:lower:]')
    [ "$clr" = "purple" ] && clr=magenta

    if [ "$br" ]; then pattern="*_b[0-9]_b_$clr"
    else pattern="*_r[0-9]_$clr"
    fi

    for key in $ENV_KEYS; do
        case $key in $pattern) echo $key; return 0;; esac
    done
    return 1
}

_help() { cat >&2 <<'###'
colorenv.sh - guaranteed to never matter in any way, shape, or form.

USAGE:
    colorenv.sh <command> [args ...]  [--] [colors ...]

    Colors can be provided on stdin, or following `--` on the command line.

COMMANDS:
    list-env
    set-env
    apply-env
    unset-env
###
}

# caller's job to make sure stdout is something reasonable.
esc() {
    local rgb
    [ "$1" -lt 256 ] || return 1

    rgb=$(echo "$2" | grep -osE '[[:xdigit:]]{2}')
    set -- $1 $rgb && [ 4 -eq $# ] &&
        printf '\e]4;%i;rgb:%s/%s/%s\e\' "$@"
}

escEnv() {
    listEnv -m | while read st num name val; do
        case "$st" in  r) base=0;;  b) base=8;;  *) continue;; esac
        idx=$(($num + $base))
        esc "$idx" "$val"
    done
}

colorENV() {
    [ -t 2 ] || error 'stderr must be connected to a terminal'
    listEnv && escEnv >&2
}

cmdlineColors() {
    while [ $# -gt 0 ]; do
        [ "$1" = '--' ] && break
        shift
    done
    [ "$1" ] || return 0
    shift && echo "$@"
}

stdinColors() {
    [ -t 0 ] && return 0
    set -- $(cat) && echo "$@"
}

CLR_ARGS=$(cmdlineColors; echo; stdinColors)

case "$1" in
   list*)  Cmd=listEnv   ;;
   apply)  Cmd=colorENV  ;;
  se[t]*)  Cmd=setEnv    ;;
unse[t]*)  Cmd=unsetEnv  ;;
       *)  _help; exit 1 ;;
esac    \
    && shift

$Cmd "$@"
