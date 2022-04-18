#!/usr/bin/env sh

set -o pipefail

Blurb="\
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Semper
risus in hendrerit gravida rutrum. Praesent tristique magna sit amet
"
ANSI_ORDER='black red green yellow blue magenta cyan white'

pfx_=Ce_

envKeys() {
    local clr
    for clr in $ANSI_ORDER; do
        echo ${pfx_}$clr;
        echo ${pfx_}B_$clr;
    done
    echo ${pfx_}foreground ${pfx_}background
}

regex() {
    local IFS
    IFS='|'
    echo "$*" && unset IFS
}

ENV_KEYS=$(envKeys)

unsetEnv() { echo unset $ENV_KEYS; }

error() {
    local fatal
    if [ "$1" = '-f' ]; then fatal=1; shift; fi

    echo '[colorenv error]:' "$@" >&2

    [ "$fatal" ] && exit 1
    return 1
}

validate_cVal() {
    local v_lo v_hi2 x
    # : ${cVal?}
    # tring 'dynamic scoping' out.
    # caller has to provide a local cVal binding
    cVal=${1##[!0-9a-f]}
    # cVal=${cVal%%[!0-9a-f]}
    cVal=$(printf %x "0x$cVal" 2>/dev/null) || return 1
    [ ${#cVal} -eq 6 ] && return 0
    [ ${#cVal} -ne 3 ] && return 1

    v_lo=${cVal#??} v_hi2=${cVal%?}
    cVal=
    for x in ${v_hi2%?} ${v_hi2#?} ${v_lo}; do
        cVal=$cVal$x$x
    done
}
try_pastel() { cVal=$(pastel format hex "$1") && validate_cVal "$cVal"; }

_setEnv() {
    local cPair cName cVal cVcopy envKey

    for cPair; do
        cVal=${cPair#*=} cName=${cPair%%=*}
        [ ${#cPair} -gt ${#cVal} ] ||
           { error 'colors need to be in name=value format'; return 1; }

        cVcopy=$cVal
        validate_cVal "$cVal"    ||
            try_pastel "$cVcopy" ||
                { error "invaid color value: $cVcopy"; return 1; }

        cName_to_envKey "$cName" ||
                { error "invalid color name: $cName"; return 1; }

        echo $envKey=$cVal
    done
}

setEnv() {
    local envStr
    envStr=$(_setEnv $COLOR_ARGS) && echo "$envStr" && return
    error -f 'problem setting environment. no changes made.'
}

fmt_sh() { echo "$1=$2"; }
fmt_pretty() { echo "${1##*_} = #$2"; }

listEnv() {
    local cVal key fmtcmd all opt OPTIND OPTARG

    while getopts 'pa' opt; do
    case "$opt" in
       p) fmtcmd=fmt_pretty ;;
       a) all=all           ;;
    esac
    done
    for key in $ENV_KEYS; do
        eval cVal=\$$key
        validate_cVal "$cVal" || [ "$all" ] || continue
        ${fmtcmd:-fmt_sh} "$key" "$cVal"
    done
}

cName_to_envKey() {
    local B_ clr
    # : ${envKey?}
    echo "$1" | grep -qiE 'bright|bold' && B_=B_
    clr=$(echo "$1" |
        grep -sioE "$(regex $ANSI_ORDER purple foreground background)" |
        tr '[:upper:]' '[:lower:]'
    ) || return 1
    [ "$clr" = purple ] && clr=magenta
    [ "$B_" ] && [ "$clr" = foreground -o "$clr" = background ] && B_=
    envKey=${pfx_}${B_}$clr
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

rgb_str() {
    local cVal v_lo
    # : ${rgb?}
    validate_cVal "$1" || return 1
    v_lo=${cVal#??}
    rgb=${cVal%????}/${v_lo%??}/${v_lo#??}
}

_initc() { printf '\e]%s;rgb:%s\e\' "$@"; }

initc() {
    local rgb
    [ "$1" -lt 256 ] || return 1
    rgb_str "$2"     || return 1
    _initc "4;$1" "$rgb"
}

initc_fb() {
    local code rgb
    rgb_str "$1" && _initc 10 "$rgb"
    rgb_str "$2" && _initc 11 "$rgb"
}

escEnv() {
    local seq clr fg bg
    set -- $ANSI_ORDER
    
    for seq in $(seq 0 7); do
        eval clr=\$$((1 + $seq))
        eval initc $seq \$$pfx_$clr
        eval initc $((8 + $seq)) \$${pfx_}B_$clr
    done
    
    eval fg=\${${pfx_}foreground:-\$${pfx_}white}
    eval bg=\${${pfx_}background:-\$${pfx_}black}
    eval initc_fb "$fg" "$bg"
}

colorENV() {
    [ -t 2 ] || error -f 'stderr must be connected to a terminal'
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

COLOR_ARGS=$(cmdlineColors "$@"; echo; stdinColors)

case "$1" in
   list*)  Cmd=listEnv   ;;
   apply)  Cmd=colorENV  ;;
  se[t]*)  Cmd=setEnv    ;;
unse[t]*)  Cmd=unsetEnv  ;;
       *)  _help; exit 1 ;;
esac    \
    && shift

$Cmd "$@"
