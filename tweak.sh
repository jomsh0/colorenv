#!/usr/bin/env sh

CLenv=$(dirname "$0")/colorenv.sh
Pastel='pastel -m off'
P_fmt=$Pastel\ format

type ce_setEnv >/dev/null 2>&1 ||
    . $CLenv

  _tw_init() { [ -t 0 ] && ./rebase16.sh ${theme:-default-dark}; } # or cat
   tw_init() { ce_setEnv $(_tw_init); }

tw_lines() {
    local seq
    [ "$1" -gt 0 ] || return 1
    for seq in $(seq 1 "$1"); do read line; echo $line; done
}

tw_Select() {
    local hi lo size nxt s
    [ "$sel" ] || { cat; return; }
  
    hi=-1   # zero index
    for s in $(tw_seldecode $sel); do
        nxt=${s%%[!0-9]*}
        size=$((nxt - hi - 1)) 2>/dev/null ||
            { ce_error "decoded selection $s invalid"; return 1; }

        if ! [ "$1" ] && [ $size -gt 0 ]; then
            tw_lines $size >/dev/null
        fi

        lo=${s%[!0-9]*}  hi=${s#*[!0-9]}
        size=$((hi - lo + 1)) 2>/dev/null ||
            { ce_error "decoded selection $s invalid"; return 1; }

        [ $size -gt 0 ]  ||  continue

        if ! [ "$1" ]; then
            tw_lines $size
        else for ln in $(tw_lines $size); do
            [ $lo -le $hi ] || continue
            echo $lo=$ln
            lo=$((lo + 1))
        done fi
    done
    cat >/dev/null
}

tw_selsplit() {
    local IFS s; IFS=$IFS,
    set -- $@; IFS=${IFS%,}
    for s; do
      case "$s" in
       *[!0-9-]*) echo $s | { while read -n1 c; do echo $c; done; };;
               *) echo $s ;;
      esac
    done
}

SEL_C_BRI=9-14
SEL_C_REG=1-6
SEL_BW_BRI=8,15  SEL_BW_REG=0,7
SEL_C=$SEL_C_REG,$SEL_C_BRI
SEL_BW=$SEL_BW_REG,$SEL_BW_BRI
SEL_ALL=$SEL_C,$SEL_BW

tw_seldecode() {
    local ansi sel
    for sel in $(tw_selsplit $@); do
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
         =) tw_selsplit $SEL_ALL    ;;
         .) tw_selsplit $SEL_C_REG  ;;
         ^) tw_selsplit $SEL_C_BRI  ;;
         /) tw_selsplit $SEL_C      ;;
         _) tw_selsplit $SEL_BW     ;;
        esac
    done | sort -g | uniq
}

RED_="[31;01m"
GREE="[32;01m"
YELL="[33;01m"
BLUE="[34;01m"
MAGE="[35;01m"
CYAN="[36;01m"
BRED_="[91m"
BGREE="[92m"
BYELL="[93m"
BBLUE="[94m"
BMAGE="[95m"
BCYAN="[96m"
BOLD="[1m"
ULIN="[4m"
OFF="[0m"

tw_usage() { cat >&2; exit 1; } <<EOF
${BOLD}colorenv${OFF} — John Sherrell
  Ad-hoc terminal color palette transformations with the help of \`pastel\`.

${ULIN}USAGE${OFF}
      colorenv  [command...]

${ULIN}COMMANDS${OFF}
  Commands have the form ${CYAN}V${OFF}(${YELL}=${OFF}|${YELL}+${OFF}|${YELL}-${OFF})${GREE}n${OFF}[${BLUE}:S${OFF}]

  ${CYAN}V${OFF}   Value to modify; enumerated below.
  ${YELL}=${OFF}   Set the property.
  ${YELL}+-${OFF}  Adjust the property.
  ${GREE}n${OFF}   Numeric value.
  ${BLUE}S${OFF}   The selection of colors to modify.

      ${ULIN}Value${OFF}        ${ULIN}Range${OFF}    ${ULIN}Default Selection${OFF}
  ${BOLD}H${OFF}   Hue          0-360    all (12) colors
  ${BOLD}S${OFF}   Saturation   0-100    all (12) colors
  ${BOLD}L${OFF}   Lightness    0-100    all (16)
  ${RED_}R${OFF}   Red          0-255    all (12) colors
  ${GREE}G${OFF}   Green        0-255    all (12) colors
  ${BLUE}B${OFF}   Blue         0-255    all (12) colors

${ULIN}SELECTORS${OFF}
  The selection can be any combination of color initials:
  (k) black, (w) white, ${RED_}(r)${OFF} red, ${GREE}(g)${OFF} green, ${YELL}(y)${OFF} yellow, ${BLUE}(b)${OFF} blue,
  ${MAGE}(m)${OFF} magenta, or ${CYAN}(c)${OFF} cyan.

  The corresponding capital letters select the ${BRED_}b${BGREE}r${BYELL}i${BBLUE}g${BMAGE}h${BCYAN}t${OFF} ${BRED_}v${BGREE}a${BYELL}r${BBLUE}i${BMAGE}a${BCYAN}n${BRED_}t${BGREE}s${OFF} of the
  same colors.

  Additionally, there are several wildcard selectors:
  ${CYAN}.${OFF}   all 6 regular colors
  ${BRED_}^${OFF}   all 6 bright colors
  ${BLUE}/${OFF}   all 12 colors (regular and bright)
  ${YELL}=${OFF}   all 16 colors (including blacks and whites)
  ${BOLD}_${OFF}   all 4 blacks and whites (both regular and bright variants)

EOF

tw_decodeOpt() {
    local work prop
    op= sign=  sel=${1##*[:0-9]} work=${1#?}
    prop=${1%$work} work=${work%$sel}
    val=${work#?}   sign=${work%%[!=+-]*}
    val=${val%:}

    if ! [ ${#prop} -eq 1  -a  ${#sign} -eq 1 ]; then
        ce_error "couldn't parse $1"; return 1
    fi

    [ "$sign" = '=' ]  &&  { op=set; sign=; }
  
    case "$prop" in S|L)
       case "$val" in
       0.*|.*)       ;;
          100) val=1 ;;
         ??|?) val=$(printf .%02d $val) ;;
      esac ;;
    esac

    case "$prop" in
      H) prop=hsl-hue        op=${op:-rotate}   sel=${sel:-$SEL_C} ;;
      S) prop=hsl-saturation op=${op:-saturate} sel=${sel:-$SEL_C} ;;
      L) prop=hsl-lightness  op=${op:-lighten}   ;;
      R) prop=red    op=set  sel=${sel:-$SEL_C}  ;;
      G) prop=green  op=set  sel=${sel:-$SEL_C}  ;;
      B) prop=blue   op=set  sel=${sel:-$SEL_C}  ;;
      X) op=mix   ;;
      *) return 1 ;;
    esac

    if [ "$op" = set ]; then op="set $prop"; fi
}

tw_cmd1() {
    local sel op val sign cat
    tw_decodeOpt "$@" || return 1
    tw_Select | $Pastel $op $sign$val | $P_fmt | tw_Select inv
}

tw_Cmd() {
    while [ $# -gt 0 ]; do
        ce_setEnv $(ce_array | tw_cmd1 "$1")
        shift
    done
}

while [ $# -gt 0  -a  -z "${1%%-*}" ]; do
  case "$1" in
    -t) theme=$2; shift 2 ;;
    -h) tw_usage ;;
     *) shift ;;
  esac
done

if [ $(basename "$0") = tweak.sh ]; then
    tw_init
    tw_Cmd "$@"
    ce_colorENV  #-D
fi
