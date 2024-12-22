import os

const
  MEMORY_SIZE = 0xFFFF+1

type
  Memory* = object
    memory*: array[MEMORY_SIZE, uint8]

proc initMemory*(): Memory =
  Memory(
    memory: default(array[MEMORY_SIZE, uint8])
  )

proc read8*(m: Memory, address: uint16): uint8 =
  return m.memory[address]

proc read16*(m: Memory, address: uint16): uint16 =
  return (m.memory[address+1].uint16 shl 8) or m.memory[address]

proc write8*(m: var Memory, address: uint16, data: uint8) =
  m.memory[address] = data

proc write16*(m: var Memory, address: uint16, data: uint16) =
  m.memory[address] = (data shr 8).uint8
  m.memory[address+1] = ((data shl 8) shr 8).uint8

proc loadROM*(m: var Memory, romPath: string) =
  if not fileExists(romPath):
    raise newException(IOError, "ROM file not found!")
  let romData = readFile(romPath)
  m.memory[0 ..< romData.len] = cast[seq[byte]](romData)