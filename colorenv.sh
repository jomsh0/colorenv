#!/usr/bin/env sh

set -o pipefail

Blurb="\
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Semper
risus in hendrerit gravida rutrum. Praesent tristique magna sit amet
"
ANSI_ORDER='black red green yellow blue magenta cyan white'
EXT_CLR_KEYS='foreground background'
EXT_ETC_KEYS='name'

Pfx=ColorENV

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

listEnv() {
    set | grep -E "^$Pfx\_([0-9]+|$(alternates $EXT_CLR_KEYS $EXT_ETC_KEYS))=" \
        | sed "s/^$Pfx\_//;s/'//g" \
        | sort -g
}

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

        # These don't need to be validated as colors
        if ! case " $EXT_ETC_KEYS " in (*\ $envKey\ *) true;; *) false;; esac &&
                ! validate_cVal "$cVal" &&
                ! try_pastel    "$cVal"  ;
        then { error "invalid color value: $cVal"; continue; } fi

        echo ${Pfx}_$envKey=$cVal
    done
}

mapFB() {
    local cVal match st
    if validate_cVal "$fg"; then
        match=$(listEnv | grep -s -m1 =$cVal\$) && fg=${match%%=*}
    fi
    st=$?
    if validate_cVal "$bg"; then
        match=$(listEnv | grep -s -m1 =$cVal\$) && bg=${match%%=*}
    fi || return 1
    return $st
}

unmapFB() {
    local cVal st

    eval cVal=\$$Pfx\_$fg && validate_cVal "$cVal" && fg=$cVal
    st=$?
    eval cVal=\$$Pfx\_$bg && validate_cVal "$cVal" && bg=$cVal
    return $(($st + $?))
}

setEnv() {
    local envStr fg bg cVal

    envStr=$(_setEnv $COLOR_ARGS) || fatal 'problem setting environment. no changes made.'

    case "$_autofb" in
      K|M)  eval  fg=\$$Pfx\_foreground  bg=\$$Pfx\_background  ;;
    esac
    [ "$_autofb" = M ] && mapFB

    eval "$envStr"
    [ "$_autofb" ] || return

    case "$_autofb" in
        M)  unmapFB ;;
        L)  eval fg=\$$Pfx\_0 bg=\$$Pfx\_7 ;;
        D)  eval fg=\$$Pfx\_7 bg=\$$Pfx\_0 ;;
    esac

    if validate_cVal "$fg"; then eval $Pfx\_foreground=$cVal
    else error "[auto fg/bg = $_autofb] couldn't validate fg=$fg"; fi

    if validate_cVal "$bg"; then eval $Pfx\_background=$cVal
    else error "[auto fg/bg = $_autofb] couldn't validate bg=$bg"; fi
}

matchKey() {
    local off clr e

    off=0
    echo "$1" | grep -qiE 'bright|bold' && off=8

    clr=$(echo "$1" | grep -sioE "$(alternates $ANSI_ORDER purple)") \
        || clr=$1
    clr=$(echo "$clr" | tr '[:upper:]' '[:lower:]')

    [ "$clr" = purple ] && clr=magenta

    case "$clr" in
      black)  envKey=$off ;;
        red)  envKey=$((1 + $off)) ;;
      green)  envKey=$((2 + $off)) ;;
     yellow)  envKey=$((3 + $off)) ;;
       blue)  envKey=$((4 + $off)) ;;
    magenta)  envKey=$((5 + $off)) ;;
       cyan)  envKey=$((6 + $off)) ;;
      white)  envKey=$((7 + $off)) ;;
          *)  false ;;
    esac && return

    # misc. whitelist
    eval "case $clr in
        $(alternates $EXT_CLR_KEYS $EXT_ETC_KEYS)) envKey=$clr ;;
        *) return 1 ;;
        esac"
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

stdinColors() {
    [ -t 0 ] && return 0
    set -- $(cat) && echo "$@"
}

t_a_b=$(printf '\e[1m') t_a_u=$(printf '\e[4m') t_a_0=$(printf '\e[0m')

_help() { cat >&2; exit 1; } <<EOF
${t_a_u}colorenv.sh${t_a_0}

${t_a_b}USAGE:${t_a_0}
    colorenv.sh  [-l|-a] [-r] [colors ...]

    Colors can be provided on stdin, or following options on the command line.

${t_a_b}OPTIONS${t_a_0}:
  -l  list
  -a  apply
  -r  reset
EOF

unset OPTARG OPTIND
while getopts 'larhLDKM' opt; do
  case "$opt" in
    l) _list=1  ;;
    a) _apply=1 ;;
    r) _reset=1 ;;
L|D|K|M) _autofb=$opt ;;
    h) _help ;;
   \?) _help ;;
  esac
done
shift $((OPTIND - 1))

[ "$_reset" ] || loadEnv

COLOR_ARGS=$(echo "$@"; stdinColors)
setEnv

[ "$_apply" ] &&  colorENV
[ "$_list"  ] &&  listEnv &&  exit # keep stdout coherent
saveEnv
