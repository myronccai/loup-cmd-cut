# Requirements: cut

## Introduction

`cut` prints selected parts of each line of its input: a set of fields
separated by a delimiter, or a set of character or byte positions. This
repository recreates GNU coreutils `cut` in Loup, including its range-list
grammar (`1,3-5,7-`), `--complement`, `--output-delimiter` and its error
messages and exit statuses. Shell users and scripts use it to pull columns out
of tabular text.

## Requirements

### Requirement 1: Range lists

**User Story:** As a shell user, I want to name the parts I need with a
compact list so that one option selects several columns.

#### Acceptance Criteria

1. WHEN a LIST is given, THE program SHALL accept ranges `N`, `N-`, `N-M` and
   `-M`, separated by commas or blanks, counted from 1.
2. THE program SHALL output each selected part once and in input order,
   whatever the order or overlap of the ranges in the LIST.
3. WHEN a LIST contains 0 as a position, a decreasing range, a lone `-`, two
   dashes in one range, a non-digit, or a number that is too large, THE
   program SHALL print GNU cut's message for it and exit with status 1.
4. WHEN `--complement` is given, THE program SHALL select every part the
   LIST does not select.

### Requirement 2: Fields

**User Story:** As a shell user, I want to select delimited fields so that I
can extract columns from tables such as `/etc/passwd`.

#### Acceptance Criteria

1. WHEN `-f LIST` is given, THE program SHALL split each line on the
   delimiter (TAB by default, or the single character given with `-d`) and
   print the selected fields joined by the output delimiter.
2. WHEN a line does not contain the delimiter, THE program SHALL print it
   whole, unless `-s` is given, in which case it SHALL print nothing for it.
3. WHEN `--output-delimiter=STRING` is given, THE program SHALL join fields
   with STRING instead of the input delimiter; an empty STRING SHALL mean
   the NUL character.
4. WHEN `-d ''` is given, THE program SHALL use the NUL character as the
   delimiter.
5. WHEN the delimiter is the line terminator, THE program SHALL treat the
   whole input as one record, as GNU cut does.

### Requirement 3: Characters and bytes

**User Story:** As a shell user, I want to select character or byte
positions so that I can extract fixed-width columns.

#### Acceptance Criteria

1. WHEN `-c LIST` is given, THE program SHALL print the selected characters
   of each line.
2. WHEN `-b LIST` is given, THE program SHALL print the selected bytes of
   each line; a multibyte UTF-8 character SHALL be printed whole when its
   first byte is selected.
3. WHEN `--output-delimiter` is given with `-b` or `-c`, THE program SHALL
   print it between selected parts that belong to different ranges.
4. THE program SHALL accept and ignore `-n`.

### Requirement 4: Input and output

**User Story:** As a script author, I want cut to read files and standard
input like other filters so that it fits in pipelines.

#### Acceptance Criteria

1. WHEN no FILE is given, or a FILE is `-`, THE program SHALL read standard
   input.
2. WHEN several FILEs are given, THE program SHALL process them in order.
3. THE program SHALL end every output line with the line terminator, adding
   one after a last line that lacks it.
4. WHEN `-z` is given, THE program SHALL use NUL instead of newline as the
   line terminator, for input and output.
5. WHEN a FILE does not exist or is a directory, THE program SHALL print
   `cut: FILE: No such file or directory` or `cut: FILE: Is a directory`,
   continue with the next FILE, and exit with status 1.

### Requirement 5: Command line

**User Story:** As a shell user, I want GNU's option syntax so that existing
scripts work unchanged.

#### Acceptance Criteria

1. THE program SHALL accept short options clustered (`-sf2`) with attached
   or separate values (`-d:`, `-d :`), long options with `=VALUE` or a
   separate value, unambiguous abbreviations of long options, options after
   operands, and `--` to end options.
2. WHEN none of `-b`, `-c`, `-f` is given, THE program SHALL print
   `cut: you must specify a list of bytes, characters, or fields` and exit
   with status 1.
3. WHEN more than one LIST is given, THE program SHALL print
   `cut: only one list may be specified` and exit with status 1.
4. WHEN `-d` or `-s` is used without `-f`, or `-d` is given more than one
   character, THE program SHALL print GNU cut's message and exit with
   status 1.
5. WHEN an option is unknown, ambiguous, missing its value or given a value
   it does not take, THE program SHALL print getopt's message followed by
   `Try 'cut --help' for more information.` and exit with status 1.
6. WHEN `--help` or `--version` is given, THE program SHALL print the help
   text or the line `cut (loup-cmd-cut) 0.1.0` and exit with status 0.
