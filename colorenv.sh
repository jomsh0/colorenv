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

fmtPairSh() { echo "$1=$2"; }
fmtPair() { echo "${1##*_} = #$2"; }

listEnv() {
    local key val fmtcmd
    case "$1" in
      pretty) fmtcmd=fmtPair   ;;
           *) fmtcmd=fmtPairSh ;;
    esac
    for key in $ENV_KEYS; do
        eval val=\$$key
        [ "$val" ] || [ "$1" = all ] || continue
        $fmtcmd "$key" "$val"
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
values.sh - guaranteed to never matter in any way, shape, or form.

USAGE:
    values.sh <command> [args ...]  [--] [colors ...]

    Colors can be provided on stdin, or following `--` on the command line.

COMMANDS:
    darken
    generate
    set-env
    unset-env
    list-env
###
}

generate() {
    local yellow red blue
    yellow=ffff00 red=ff0000 blue=0000ff

    pastel color $yellow
}

darken() {
    local Cin Cout
    for Cin in $(eval echo $colorEnv); do
        for q in  0.2  0.4  0.6; do
        #for C in $(pastel darken 0.2 "$@" $stdin); do
            Cout=$(eval pastel darken $q $Cin)
            echo "$Blurb" | pastel paint $Cout
        done
    done
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
 (sete*)  Cmd=setEnv    ;;
  dark*)  Cmd=darken    ;;
   gen*)  Cmd=generate  ;;
(un?et*)  Cmd=unsetEnv  ;;
      *)  _help; exit 1 ;;
esac   \
    && shift

$Cmd "$@"
