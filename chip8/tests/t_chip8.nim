import unittest
import std/random
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

  suite "when executing instructions, can handle":
      test "00E0 (Clear display)":
        chip8.display[0] = true
        chip8.executeOp(0x00E0)
        check(chip8.display[0] == false)
        check(chip8.pc == 0x202)

      test "00EE (Return from subroutine)":
        chip8.stack[0] = 0x242
        chip8.stackPointer = 1
        chip8.executeOp(0x00EE)
        check(chip8.pc == 0x242)
        check(chip8.stackPointer == 0)

      test "1nnn (Jump to location)":
        chip8.executeOp(0x1042)
        check(chip8.pc == 0x042)

      test "2nnn (Call subroutine)":
        chip8.executeOp(0x2042)
        check(chip8.stackPointer == 1)
        check(chip8.stack[0] == 0x200)
        check(chip8.pc == 0x042)

      test "3xkk (Skip next instruction - equal)":
        chip8.registers[1] = 0x42
        chip8.executeOp(0x3142)
        check(chip8.pc == 0x204) # Has incremented PC twice

        chip8.registers[1] = 0x64
        chip8.executeOp(0x3142)
        check(chip8.pc == 0x206) # Has incremented PC only once since 64 != 42

      test "4xkk (Skip next instruction - not equal)":
        chip8.registers[1] = 0x42
        chip8.executeOp(0x4142)
        check(chip8.pc == 0x202) # Has incremented PC only once since 42 == 42

        chip8.registers[1] = 0x64
        chip8.executeOp(0x4142)
        check(chip8.pc == 0x206) # Has incremented PC twice since 64 != 42

      test "5xy0 (Skip next instruction - registers equal)":
        chip8.registers[1] = 0x42
        chip8.registers[2] = 0x42
        chip8.executeOp(0x5120)
        check(chip8.pc == 0x204) # Has incremented PC twice

        chip8.registers[1] = 0x64
        chip8.executeOp(0x5120)
        check(chip8.pc == 0x206) # Has incremented PC only once since 64 != 42

      test "6xkk (Load)":
        chip8.executeOp(0x6042)
        check(chip8.registers[0] == 0x42)
        check(chip8.pc == 0x202)

      test "7xkk (Add)":
        chip8.registers[0] = 0x42
        chip8.executeOp(0x7042)
        check(chip8.registers[0] == 0x84)
        check(chip8.pc == 0x202)

        # Make sure that overflow is not a problem (expected behavior)
        chip8.registers[0] = 0xFF
        chip8.executeOp(0x7002)
        check(chip8.registers[0] == 0x01)
        check(chip8.pc == 0x204)

      test "8xy0 (Load from register)":
        chip8.registers[1] = 0x42
        chip8.executeOp(0x8010)
        check(chip8.registers[0] == 0x42)
        check(chip8.pc == 0x202)

      test "8xy1 (OR from register)":
        chip8.registers[0] = 0x01
        chip8.registers[1] = 0x10
        chip8.executeOp(0x8011)
        check(chip8.registers[0] == 0x11)
        check(chip8.pc == 0x202)

      test "8xy2 (AND from register)":
        chip8.registers[0] = 0x11
        chip8.registers[1] = 0x10
        chip8.executeOp(0x8012)
        check(chip8.registers[0] == 0x10)
        check(chip8.pc == 0x202)

      test "8xy3 (XOR from register)":
        chip8.registers[0] = 0x11
        chip8.registers[1] = 0x10
        chip8.executeOp(0x8013)
        check(chip8.registers[0] == 0x01)
        check(chip8.pc == 0x202)

      test "8xy4 (ADD from register with carry flag)":
        chip8.registers[0] = 0xFF
        chip8.registers[1] = 0x02
        chip8.executeOp(0x8014)
        check(chip8.registers[0] == 0x01)
        check(chip8.registers[0xF] == 0x01)
        check(chip8.pc == 0x202)

        chip8.registers[0] = 0x42
        chip8.registers[1] = 0x42
        chip8.executeOp(0x8014)
        check(chip8.registers[0] == 0x84)
        check(chip8.registers[0xF] == 0)
        check(chip8.pc == 0x204)

      test "8xy5 (SUB from register with NOT borrow flag)":
        chip8.registers[0] = 0xFF
        chip8.registers[1] = 0x01
        chip8.executeOp(0x8015)
        check(chip8.registers[0] == 0xFE)
        check(chip8.registers[0xF] == 0x01)
        check(chip8.pc == 0x202)

        chip8.registers[0] = 0x01
        chip8.registers[1] = 0x02
        chip8.executeOp(0x8015)
        check(chip8.registers[0] == 0xFF)
        check(chip8.registers[0xF] == 0)
        check(chip8.pc == 0x204)

      test "8xy6 (Least significant bit)":
        chip8.registers[0] = 0x03
        chip8.executeOp(0x8016)
        check(chip8.registers[0] == 0x01)
        check(chip8.registers[0xF] == 0x01)
        check(chip8.pc == 0x202)

        chip8.registers[0] = 0x02
        chip8.executeOp(0x8016)
        check(chip8.registers[0] == 0x01)
        check(chip8.registers[0xF] == 0)
        check(chip8.pc == 0x204)

      test "8xy7 (SUB from register with NOT borrow flag Vy - Vx)":
        chip8.registers[0] = 0x01
        chip8.registers[1] = 0xFF
        chip8.executeOp(0x8017)
        check(chip8.registers[0] == 0xFE)
        check(chip8.registers[0xF] == 0x01)
        check(chip8.pc == 0x202)

        chip8.registers[0] = 0xFF
        chip8.registers[1] = 0x01
        chip8.executeOp(0x8017)
        check(chip8.registers[0] == 0x02)
        check(chip8.registers[0xF] == 0)
        check(chip8.pc == 0x204)

      test "8xyE (Most significant bit)":
        chip8.registers[0] = 0xF0
        chip8.executeOp(0x801E)
        check(chip8.registers[0] == 0xE0)
        check(chip8.registers[0xF] == 0x01)
        check(chip8.pc == 0x202)

        chip8.registers[0] = 0x01
        chip8.executeOp(0x801E)
        check(chip8.registers[0] == 0x02)
        check(chip8.registers[0xF] == 0)
        check(chip8.pc == 0x204)

      test "9xy0 (Skip next instruction - registers not equal)":
        chip8.registers[1] = 0x42
        chip8.registers[2] = 0x42
        chip8.executeOp(0x9120)
        check(chip8.pc == 0x202) # Has incremented PC only once since 42 != 42

        chip8.registers[1] = 0x64
        chip8.executeOp(0x9120)
        check(chip8.pc == 0x206) # Has incremented PC twice

      test "Annn (Set index)":
        chip8.executeOp(0xA042)
        check(chip8.I == 0x42)
        check(chip8.pc == 0x202)

      test "Bnnn (Jump to V0 + nnn)":
        chip8.registers[0] = 0x42
        chip8.executeOp(0xB042)
        check(chip8.pc == 0x84)

      test "Cxkk (Random byte AND kk)":
        var rng = initRand(1) # Will always give 251 as first output
        chip8.rng = rng
        chip8.executeOp(0xC010)
        check(chip8.registers[0] == 0x10)
        check(chip8.pc == 0x202)