# Design: cut

## Overview

`main()` passes `runtime.args()` to `cli.app.run`. `run` parses the
arguments into `Options` (the range list is parsed, merged and, with
`--complement`, inverted at this point), handles `--help` and `--version`,
and calls `commands.cut.run_cut`. `run_cut` reads each input whole and
prints what `cut_text` returns. Everything below `run_cut` is a pure function
returning values, so the unit tests need no captured output.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (GNU cut uses 1 for usage errors too) |
| `source/cli/getopt.loup` | `OptSpec`, `OptHit`, `Scan`, `scan_options`: a GNU `getopt_long` work-alike (clustering, permutation, abbreviations, getopt's messages) |
| `source/cli/args.loup` | `Mode` (`Bytes`, `Characters`, `Fields`), `Options`, `parse_args`: cut's options and their cross-checks |
| `source/cli/usage.loup` | `usage()` help text, `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, map exceptions to status 1 |
| `source/commands/ranges.loup` | `Range{lo, hi}`, `parse_list` (the LIST mini-grammar into sorted, merged ranges), `complement`, `is_selected`, `starts_range` |
| `source/commands/cut.loup` | `cut_fields_line`, `cut_positions_line`, `split_records`, `cut_text`, `run_cut` |

### Range lists

`parse_list` follows GNU's `set_fields` state machine: digits accumulate a
number, `-` starts a range (a second `-` is an error), and `,`, a blank or
the end of the list closes the current item. Each item becomes a
`Range{lo, hi}` with `hi = END` (the largest `int`) for an open range. The
ranges are sorted by `lo` and overlapping ones merged, as GNU does (adjacent
ranges such as `1-2,3-4` stay separate, which matters for
`--output-delimiter`). `complement` returns the gaps between them.

### Selecting

- Fields: `cut_fields_line` returns `None` for a line without the delimiter
  under `-s`, the whole line for one without the delimiter otherwise, and
  else the selected fields of `line.split(delim)` joined by the output
  delimiter.
- Characters and bytes: `cut_positions_line` walks the line one character at
  a time with a running position (characters count 1; bytes count the
  character's UTF-8 length) and keeps the characters whose first position is
  selected. With an explicit `--output-delimiter` it inserts it before a kept
  character that starts a new range, as GNU's `cut_bytes` does.

`split_records` splits an input into records on the terminator (newline, or
NUL with `-z`), dropping the empty piece after a final terminator. When the
field delimiter equals the terminator the whole input is one record. Each
output record ends with the terminator.

## Differences from GNU cut

- `-c` counts characters (code points). GNU cut 9.5 treats `-c` exactly like
  `-b`.
- `-b` counts bytes but cannot split a multibyte UTF-8 character, because
  Loup strings hold whole characters: such a character is printed whole when
  its first byte is selected, and not at all otherwise. Input that is pure
  ASCII gives the same output as GNU.
- `-d` accepts any single character, including a multibyte one; GNU accepts
  a single byte only.
- A file that exists but cannot be read (for example, permission denied)
  stops the program with status 1 and Loup's own message, instead of being
  reported and skipped: the Loup 1.26.0 native runtime does not let the
  program catch that `IoError`.
- `--version` prints one line; `--help` omits GNU's links to its online
  documentation.

## Error handling

Usage errors (from `scan_options`, `parse_list` or the cross-checks in
`parse_args`) come back as `Err(message)`; `run` prints `cut: message` and
`Try 'cut --help' for more information.` and returns 1. Missing files and
directories are checked with `exists` and `io.fs.isDir` before reading
(see the IoError note above), reported as `cut: FILE: ...`, and make the
final status 1 while the other files are still processed.

## Testing

- `tests/getopt_test.loup`: clustering, values, permutation, `--`,
  abbreviations, and each getopt message.
- `tests/ranges_test.loup`: every LIST form, merging, complement and each
  LIST error.
- `tests/args_test.loup`: option cross-checks and defaults.
- `tests/cut_test.loup`: fields, `-s`, delimiters, positions, bytes vs
  characters, output delimiters, records and terminators.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: runs the native binary on fixtures and standard input and
  compares output byte for byte, including NUL-terminated records.
