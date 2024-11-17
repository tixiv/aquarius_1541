# Aquarius 1541
Port of the C64 game Aquarius by Aleksi Eeben so it can be played with a 1541 as a controller instead of a 1530. Sourcecode and Makefile will be included if anyone is interested in how to hack a game like this.

# Running
Just download the file "out/aquarius_1541.d64", write to disk and enjoy on your c64/1541. I assume you have a way to write a disk image to a real disk. Running this in an emulator does not make much sense since you need to use the 1541 as the controller.

# Building
I use WSL to build this, but you should be able to build this anywhere where you have the following tools:
- make
- Acme assembler for 6502
- exomizer cross packer
- c1541 which is included with the Vice c64 emulator to build the d64


