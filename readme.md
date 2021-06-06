# [NEC PC8801](https://en.wikipedia.org/wiki/PC88) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

This is the port of the [PC8801 MKII SR](http://fpga8801.seesaa.net/category/21233167-1.html) core by Puu-san.

## Installation
Copy the PC88_\*.rbf file to the root of the SD card. Create a **PC8801mk2SR** folder on the root/games of the card, and place PC8801 floppies (\*.D88) inside this folder. 
- boot.rom = PC8801 MKII SR BIOS file.  Required to start the core.

## How to build the boot.rom

- 00000 ~ N88BASIC (32ko) mk2sr_n88.rom A0FC0473
- 08000- N-BASIC (32ko) mk2sr_n80.rom 27E1857D
- 10000 ~ N88 4th-0 (8ko) mk2sr_n88_0.rom 710A63EC
- 12000 ~ N88 4th-1 (8ko) n88_1.rom C0BD2AA6
- 14000 ~ N88 4th-2 (8ko) n88_2.rom AF2B6EFA
- 16000 ~ N88 4th-3 (8ko) n88_3.rom 7713C519
- 18000 ~ FONT (8x16) (2ko) + (2ko blank) font.rom 56653188
- 19000- Simple graphics font (attached Font / graphfont.bin) (4ko) graphfont.bin CDD1BE6B
- 1a000 ~ DISK ROM (8ko) + (16ko blank) mh_disk.rom A222ECF0
- 20000 ~ KANJI1 (128ko) kanji1.rom 6178BD43
- 40000 ~ KANJI2 (128ko) kanji2.rom 154803CC

copy /b mk2sr_n88.rom+mk2sr_n80.rom+mk2sr_n88_0.rom+n88_1.rom+n88_2.rom+n88_3.rom+font.rom+2KO_BLANK_00.ROM+graphfont.bin+mh_disk.rom+8KO_BLANK_00.ROM+8KO_BLANK_00.ROM+kanji1.rom+kanji2.rom boot.rom

## TODO
- Add Audio MIX
- Update T80 cpu
- ...