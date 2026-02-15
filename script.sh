#!/usr/bin/env bash
set -euo pipefail

RUNS=100

mkdir -p /tmp/ascii_bench
cp /mnt/c/Users/pawel/Desktop/ASCII_ASM/init.elf /tmp/ascii_bench/
cp /mnt/c/Users/pawel/Desktop/ASCII_ASM/out.bruh /tmp/ascii_bench/
cd /tmp/ascii_bench

S1=$(date +%s%N)
./init.elf >/dev/null
E1=$(date +%s%N)
ONE=$(awk -v s="$S1" -v e="$E1" 'BEGIN { printf "%.5f", (e-s)/1000000000 }')

printf 'SINGLE RUN: %ss\n' "$ONE"
