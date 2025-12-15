#!/bin/sh

# Convert TICS '~/lmxxxx.tcs' to CSV table

set -eu

TCSFILE="$1"

BASENAME=`basename --suffix=.tcs $TCSFILE`
CSV="$BASENAME.csv"

tr -d '\r' <"$TCSFILE" |
sed -n -e '/^VALUE[0-9]*=\([0-9]*\)/s//\1/p'
