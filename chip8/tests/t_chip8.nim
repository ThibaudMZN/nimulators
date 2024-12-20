import unittest
import ../src/chip8

suite "The Chip8 emulator":
  setup:
    var chip8 = initChip8()

  test "copies the fontset in its memory":
    check(chip8.memory[0] == 0xF0) # First byte of fontset
    check(chip8.memory[79] == 0x80) # Last byte of fontset

  test "can increment its program counter":
    chip8.incrementPc()
    check(chip8.pc == 0x202) # Since we start at 0x200

  suite "when executing instructions":
      test "can handle 00E0 (Clear display)":
        chip8.display[0] = true
        chip8.executeOp(0x00E0)
        check(chip8.display[0] == false)
        check(chip8.pc == 0x202)

      test "can handle 1nnn (Jump to location)":
        chip8.executeOp(0x1042)
        check(chip8.pc == 0x042)