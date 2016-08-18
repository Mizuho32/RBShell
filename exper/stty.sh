#!/bin/sh
#getchar.sh

echo "Hit any key!"
stty raw
char=`dd bs=1 count=1 2>/dev/null`
stty -raw
echo "Key pressed: '$char'"
