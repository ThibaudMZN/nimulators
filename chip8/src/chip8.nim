import system

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
    registers: array[16, uint8]
    I: uint16
    pc*: uint16
    display*: array[DISPLAY_WIDTH * DISPLAY_HEIGHT, bool]
    delayTimer: uint8
    soundTimer: uint8
    stack: array[16, uint16]
    stackPointer: uint16
    keypad: array[16, bool]

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
    keypad: default(array[16, bool])
  )
  result.memory[0 ..< FONTSET.len] = FONTSET

proc incrementPc*(chip8: var Chip8) = 
  chip8.pc += 2

proc executeOp*(chip8: var Chip8, opcode: uint16) =
  case opcode shr 12:
    of 0x0:
      if opcode == 0x00E0:
        chip8.display = default(array[DISPLAY_WIDTH * DISPLAY_HEIGHT, bool])
        chip8.incrementPc()
    of 0x1:
      chip8.pc = opcode and 0x0FFF
    else:
      echo "Unknown opcode: ", $opcode

proc cycle*(chip8: var Chip8) =
  var opcode = uint16(chip8.memory[chip8.pc] shl 8 or chip8.memory[chip8.pc + 1])
  chip8.executeOp(opcode)