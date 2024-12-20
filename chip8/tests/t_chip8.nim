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
        check(chip8.pc == 0x244)
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

      test "Dxyn (Display n-byte sprite)":
        # I is 0, so we should draw what is at memory[0], which is the first byte of the "0" from the fontset
        chip8.executeOp(0xD001)
        check(chip8.display[0] == true)
        check(chip8.registers[0x0F] == 0)
        check(chip8.drawFlag == true)
        check(chip8.pc == 0x202)

        # Now if we execute the same command, we should "erase" the 0
        chip8.executeOp(0xD001)
        check(chip8.display[0] == false)
        check(chip8.registers[0x0F] == 1)
        check(chip8.pc == 0x204)

      test "Ex9E (Skip if key pressed)":
        chip8.registers[0] = 0x01
        chip8.keypad[0x01] = true
        chip8.executeOp(0xE09E)
        check(chip8.pc == 0x204) # Skipped because key is pressed

        chip8.keypad[0x01] = false
        chip8.executeOp(0xE09E)
        check(chip8.pc == 0x206) # Not skipped because key is not pressed

      test "ExA1 (Skip if key not pressed)":
        chip8.registers[0] = 0x01
        chip8.keypad[0x01] = false
        chip8.executeOp(0xE0A1)
        check(chip8.pc == 0x204) # Skipped because key is not pressed

        chip8.keypad[0x01] = true
        chip8.executeOp(0xE0A1)
        check(chip8.pc == 0x206) # Not skipped because key is pressed

      test "Fx07 (Load Delay timer)":
        chip8.delayTimer = 0x42
        chip8.executeOp(0xF007)
        check(chip8.registers[0] == 0x42)

      test "Fx0A (Wait for key press)":
        chip8.keypad[0x02] = true
        chip8.executeOp(0xF00A)
        check(chip8.registers[0] == 0x02)

      test "Fx15 (Set Delay timer)":
        chip8.registers[0] = 0x42
        chip8.executeOp(0xF015)
        check(chip8.delayTimer == 0x42)

      test "Fx18 (Set Delay timer)":
        chip8.registers[0] = 0x42
        chip8.executeOp(0xF018)
        check(chip8.soundTimer == 0x42)

      test "Fx1E (Add index)":
        chip8.I = 0x01
        chip8.registers[0] = 0x42
        chip8.executeOp(0xF01E)
        check(chip8.I == 0x43)

      test "Fx29 (Set index to sprite location)":
        chip8.registers[0] = 0x03
        chip8.executeOp(0xF029)
        check(chip8.I == 15) # Since each font char is 5 byte

      test "Fx33 (Store BCD representation)":
        chip8.registers[0] = 123
        chip8.executeOp(0xF033)
        check(chip8.memory[0] == 1)
        check(chip8.memory[1] == 2)
        check(chip8.memory[2] == 3)

      test "Fx55 (Store registers)":
        chip8.registers[0] = 0x42
        chip8.registers[1] = 0x84
        chip8.executeOp(0xF155)
        check(chip8.memory[0] == 0x42)
        check(chip8.memory[1] == 0x84)

      test "Fx65 (Store registers)":
        chip8.memory[0] = 0x42
        chip8.memory[1] = 0x84
        chip8.executeOp(0xF165)
        check(chip8.registers[0] == 0x42)
        check(chip8.registers[1] == 0x84)