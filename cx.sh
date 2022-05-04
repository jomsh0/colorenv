#!/usr/bin/env sh

set -o pipefail

B16DIR=~/.themes/shell/scripts
export BAT_THEME=base16-256 BAT_STYLE=numbers
export FZF_DEFAULT_OPTS="--color=16,border:gray +s --ansi --cycle --height=60% --no-info --preview=bat\ -f\ colorx.c"
EXP_Keys=left,right,alt-left,alt-right,shift-left,shift-right
colorx=$(dirname $0)/colorx

 dark() { color_foreground=$color07 color_background=$color00; }
light() { color_foreground=$color00 color_background=$color07; }

colorENV() { :; set | grep -E '^color[_0-9]' | sed "s/[/'\"]//g"; }
  exPort() { eval export $(colorENV); }
allPairs() { colorENV | sed 's/^color[_0]\?//'; }

fmtColor() {
    set -- $(echo $color | grep -oE '[[:xdigit:]]{2}')
    [ $# -eq 3 ]  &&  color=$1/$2/$3
}

initc() { printf '\e]%s;rgb:%s\e\' "$1" "$2" >&2; }
initC() {
    local pair n color
    for pair in $(allPairs); do
        n=${pair%%=*}  color=${pair##*=}
        case "$n" in *[!0-9]*) continue ;; esac;
        fmtColor  &&  initc 4\;$n $color
    done
    color=$color_foreground; fmtColor && initc 10 $color
    color=$color_background; fmtColor && initc 11 $color
}
theme() {
    [ -r "$B16DIR/base16-$1.sh" ] &&
    eval "$(grep -oE '^color[_0-9]\S+' "$B16DIR/base16-$1.sh")" &&
    exPort && initC
}
explodeRange() {
    local IFS r
    IFS=$IFS,; set -- $@; IFS=${IFS%,}
    for r; do
      case "$r" in
      *[!0-9-]*) continue ;;
          *-*-*) continue ;;
            *-*) seq ${r%-*} ${r#*-} ;;
              *) echo $r  ;;
      esac
    done | sort -g | uniq
}
colorKeyN() { printf color%02d "$1"; }
colors() {
    for n; do
        case "$n" in
            foreground|background) eval echo \$color_$n; continue ;;
        esac
        [ "$n" -ge 0 ]              &&
        eval echo \$$(colorKeyN $n) ||
        return 1
    done
}

error() { echo '[cx error]: ' $@ >&2; return 1; }

key2inc() {
    case "$1" in
       left) echo \-3  ;;
      right) echo 3    ;;
   alt-left) echo \-1  ;;
  alt-right) echo 1    ;;
 shift-left) echo \-10 ;;
shift-right) echo 10   ;;
          *) return 1  ;;
    esac
}
colorAssn() {
    case "$1" in
  foreground|background) eval color_$1=$2; return ;;
               *[!0-9]*) return 1 ;;
    esac
    eval $(colorKeyN $1)=$2
}
NCassn() {
    local N C n_fg n_bg; N=$1 C=$2
    case "$N" in *background*);; *) set -- $(colors $N); for n in $N; do [ "$1" = "$color_background" ] && n_bg=$n && break || shift; done;; esac
    case "$N" in *foreground*);; *) set -- $(colors $N); for n in $N; do [ "$1" = "$color_foreground" ] && n_fg=$n && break || shift; done;; esac
    set -- $C
    for n in $N; do
        colorAssn $n $1 || return 1
        [ "$n" = "$n_bg" ] && colorAssn background $1
        [ "$n" = "$n_fg" ] && colorAssn foreground $1
        shift
    done
}

TPL="[38;5;%um"
DEF="[39m"

fzinit() {
    ls $B16DIR | sed 's/^base16-\|\.sh$//g' |
        fzf --bind="up:up+execute-silent($0 theme {})" \
            --bind="ctrl-k:up+execute-silent($0 theme {})" \
            --bind="ctrl-p:up+execute-silent($0 theme {})" \
            --bind="down:down+execute-silent($0 theme {})" \
            --bind="ctrl-j:down+execute-silent($0 theme {})" \
            --bind="ctrl-n:down+execute-silent($0 theme {})"
}

fill() {
    local clr blk
    clr=$(printf $TPL $1) blk=■
    if [ "$(colors $1)" = "$(colors background)" ]; then
        clr=$DEF blk=□ #▧
    fi
    printf $clr$blk$blk$DEF
}

fzcolors() {
    local graph sel i range name
    while read -r range name; do
        [ "$range" ] || continue
        sel=$(echo $(explodeRange $range)) graph=
        for i in $(seq 0 0xF); do
            case " $sel " in
            *" $i "*) graph=$graph$(fill $i) ;;
                   *) graph=$graph'  '       ;;
            esac
        done
        printf %s:%15s:%s\\n $range "$name" "$graph"
    done |
    fzf -d: --with-nth=2.. |
    { IFS=: read -r range _; echo $range; }
}<<EOF
1-6,9-14   Colors
1-6        Normal-Colors
9-14       Bright-Colors
0,7-8,15   Grays
0,7        Normal-Grays
8,15       Bright-Grays
0-15       All
EOF

fzaction() {
    local prop
    ops=${ops:-H S L R G B}
    while read -r prop; do
        echo $range:$ops:$prop
    done |
    fzf --no-clear -d: --with-nth=3 --expect=$EXP_Keys |
    { read key; IFS=: read range ops next; [ "$key" ] && tweak || echo "$ops"; }
}<<EOF
H
S
L
R
G
B
EOF

main() {
    local cap ln range ops key next

    cap=$(fzinit) && theme "$cap" || initC
    range=$(fzcolors)
    ops=$(fzaction)
    fzf --bind=change:abort </dev/null
    echo export $(colorENV)
}

tweak() {
    local new inc _inc p prop

    inc=$(key2inc "$key")
    N=$(explodeRange "$range")
    C=$($colorx $next$inc $(colors $N))
    NCassn "$N" "$C" && exPort && initC || { error 'trouble reloading'; return; }

    new=
    for p in $ops; do
        prop=${p%%[!HSLRGB]*} _inc=${p#[HSLRGB]}
        [ ${#prop} -eq 1 ] || return 1

        if [ "$prop" = "$next" ]; then
            inc=$((${_inc:-0} + inc))
            if   [ $inc -gt 0 ]; then inc=+$inc
            elif [ $inc -eq 0 ]; then inc= ; fi
        fi
        new=$new${new:+ }$prop$inc
    done
    ops=$new

    fzaction
}

if [ "$1" = -r ]; then
    shift
    reload "$@"
elif [ "$1" = "theme" ]; then
    shift
    theme "$@" 2>/dev/tty
else
    main "$@"
fi