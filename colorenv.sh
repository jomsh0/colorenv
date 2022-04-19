#!/usr/bin/env sh

set -o pipefail

Blurb="\
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Semper
risus in hendrerit gravida rutrum. Praesent tristique magna sit amet
"
ANSI_ORDER='black red green yellow blue magenta cyan white'
EXT_KEYS='foreground background'
Pfx=colorENV

alternates() {
    local IFS
    IFS='|'
    echo "$*" && unset IFS
}

fatal() { error "$@"; exit 1; }
error() { echo '[colorenv error]:' "$@" >&2; return 1; }

loadEnv() {
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
    local work v_lo v_hi2 x
    # caller has to provide a local cVal binding

    cVal=${1###}
    [ ${#cVal} -eq 8 ] && cVal=$(echo "$cVal" | sed 's^/^^g')

    work=$(printf %0${#cVal}x "0x$cVal" 2>/dev/null) || return 1

    cVal=$work
    [ ${#cVal} -eq 6 ] && return 0
    [ ${#cVal} -ne 3 ] && return 1

    v_lo=${cVal#??} v_hi2=${cVal%?}
    cVal=
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
        esac || continue

        validate_cVal "$cVal"    ||
            try_pastel "$cVal"   ||
                { error "invalid color value: $cVal"; continue; }

        echo ${Pfx}_$envKey=$cVal
    done
}

setEnv() {
    local envStr
    envStr=$(_setEnv $COLOR_ARGS) && eval "$envStr" && return
    fatal 'problem setting environment. no changes made.'
}

matchKey() {
    local off clr e

    off=0
    echo "$1" | grep -qiE 'bright|bold' && off=8

    # TODO: idk
    [ "$1" = "selectionBackground" ] && return 1

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
    envKey=$e
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
    [ -t 2 ] || fatal 'stderr must be connected to a terminal'
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

t_a_b=$(printf '\e[1m')
t_a_u=$(printf '\e[4m')
t_a_0=$(printf '\e[0m')

_help() { cat >&2; exit 1; } <<EOF
${t_a_u}colorenv.sh${t_a_0}

${t_a_b}USAGE:${t_a_0}
    colorenv.sh <command> [args ...]  [--] [colors ...]

    Colors can be provided on stdin, or following \`--\` on the command line.

${t_a_b}COMMANDS${t_a_0}:
    list
    apply
    reset
EOF

unset OPTARG OPTIND
while getopts 'h' opt; do
  case "$opt" in
    h) _help ;;
   \?) _help ;;
  esac
done
shift $((OPTIND - 1))

if [ "$1" ]; then _cmd=$1; shift
else _cmd=list; fi

case "$_cmd" in
    list)  Cmd=listEnv   ;;
   apply)  Cmd=colorENV  ;;
rese[t]*)  Cmd=resetEnv  ;;
       *)  _help         ;;
esac

[ "$Cmd" = resetEnv ] || loadEnv
COLOR_ARGS=$(cmdlineColors "$@"; echo; stdinColors)
setEnv
[ "$Cmd" = resetEnv ] || $Cmd "$@"
saveEnv
