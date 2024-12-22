import unittest, os
import ../src/mmu

suite "The Memory Management Unit (MMU)":
  setup:
    var mem = initMemory()

  test "can read/write 8 bits":
    mem.write8(0x0000, 0x42)
    check(mem.read8(0x0000) == 0x42)

  test "can read/write 16 bits":
    mem.write16(0x0000, 0x4242)
    check(mem.read16(0x0000) == 0x4242)

  suite "when loading ROM":
    test "can load":
      writeFile("test.gb", [byte(0x42), byte(0x84)])
      mem.loadROM("test.gb")
      check(mem.memory[0] == 0x42)
      check(mem.memory[1] == 0x84)
      removeFile("test.gb")

    test "throws error if ROM not found":
      expect IOError:
        mem.loadROM("/rom/not/found")