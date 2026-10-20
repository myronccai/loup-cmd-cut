# loup-cmd-cut

GNU `cut` recreated in [Loup](https://code-craft.ai/references/loup): print
selected fields, characters or bytes of each line, with GNU's range lists
(`1,3-5,7-`), `--complement`, `--output-delimiter` and error messages.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                              # native binary: build/cut
make ci                                 # check, unit tests, build, end-to-end tests
make run ARGS="-d: -f1 /etc/passwd"     # run from source with loup run
```

```text
$ build/cut -d: -f1,7 tests/fixtures/passwd.txt
root:/bin/bash
daemon:/usr/sbin/nologin
ann:/bin/zsh
# no delimiter on this line
$ build/cut -d: -f1,7 -s tests/fixtures/passwd.txt
root:/bin/bash
daemon:/usr/sbin/nologin
ann:/bin/zsh
$ build/cut -f1,3 --output-delimiter=', ' tests/fixtures/table.tsv
name, price
apple, 0.50
pear, 0.75
fig, 1.20
$ build/cut -d: -f5 --complement -s tests/fixtures/passwd.txt
root:x:0:0:/root:/bin/bash
daemon:x:1:1:/usr/sbin:/usr/sbin/nologin
ann:x:1000:1000:/home/ann:/bin/zsh
$ build/cut -c5-7,15- --output-delimiter=' ' tests/fixtures/fixed.txt
nam city
Ann Oslo
Bob Lima
$ printf 'abcdefgh\n' | build/cut -c1-2,4-5,7- --output-delimiter=' | '
ab | de | gh
$ build/cut -f0
cut: fields are numbered from 1
Try 'cut --help' for more information.
$ build/cut -f1 missing.txt; echo "exit $?"
cut: missing.txt: No such file or directory
exit 1
$ build/cut --version
cut (loup-cmd-cut) 0.1.0
```

Options, exactly one of `-b`, `-c`, `-f` required:

| Option | Meaning |
|---|---|
| `-b LIST`, `--bytes=LIST` | select these bytes |
| `-c LIST`, `--characters=LIST` | select these characters |
| `-f LIST`, `--fields=LIST` | select these fields; lines without the delimiter are printed whole |
| `-d DELIM`, `--delimiter=DELIM` | field delimiter (default TAB; `-d ''` means NUL) |
| `-s`, `--only-delimited` | with `-f`, skip lines that have no delimiter |
| `--complement` | select everything the LIST does not |
| `--output-delimiter=STRING` | join fields (or separate `-b`/`-c` ranges) with STRING |
| `-z`, `--zero-terminated` | lines end with NUL, not newline |
| `-n` | ignored, as in GNU cut |
| `--help`, `--version` | print help or the version and exit |

A LIST is one or more ranges separated by commas or blanks: `N`, `N-` (to
the end of the line), `N-M`, `-M` (from the first), counted from 1. Selected
parts are printed once each, in input order. With no FILE, or with `-`, cut
reads standard input. Options may come after the files, short options may be
combined (`-sd:`), and long ones shortened (`--only`).

Exit status: `0` on success; `1` if a FILE could not be read (the others are
still processed) or on a usage error, as in GNU cut.

## Differences from the original

- `-c` counts characters (Unicode code points). GNU cut 9.5 treats `-c`
  exactly like `-b` and can split a multibyte character.
- `-b` counts bytes but never splits a multibyte UTF-8 character, because a
  Loup string holds whole characters: a character is printed whole when its
  first byte is selected and not at all otherwise (`printf 'café\n' | cut
  -b1-4` prints `café`; GNU prints `caf` and the first byte of `é`). ASCII
  input gives the same output as GNU.
- `-d` accepts any single character, including a multibyte one such as `é`;
  GNU accepts only a single byte.
- A FILE that exists but cannot be read (for example, permission denied)
  stops the program with Loup's own `IoError` message and status 1 instead
  of being reported and skipped: the Loup 1.26.0 native runtime does not let
  the program catch that error. Missing files and directories are checked
  beforehand and reported as GNU does.
- Messages use the C locale's quotes (`'x'`, not `‘x’`); file names are
  quoted as GNU quotes them.
- `--version` prints a single line; `--help` omits GNU's links to its online
  documentation.

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses
source/cli/getopt.loup        # GNU getopt_long work-alike: clustering, abbreviations, messages
source/cli/args.loup          # cut's options and their cross-checks
source/cli/quote.loup         # GNU-style quoting of file names in messages
source/cli/usage.loup         # --help and --version text
source/cli/app.loup           # run(): parse, dispatch, exit status
source/commands/ranges.loup   # LIST parsing into sorted, merged ranges; complement
source/commands/cut.loup      # field, character and byte selection; files
tests/*_test.loup             # unit tests (make test)
tests/e2e.sh                  # end-to-end tests of build/cut (make e2e)
tests/fixtures/               # input files for the end-to-end tests
specs/cut/                    # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
