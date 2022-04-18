#!/usr/bin/env sh

set -e -o pipefail

Blurb="\
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Semper
risus in hendrerit gravida rutrum. Praesent tristique magna sit amet
"
ANSI_ORDER='black red green yellow blue magenta cyan white'

pfx_=Ce_

envKeys() {
    local count clr
    set -- $ANSI_ORDER
    for seq in $(seq 0 7); do
        eval clr=\$$((1+$seq))
        echo ${pfx_}r${seq}_$clr
        echo ${pfx_}B${seq}_$clr
    done
    echo ${pfx_}tty_fg ${pfx_}tty_bg
}

regex() {
    local IFS
    IFS='|'
    echo "$*" && unset IFS
}

ENV_KEYS=$(envKeys)

save_map() {
    local seq key clr st
    set -- $ANSI_ORDER

    for seq in $(seq 0 7); do
        eval clr=\$$((1+$seq))
        for st in r B; do
            key=__${pfx_}$st$seq
            eval "$key=$clr"
        done
    done
}
save_map

_map() { eval echo \$__${pfx_}$1; }

unsetEnv() { echo unset $ENV_KEYS; }

error() {
    echo '[colorenv]' ERROR: "$@" >&2
    return 1
}

_validGrep() { grep -oisE '^[0-9a-f]{6}$'; }
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
    envStr=$(_setEnv $COLOR_ARGS) && echo "$envStr" && return;
    error "problem setting environment. no changes made."
}

fmt_sh() { echo "$1=$2"; }
fmt_pretty() { echo "${1##*_} = #$2"; }
fmt_parse() {
    local base name st num
    name=${1##*_} base=${1#$pfx_}
    base=${base%%_*}
    st=${base%?} num=${base#?}

    case "$st:$num" in [rB]:[0-7]) ;;
      *) return 1 ;;
    esac
    echo $st $num $name $2
}

listEnv() {
    local key val fmtcmd opt all

    unset OPTIND OPTARG
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

    if [ "$br" ]; then pattern="*_B[0-9]_$clr"
    else pattern="*_r[0-9]_$clr"
    fi

    for key in $ENV_KEYS; do
        case $key in $pattern) echo $key; return 0;; esac
    done
    return 1
}

_help() { cat >&2 <<'###'
colorenv.sh — Something to fiddle with.

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
emitEsc() {
    local rgb
    rgb=$(echo "$2" | grep -osE '[[:xdigit:]]{2}')
    set -- "$1" $rgb && [ 4 -eq $# ] &&
        printf '\e]%s;rgb:%s/%s/%s\e\' "$@"
}

escEnv() {
    local _fg _bg fg_val bg_val
    listEnv -m | while read st num name val; do
        case "$st" in  r) base=0;;  B) base=8;;  *) continue;; esac
        idx=$(($num + $base))
        emitEsc "4;$idx" "$val"
    done

    eval _fg="\${${pfx_}tty_fg:-r7}"             &&
        eval fg_val=\$${pfx_}${_fg}_$(_map $_fg) &&
        _validVal "$fg_val"                      &&
        emitEsc 10 "$fg_val"

    eval _bg="\${${pfx_}tty_bg:-r0}"             &&
        eval bg_val=\$${pfx_}${_bg}_$(_map $_bg) &&
        _validVal "$bg_val"                      &&
        emitEsc 11 "$bg_val"
}

colorENV() {
    [ -t 2 ] || error 'stderr must be connected to a terminal'
    escEnv >&2
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

COLOR_ARGS=$(cmdlineColors; echo; stdinColors)

case "$1" in
   list*)  Cmd=listEnv   ;;
   apply)  Cmd=colorENV  ;;
  se[t]*)  Cmd=setEnv    ;;
unse[t]*)  Cmd=unsetEnv  ;;
       *)  _help; exit 1 ;;
esac    \
    && shift

$Cmd "$@"
