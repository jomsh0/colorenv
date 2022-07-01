# `colorenv`—tweaking base16-style themes

I’m a fan of the idea behind
[chriskempson/base16](https://github.com/chriskempson/base16), particularly the
[“shell”](https://github.com/chriskempson/base16-shell) themes (actually shell
scripts which modify the terminal emulator color palette by `printf`-ing
traditional escape sequences to stdout).

That way, you set the basic color palette in a platform/emulator-independent
way, and it remains consistent no matter which terminal app you use, as long as
the app can be configured to use the traditional palette (as opposed to the
newer `truecolor` method, which emits a full 24-bit RGB sequence for every color
change).

Although the palette is limited to 256 colors—and most applications only use the
classic 8 colors (or 16, with the bright versions)—the colors themselves can be
set with full 24-bit RGB values (at least, in modern terminal emulators). So a
huge variety of themes are possible, including the entire `base16` library.

The idea behind this script is to allow such themes to be tweaked, with
immediate feedback, and with computed color values stored in the environment so
they can be saved or reused. The tweaks involve adjustments to RGB values or HSL
values. The RGB\<–\>HSL conversion is performed by
[sharkdp/pastel](https://github.com/sharkdp/pastel), or, in a later version, by
a simple, purpose-built C program. The ANSI interface for setting the color
value uses RGB values, but HSL makes more sense for most kinds of tweaks.

I mostly abandoned this in favor of a Go program that uses a proper TUI library.
See [jomshcc/cx](https://github.com/jomshcc/cx).
