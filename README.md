# My Bare-Metal Clone of Space Invaders
A basic clone of space invaders that runs without an operating system just using BIOS calls.

# Space-Loader
The game itself is larger than 510 bytes which is the maximum that can be put on the 512 byte boot sector. Therefore instead of putting the game in the boot sector, the boot sector contains code which will read the next sectors and run them.
