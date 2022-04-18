#!/usr/bin/env sh

# https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
#
# General format:
#     \e[n1{;n2;...;nX}m
#
# n = 0 resets all attributes including color
#    [1..9] sets attributes like bold, underline, etc.
#    [22..29] resets the same attributes (individually)
#    [30..37] sets the 3-bit classic foreground color
#     38;5;[0..255] is used to set 8-bit foreground color
#     38;2;{r};{g};{b} is used to 'direct' set 24-bit foreground color
#     39 resets to the *default* foreground color
#    [40..49] is the same as above, but for background
#    [90..97] sets foreground to 'bright' versions of the classic 8 colors (when supported)
#    [100..107] same for background. Distinct from the 'bold' attribute (n = 1) but ... it's murky

fg_brold() {
    for i in $(seq 0 7); do
        printf "\e[3${i}m"
        echo "Now testing code 3$i. Lorem Ipsum."
        printf "\e[9${i}m"
        echo "Now testing BRIGHT code 9$i. Lorem Ipsum."
        printf "\e[1;3${i}m"
        echo "Now testing BOLD code 1;3$i. Lorem Ipsum."
        printf "\e[9${i}m"
        echo "Now testing BOLD, BRIGHT code 1;9$i. Lorem Ipsum."
        printf "\e[22m"
    done
    printf "\e[39m"
    echo "Now testing code 39 (default fg). Lorem Ipsum."
    printf "\e[1m"
    echo "Now testing default fg with BOLD switched on. Lorem Ipsum."
    printf "\e[22m"
}

# 8-bit color index: 38;5;[0..255]
# [0..15] are the original 16 colors (regular and bright versions of the classic 8)
# [16..231] is a counter with the most-significant bits representing red and the LSB representing blue.
# So it's cyclical but there are rapid fluctuations in green and blue, while growing more red overall.
# [232..255] are grayscale ranging from almost black to almost white.

# Defining the 8-bit color space
#
#   \e]4;{i};rgb:{r}/{g}/{b}
# Sets index i to the given red, green, and blue (in *case ascii representing hex values)
 
# printf '\e]4;215;rgb:00/00/ff\e\'

# NOTE base16 scripts only set [0..21]. I always believed there was some magic to doing so,
# but for Windows Terminal at least, any index can be arbitrarily set and the others seem
# to always stay the same (i.e., not computed from those that are set).

#   \e]10;rgb:c5/c8/c6
# 10 is for default foreground, 11 for default background.
# Unlike any of the above, these aren't followed by 'm'.
# However, the base16 scripts do append \e\\ (escape-backslash) to each.
# Also the bracket following the opening escape is turned the other direction.

bg_3bit() {
    printf '\e[49m'
    echo '8 primary backgrounds:'
    for i in $(seq 40 47); do
        printf "\e[${i}m"
        echo
    done
    printf '\e[49m'
    echo
    echo '8 BRIGHT backgrounds:'
    for i in $(seq 100 107); do
        printf "\e[${i}m"
        echo
    done
    printf '\e[49m'
    echo
}

bg_8bit() {
    printf '\e[49m'
    echo 'The classic 16, but using 8-bit commands:'
    for i in $(seq 0 15); do
        printf "\e[48;5;${i}m"
        echo
    done
    printf '\e[49m'
    echo
    echo 'The next 6 that base16 messes with:'
    for i in $(seq 16 21); do
        printf "\e[48;5;${i}m"
        echo
    done
    printf '\e[49m'
    echo
    echo 'The remainder that seems fixed without explicitly setting:'
    for i in $(seq 22 255); do
        printf "\e[48;5;${i}m"
    #   echo
    done
    printf '\e[49m'
    echo '  ...   [redacted]  ...  '
    echo
}

for arg; do
    case "$arg" in
        bg[_-]8bit | bg[_-]3bit | fg[_-]brold) sfx=${arg#*[_-]} ; cmd=${arg%[_-]$sfx}_$sfx ;;
          -r) reset=1 ;;
        -h|*) >&2 echo "Use -r to reset terminal. COMMANDS: bg-8bit, bg-3bit, fg-brold"; exit 1 ;;
    esac
done

cmdstatus=0
if [ "$cmd" ]; then
    echo ": running $cmd" >&2
    $cmd; cmdstatus=$?
fi

[ "$reset" ] || exit $cmdstatus

echo ': sending reset to tty' >&2
printf '\e[0m'
exit $cmdstatus
