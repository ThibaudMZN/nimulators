import unittest
import ../src/chip8

suite "The Chip8 emulator":
  setup:
    var chip8 = initChip8()

  test "copies the fontset in its memory":
    check(chip8.memory[0] == 0xF0) # First byte of fontset
    check(chip8.memory[79] == 0x80) # Last byte of fontset