#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte) and exit status with the expected ones, and for errors
# its standard error.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$1
FIX=tests/fixtures
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... as check_file does and compares standard error.
check_err() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want_err"
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want_err" "$TMP/err"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$TMP/want_err" "$TMP/err" | sed 's/^/    /' | head -10
    fi
}

TRY=$'\nTry \'cut --help\' for more information.\n'

# Fields.
check "fields 1,7"          0 $'root:/bin/bash\ndaemon:/usr/sbin/nologin\nann:/bin/zsh\n# no delimiter on this line\n' \
    -d: -f1,7 "$FIX/passwd.txt"
check "-s drops plain line" 0 $'root:/bin/bash\ndaemon:/usr/sbin/nologin\nann:/bin/zsh\n' \
    -d: -f1,7 -s "$FIX/passwd.txt"
check "--complement"        0 $'root:x:0:0:/root:/bin/bash\ndaemon:x:1:1:/usr/sbin:/usr/sbin/nologin\nann:x:1000:1000:/home/ann:/bin/zsh\n' \
    -d: -f5 --complement -s "$FIX/passwd.txt"
check "TAB default"         0 $'qty\n3\n12\n\n'                      -f2 "$FIX/table.tsv"
check "output delimiter"    0 $'name,price\napple,0.50\npear,0.75\nfig,1.20\n' \
    -f1,3 --output-delimiter=, "$FIX/table.tsv"
IN=<(printf 'a:b:c:d\n') check "open range N-" 0 $'c:d\n'           -d: -f3-
IN=<(printf 'a:b:c:d\n') check "range -M" 0 $'a:b\n'                 -d: -f-2
IN=<(printf 'a:b:c:d\n') check "list order ignored" 0 $'a:c\n'       -d: -f3,1
IN=<(printf 'a:b:c:d\n') check "overlapping ranges" 0 $'a:b:c\n'     -d: -f1-2,2-3
IN=<(printf 'a:b:c:d\n') check "blank-separated list" 0 $'a:d\n'     -d: -f '1 4'
IN=<(printf 'a:b\n') check "past the last field" 0 $'\n'              -d: -f3
IN=<(printf 'a b c\n') check "space delimiter" 0 $'b\n'               -d ' ' -f2
IN=<(printf 'a:b\nc:d') check "adds final newline" 0 $'b\nd\n'        -d: -f2
IN=<(printf '') check "empty input" 0 ''                               -f1

# Characters and bytes.
check "columns -c5-14"      0 $'name      \nAnn       \nBob       \n' -c5-14 "$FIX/fixed.txt"
check "-c with delimiter"   0 $'id |name      \n 1 |Ann       \n 2 |Bob       \n' \
    -c1-3,5-14 --output-delimiter='|' "$FIX/fixed.txt"
IN=<(printf 'abcdef\n') check "adjacent ranges"   0 $'ab:cd\n'        -c1-2,3-4 --output-delimiter=:
IN=<(printf 'abcdef\n') check "-c complement"     0 $'b:d:f\n'        -c1,3,5 --complement --output-delimiter=:
IN=<(printf 'abcdef\n') check "-b ASCII"          0 $'bcd\n'          -b2-4
IN=<(printf 'abcdef\n') check "-n ignored"        0 $'a\n'            -b1 -n
check "-c counts characters" 0 $'café\nnaïv\n'                       -c1-4 "$FIX/utf8.txt"
check "-b keeps characters whole" 0 $'caf\nnaï\n'                    -b1-3 "$FIX/utf8.txt"
check "UTF-8 fields"        0 $'1\n2\n'                               -d: -f2 "$FIX/utf8.txt"
IN=<(printf 'aéb\n') check "multibyte delimiter" 0 $'b\n'             -d é -f2

# Files and standard input.
IN=<(printf 'x:y\n') check "dash is stdin" 0 $'y\nb\n'                -d: -f2 - <(printf 'a:b\n') /dev/null
IN=<(printf 'x:y\n') check "files in order" 0 $'0\n1\n1000\n# no delimiter on this line\n\n'       -d: -f3 "$FIX/passwd.txt" -
check "options after files" 0 $'qty\n3\n12\n\n'                       "$FIX/table.tsv" -f2
check "-- ends options"     0 ''                                      -f1 -- /dev/null

# Newline and NUL as terminators or delimiters.
printf 'a:b\0c:d\0' > "$TMP/z_in"
printf 'b\0d\0' > "$TMP/z_want"
check_file "-z"             0 "$TMP/z_want"                           -z -d: -f2 "$TMP/z_in"
printf 'a\0b\nc\0d\n' > "$TMP/nul_in"
check "-d '' is NUL"        0 $'b\nd\n'                               -d '' -f2 "$TMP/nul_in"
printf 'a\0c\n' > "$TMP/nul_want"
IN=<(printf 'a:b:c\n') check_file "empty output delimiter" 0 "$TMP/nul_want" -d: -f1,3 --output-delimiter=
IN=<(printf 'a\nb\nc\n') check "newline delimiter" 0 $'b\n'           -d $'\n' -f2
IN=<(printf 'a\nb\nc') check "newline delimiter join" 0 $'a\nc\n'     -d $'\n' -f1,3

# Missing files and usage errors.
check_err "missing file"    1 $'cut: nope.txt: No such file or directory\n'  -f1 nope.txt
check_err "directory"       1 $'cut: tests: Is a directory\n'                -f1 tests
check_err "quoted name"     1 $'cut: \'a b\': No such file or directory\n'   -f1 'a b'
check "missing file, others still cut" 1 $'qty\n3\n12\n\n'            -f2 nope.txt "$FIX/table.tsv"
check_err "no list"         1 "cut: you must specify a list of bytes, characters, or fields$TRY"
check_err "two lists"       1 "cut: only one list may be specified$TRY"      -b1 -f1
check_err "-d without -f"   1 "cut: an input delimiter may be specified only when operating on fields$TRY" -c1 -d:
check_err "-s without -f"   1 $'cut: suppressing non-delimited lines makes sense\n\tonly when operating on fields'"$TRY" -c1 -s
check_err "long delimiter"  1 "cut: the delimiter must be a single character$TRY" -d ab -f1
check_err "field 0"         1 "cut: fields are numbered from 1$TRY"         -f0
check_err "position 0"      1 "cut: byte/character positions are numbered from 1$TRY" -c0
check_err "decreasing"      1 "cut: invalid decreasing range$TRY"            -f3-1
check_err "lone dash"       1 "cut: invalid range with no endpoint: -$TRY"   -f-
check_err "bad field value" 1 "cut: invalid field value 'x2'$TRY"            -f1x2
check_err "too large"       1 "cut: field number '99999999999999999999' is too large$TRY" -f99999999999999999999
check_err "invalid option"  1 "cut: invalid option -- 'x'$TRY"               -x
check_err "missing value"   1 "cut: option requires an argument -- 'f'$TRY"  -f
check_err "unknown long"    1 "cut: unrecognized option '--nope'$TRY"        --nope
check_err "ambiguous"       1 "cut: option '--c' is ambiguous; possibilities: '--characters' '--complement'$TRY" --c 1
check_err "no argument allowed" 1 "cut: option '--complement' doesn't allow an argument$TRY" --complement=1

# Help and version.
check "version"             0 $'cut (loup-cmd-cut) 0.1.0\n'          --version
check "help wins"           0 "$("$BIN" --help)"$'\n'                 --help -x
"$BIN" --help | head -1 | grep -q '^Usage: cut OPTION' && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: help text"; }

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
