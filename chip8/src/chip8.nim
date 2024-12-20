import std/random
import os
import std/strutils

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
    delayTimer*: uint8
    soundTimer*: uint8
    stack*: array[16, uint16]
    stackPointer*: uint16
    keypad*: array[16, bool]
    rng*: Rand
    drawFlag*: bool

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
    rng: initRand(),
    drawFlag: false
  )
  result.memory[0 ..< FONTSET.len] = FONTSET

proc incrementPc*(chip8: var Chip8) = 
  chip8.pc += 2

proc currentStack(chip8: var Chip8): uint16 =
  chip8.stack[chip8.stackPointer]

proc `currentStack=`(chip8: var Chip8, stack: uint16) =
  chip8.stack[chip8.stackPointer] = stack

proc executeOp*(chip8: var Chip8, opcode: uint16) =
  chip8.drawFlag = false
  case opcode shr 12:
    of 0x0:
      if opcode == 0x00E0:
        chip8.display = default(array[DISPLAY_WIDTH * DISPLAY_HEIGHT, bool])
        chip8.incrementPc()
        chip8.drawFlag = true
      elif opcode == 0x00EE:
        dec(chip8.stackPointer)
        chip8.pc = chip8.currentStack
        chip8.incrementPc()
      else:
        echo "Unknown opcode 0x0", $opcode
    of 0x1:
      chip8.pc = opcode and 0x0FFF
    of 0x2:
      chip8.currentStack = chip8.pc
      inc(chip8.stackPointer)
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
      var kk = uint8(opcode and 0x00FF)
      chip8.registers[x] = kk
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
    of 0xD:
      var n = opcode and 0x000F
      chip8.registers[0xF] = 0
      var regX = chip8.registers[(opcode and 0x0F00) shr 8]
      var regY = chip8.registers[(opcode and 0x00F0) shr 4]
      var y = uint16(0)
      while y < n:
        var spr = chip8.memory[chip8.I + y];
        var x = uint16(0)
        while x < 8:
          const msb = uint8(0x80)
          if (spr and (msb shr x)) != 0:
              var tX = (regX + x) mod 64
              var tY = (regY + y) mod 32
              var idx = tX + tY * 64
              chip8.display[idx] = chip8.display[idx] xor true;
              if chip8.display[idx] == false:
                chip8.registers[0x0F] = 1
          x += 1
        y += 1
      chip8.drawFlag = true
      chip8.incrementPc()
    of 0xE:
      var x = (opcode and 0x0F00) shr 8
      var m = (opcode and 0x00FF)
      case m:
        of 0x9e:
          if chip8.keypad[chip8.registers[x]]:
            chip8.incrementPc()
        of 0xA1:
          if not chip8.keypad[chip8.registers[x]]:
            chip8.incrementPc()
        else:
          echo "Unknown mode for key handling 0xE, mode: ", $m
      chip8.incrementPc()
    of 0xF:
      var x = (opcode and 0x0F00) shr 8
      var m = (opcode and 0x00FF)
      case m:
        of 0x07:
          chip8.registers[x] = chip8.delayTimer
        of 0x0A:
          var key_pressed = false;
          var i = uint8(0)
          while i < 16:
            if chip8.keypad[i]:
              chip8.registers[x] = i
              key_pressed = true
              break
            i += 1
                    
          if not key_pressed:
            return
        of 0x15:
          chip8.delayTimer = chip8.registers[x]
        of 0x18:
          chip8.soundTimer = chip8.registers[x]
        of 0x1E:
          var vx = chip8.registers[x]
          chip8.registers[0x0f] = if chip8.I + vx > uint16(0xfff): 1 else: 0
          chip8.I += vx
        of 0x29:
          chip8.I = chip8.registers[x] * 0x5
        of 0x33:
          chip8.memory[chip8.I] = chip8.registers[x] div 100
          chip8.memory[chip8.I + 1] = (chip8.registers[x] div 10) mod 10
          chip8.memory[chip8.I + 2] = chip8.registers[x] mod 10
        of 0x55:
          var i = uint8(0)
          while i <= x:
            chip8.memory[chip8.I + i] = chip8.registers[i];
            i += 1
        of 0x65:
          var i = uint8(0)
          while i <= x:
            chip8.registers[i] = chip8.memory[chip8.I + i]
            i += 1
        else:
          echo "Unknown mode for misc handling 0xF, mode: ", $m
      chip8.incrementPc()
    else:
      echo "Unknown opcode: ", $opcode

proc cycle*(chip8: var Chip8) =
  var opcode = (uint16(chip8.memory[chip8.pc]) shl 8) or chip8.memory[chip8.pc + 1]
  chip8.executeOp(opcode)
  if chip8.delayTimer > 0:
    chip8.delayTimer -= 1

  if chip8.soundTimer > 0:
    chip8.soundTimer -= 1

proc loadROM*(chip8: var Chip8, romPath: string) =
  if not fileExists(romPath):
    raise newException(IOError, "ROM file not found!")
  let romData = readFile(romPath)
  chip8.memory[0x200 ..< 0x200 + romData.len] = cast[seq[byte]](romData)