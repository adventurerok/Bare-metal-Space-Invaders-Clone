#!/usr/bin/env bash

printf "Compiling loader...\n"
nasm -f bin "space_loader.asm"

printf "Compiling main...\n"
nasm -f bin "space.asm"

rm -f space.iso

dd status=noxfer conv=notrunc if=space_loader of=space.iso
dd status=noxfer conv=notrunc if=space of=space.iso seek=1

printf "\nRunning Program...\n"
screen -dmS "space_qemu" qemu-system-x86_64 -s -S /dev/zero -fda "space.iso"

gdb --command=gdb_commands

screen -r "space_qemu"
