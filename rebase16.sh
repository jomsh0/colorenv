#!/usr/bin/env sh

ANSI_ORDER='black red green yellow blue magenta cyan white'
B16_dir=$HOME/.themes/shell/scripts

extract() {
    local seq
    eval "$(grep -e ^color)"
    
    for seq in $(seq 0 21); do
        eval echo \$color$(printf %02d $seq)
    done
    echo foreground=$color_foreground
    echo background=$color_background
}

error() { echo '[rebase16 error]:' "$@" >&2; exit 1; }

wcard() {
    local match
    if [ -r "$B16_dir/base16-$1.sh" ]; then match=$B16_dir/base16-$1.sh
    else
        set -- "$B16_dir"/*"$1"*.sh
        [ -r "$1" ]  || error "no matching base16 scripts."
        [ $# -eq 1 ] || error "must match exactly one script."
        match=$1
    fi
    extract < "$match"
}

help_exit() { cat >&2; exit 1; } <<'EOF'
rebase16.sh

USAGE:
      colors=$(rebase16.sh theme|script-file)
      rebase16.sh < script-file | pastel color
      rebase16.sh  ... | colorenv.sh
EOF

[ -t 0 ] && [ $# -eq 0 ] && help_exit
[ -t 0 ] || extract
[ "$1" ] || error 'supply a theme name or file path as an argument, or the contents on stdin.'

while [ $# -gt 0 ]; do
    if [ -r "$1" ]; then extract "$1"
    elif [ "${1#/}" = "$1" ]; then wcard "$1"
    else error 'bad file name; try a base16 theme name.'; fi
    shift
done
