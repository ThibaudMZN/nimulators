import std/random

const
  MEMORY_SIZE = 4096
  DISPLAY_WIDTH = 64
  DISPLAY_HEIGHT = 32
  START_ADDRESS = 0x200
  FONTSET: array[80, uint8] = # Based on http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#font
    [ 
      0xF0, 0x90, 0x90, 0x90, 0xF0,
      0x20, 0x60, 0x20, 0x20, 0x70,
      0xF0, 0x10, 0xF0, 0x80, 0xF0,
      0xF0, 0x10, 0xF0, 0x10, 0xF0,
      0x90, 0x90, 0xF0, 0x10, 0x10,
      0xF0, 0x80, 0xF0, 0x10, 0xF0,
      0xF0, 0x80, 0xF0, 0x90, 0xF0,
      0xF0, 0x10, 0x20, 0x40, 0x40,
      0xF0, 0x90, 0xF0, 0x90, 0xF0,
      0xF0, 0x90, 0xF0, 0x10, 0xF0,
      0xF0, 0x90, 0xF0, 0x90, 0x90,
      0xE0, 0x90, 0xE0, 0x90, 0xE0,
      0xF0, 0x80, 0x80, 0x80, 0xF0,
      0xE0, 0x90, 0x90, 0x90, 0xE0,
      0xF0, 0x80, 0xF0, 0x80, 0xF0,
      0xF0, 0x80, 0xF0, 0x80, 0x80 
    ] 

type
  Chip8* = object
    memory*: array[MEMORY_SIZE, uint8]
    registers*: array[16, uint8]
    I*: uint16
    pc*: uint16
    display*: array[DISPLAY_WIDTH * DISPLAY_HEIGHT, bool]
    delayTimer: uint8
    soundTimer: uint8
    stack*: array[16, uint16]
    stackPointer*: uint16
    keypad: array[16, bool]
    rng*: Rand

proc initChip8*(): Chip8 =
  result = Chip8(
    memory: default(array[MEMORY_SIZE, uint8]),
    registers: default(array[16, uint8]),
    I: 0,
    pc: START_ADDRESS,
    display: default(array[DISPLAY_WIDTH * DISPLAY_HEIGHT, bool]),
    delayTimer: 0,
    soundTimer: 0,
    stack: default(array[16, uint16]),
    stackPointer: 0,
    keypad: default(array[16, bool]),
    rng: initRand()
  )
  result.memory[0 ..< FONTSET.len] = FONTSET

proc incrementPc*(chip8: var Chip8) = 
  chip8.pc += 2

proc currentStack(chip8: var Chip8): uint16 =
  chip8.stack[chip8.stackPointer]

proc `currentStack=`(chip8: var Chip8, stack: uint16) =
  chip8.stack[chip8.stackPointer] = stack

proc executeOp*(chip8: var Chip8, opcode: uint16) =
  case opcode shr 12:
    of 0x0:
      if opcode == 0x00E0:
        chip8.display = default(array[DISPLAY_WIDTH * DISPLAY_HEIGHT, bool])
        chip8.incrementPc()
      elif opcode == 0x00EE:
        chip8.stackPointer -= 1
        chip8.pc = chip8.currentStack
    of 0x1:
      chip8.pc = opcode and 0x0FFF
    of 0x2:
      chip8.currentStack = chip8.pc
      chip8.stackPointer += 1
      chip8.pc = opcode and 0x0FFF
    of 0x3:
      var x = (opcode and 0x0F00) shr 8
      if chip8.registers[x] == (opcode and 0x00FF):
        chip8.incrementPc()
      chip8.incrementPc()
    of 0x4:
      var x = (opcode and 0x0F00) shr 8
      if chip8.registers[x] != (opcode and 0x00FF):
        chip8.incrementPc()
      chip8.incrementPc()
    of 0x5:
      var x = (opcode and 0x0F00) shr 8
      var y = (opcode and 0x00F0) shr 4
      if chip8.registers[x] == chip8.registers[y]:
        chip8.incrementPc()
      chip8.incrementPc()
    of 0x6:
      var x = (opcode and 0x0F00) shr 8
      chip8.registers[x] = uint8(opcode and 0x00FF)
      chip8.incrementPc()
    of 0x7:
      var x = (opcode and 0x0F00) shr 8
      chip8.registers[x] += uint8(opcode and 0x00FF)
      chip8.incrementPc()
    of 0x8:
      var x = (opcode and 0x0F00) shr 8
      var y = (opcode and 0x00F0) shr 4
      var m = (opcode and 0x000F)
      case m:
        of 0:
          chip8.registers[x] = chip8.registers[y]
        of 1:
          chip8.registers[x] = chip8.registers[x] or chip8.registers[y]
        of 2:
          chip8.registers[x] = chip8.registers[x] and chip8.registers[y]
        of 3:
          chip8.registers[x] = chip8.registers[x] xor chip8.registers[y]
        of 4:
          chip8.registers[0xF] = uint8(uint16(chip8.registers[x]) + uint16(chip8.registers[y]) > 0xFF)
          chip8.registers[x] = chip8.registers[x] + chip8.registers[y]
        of 5:
          chip8.registers[0xF] = uint8(chip8.registers[x] > chip8.registers[y])
          chip8.registers[x] = chip8.registers[x] - chip8.registers[y]
        of 6:
          chip8.registers[0xF] = chip8.registers[x] and 0b00000001
          chip8.registers[x] = chip8.registers[x] shr 1
        of 7:
          chip8.registers[0xF] = uint8(chip8.registers[y] > chip8.registers[x])
          chip8.registers[x] = chip8.registers[y] - chip8.registers[x]
        of 0xE:
          chip8.registers[0xF] = (chip8.registers[x] and 0b10000000) shr 7
          chip8.registers[x] = chip8.registers[x] shl 1
        else:
          echo "Unknown mode for ALU 0x8, mode: ", $m
      chip8.incrementPc()
    of 0x9:
      var x = (opcode and 0x0F00) shr 8
      var y = (opcode and 0x00F0) shr 4
      if chip8.registers[x] != chip8.registers[y]:
        chip8.incrementPc()
      chip8.incrementPc()
    of 0xA:
      chip8.I = (opcode and 0x0FFF)
      chip8.incrementPc()
    of 0xB:
      chip8.pc = (opcode and 0x0FFF) + chip8.registers[0]
    of 0xC:
      var x = (opcode and 0x0F00) shr 8
      var kk = uint8(opcode and 0x00FF)
      var r = uint8(chip8.rng.rand(255))
      chip8.registers[x] = r and kk
      chip8.incrementPc()
    else:
      echo "Unknown opcode: ", $opcode

proc cycle*(chip8: var Chip8) =
  var opcode = uint16(chip8.memory[chip8.pc] shl 8 or chip8.memory[chip8.pc + 1])
  chip8.executeOp(opcode)