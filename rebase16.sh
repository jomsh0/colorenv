# Input: a standard base16 shell script.
# Output: shell assignments for named color variables.

ANSI_ORDER='black red green yellow blue magenta cyan white'
B16_dir=$HOME/.themes/shell/scripts

gen_sh_variables() {
    eval "$(grep -e '^color[0-9]\+=' | sed 's^/^^g')"

    set -- $ANSI_ORDER
    local i name

    for i in $(seq 0 7); do
        eval "name=\$$((i+1))"
        eval echo "$name=\$color0$i"
    done

    for i in $(seq 8 15); do
        eval "name=bright_\$$((i-7))"
        eval echo "$name=\$color$(printf %02i $i)"
    done
}

error() {
    echo ERROR: "$@"
    exit 1
} >&2

_wcard() {
    local match
    if [ -r "$B16_dir/base16-$1.sh" ]; then match=$B16_dir/base16-$1.sh
    else
        set -- "$B16_dir"/*"$1"*.sh
        [ -r "$1" ]  || error "no matching base16 scripts."
        [ $# -eq 1 ] || error "must match exactly one script."
        match=$1
    fi
    gen_sh_variables < "$match"
}

_generate() {
    if ! [ -t 0 ]; then gen_sh_variables
    elif [ -r "$1" ]; then gen_sh_variables "$1"
    elif [ -z "$1" ]; then error 'supply a theme name or file path as an argument, or the contents on stdin.'
    elif [ "${1#/}" = "$1" ]; then _wcard "$1"
    else error 'bad file name; try a base16 theme name.'
    fi
}

unset OPTIND OPTARG
while getopts 'Gk' opt; do
    case "$opt" in
        G) shift; _generate "$@"; exit $? ;;
        k) emitKeys=1
    esac
done
shift $((OPTIND-1))
# in case arg needs to be word-split
set -- $@

help-exit() { cat >&2; exit 1; } <<'EOF'
rebase16.sh - "My life is ruined either way."

USAGE:
    # Extracting colors from a generated base16 shell script:

      colors=$(rebase16.sh -G theme|script-file)
      colors=$(rebase16.sh -G < script-file)


    # Sending values to `pastel`:

      rebase16.sh $(colors) | pastel color


OPTIONS:
    -k   Emits `key=value` tokens instead of a list of only values.
EOF
[ -t 0 ] && [ $# -eq 0 ] && help-exit

# clear any existing colors in environment
unset $ANSI_ORDER
[ -t 0 ] || eval "$(cat)"  # go big or go home

for arg; do
    Name=${arg%=*}
    [ "$Name" != "$arg" ] && Val=${arg#$Name=}
    Base=${Name#bright}
    [ "$Base" != "$Name" ] && Name=bright_${Base#[_-]}

    case " $ANSI_ORDER " in
        *" ${Name#bright_} "*)
            if [ "$Val" ]; then eval "$Name=\$Val"
            else Filter="$Filter $Name"
            fi ;;
        *) echo ": unrecognized: $arg" >&2 ;;
    esac
done

all-colors() {
    local c
    for c in $ANSI_ORDER; do
        echo $c; echo bright_$c;
    done
}

unset Val
for Color in ${Filter:-$(all-colors)} ; do
    eval Val=\$$Color
    [ "$Val" ] || continue
    [ "$emitKeys" ] && Val=$Color=$Val
    echo $Val
done

exit $?
