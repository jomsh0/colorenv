#!/usr/bin/env sh

set -o pipefail

Blurb="\
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Semper
risus in hendrerit gravida rutrum. Praesent tristique magna sit amet
"
ANSI_ORDER='black red green yellow blue magenta cyan white'
EXT_KEYS='foreground background'

Pfx=ColorEnv

alternates() {
    local IFS
    IFS='|'
    echo "$*" && unset IFS
}

unsetEnv() { echo unset $Pfx; }

fatal() { error "$@"; exit 1; }
error() { echo '[colorenv error]:' "$@" >&2; return 1; }

initEnv() {
    local ent key val
    eval set -- \$$Pfx
    for ent; do
        key=${ent%%=*} val=${ent#*=}
        [ ${#key} -ne ${#ent} ] || { error "bad entry $ent"; continue; }
        eval ${Pfx}_$key=$val
    done
}

listEnv() { set | sed -n "/^${Pfx}_/{s/^${Pfx}_//; p}"; }
saveEnv() { echo $Pfx=\'$(listEnv)\'; }

validate_cVal() {
    local work v_lo v_hi2 x tmp
    # caller has to provide a local cVal binding

    work=${1##[!0-9a-f]}

    tmp=$(printf %x "0x$work" 2>/dev/null) || {
        work=$(echo "$work" | sed 's^/^^g')
        tmp=$(printf %x "0x$work" 2>/dev/null)
    } || return 1

    work=$tmp
    [ ${#work} -eq 6 ] && { cVal=$work; return 0; }
    [ ${#work} -ne 3 ] && return 1

    v_lo=${work#??} v_hi2=${work%?} cVal=
    for x in ${v_hi2%?} ${v_hi2#?} ${v_lo}; do
        cVal=$cVal$x$x
    done
}

try_pastel() {
    local work
    work=$(pastel format hex "$1") && validate_cVal "$work"
}

_setEnv() {
    local cPair cName cVal envKey idx

    idx=0
    for cPair; do
        case "$cPair" in
          *=*) cVal=${cPair#*=} cName=${cPair%%=*}
               matchKey "$cName" || error "unable to match $cName" ;;
            *) cVal=$cPair; envKey=$idx; idx=$((1 + $idx))
               [ $idx -lt 256 ] || error 'only indices 0-255 allowed' ;;
        esac || return 1

        validate_cVal "$cVal"    ||
            try_pastel "$cVal"   ||
                { error "invaid color value: $cVal"; return 1; }

        echo $envKey=$cVal
    done
}

setEnv() {
    local envStr
    envStr=$(_setEnv $COLOR_ARGS) && echo "$envStr" && return
    error -f 'problem setting environment. no changes made.'
}

matchKey() {
    local off clr e

    off=0
    echo "$1" | grep -qiE 'bright|bold' && off=8

    clr=$(echo "$1" |
        grep -sioE "$(alternates $ANSI_ORDER purple $EXT_KEYS)" |
        tr '[:upper:]' '[:lower:]'
    ) || return 1
    [ "$clr" = purple ] && clr=magenta

    case "$clr" in
      black)  e=$off ;;
        red)  e=$((1 + $off)) ;;
      green)  e=$((2 + $off)) ;;
     yellow)  e=$((3 + $off)) ;;
       blue)  e=$((4 + $off)) ;;
    magenta)  e=$((5 + $off)) ;;
       cyan)  e=$((6 + $off)) ;;
      white)  e=$((7 + $off)) ;;
          *)  e=$clr ;;
    esac

    envKey=${Pfx}_$e
}

rgb_str() {
    local cVal v_lo
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
    
    for seq in $(seq 0 15); do
        eval initc $seq \$${Pfx}_$seq
        eval initc $((8 + $seq)) \$${Pfx}_$((8 + $seq))
    done
    
    eval fg=\${${Pfx}_foreground:-\$${Pfx}_7}
    eval bg=\${${Pfx}_background:-\$${Pfx}_0}
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

_help() { cat >&2 <<'###'
colorenv.sh

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

case "$1" in
   list*)  Cmd=listEnv   ;;
   apply)  Cmd=colorENV  ;;
  se[t]*)  Cmd=setEnv    ;;
unse[t]*)  Cmd=unsetEnv  ;;
       *)  _help; exit 1 ;;
esac    \
    && shift

$Cmd "$@"
