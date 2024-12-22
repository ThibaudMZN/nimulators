import unittest
import ../src/registers

suite "The CPU Registers":
  setup:
    var regs = initRegisters()

  test "can access 16bits registers":
    check(regs.AF == 0x01B0)
    check(regs.BC == 0x0013)
    check(regs.DE == 0x00D8)
    check(regs.HL == 0x014D)
  
  test "can access 8bits registers with string index":
    check(regs["A"] == 0x01)
    check(regs["B"] == 0x00)
    check(regs["C"] == 0x13)
    check(regs["D"] == 0x00)
    check(regs["E"] == 0xD8)
    check(regs["H"] == 0x01)
    check(regs["L"] == 0x4D)
    # F register is only used for flag and should not be accessed through indexing
    expect IndexDefect:
      discard regs["F"]

  test "can write to 8bits registers with string index":
    regs["A"] = 0x42
    check(regs.AF == 0x42B0)
    regs["B"] = 0x42
    check(regs.BC == 0x4213)
    regs["C"] = 0x42
    check(regs.BC == 0x4242)
    regs["D"] = 0x42
    check(regs.DE == 0x42D8)
    regs["E"] = 0x42
    check(regs.DE == 0x4242)
    regs["H"] = 0x42
    check(regs.HL == 0x424D)
    regs["L"] = 0x42
    check(regs.HL == 0x4242)
    # # F register is only used for flag and should not be written through indexing
    expect IndexDefect:
      regs["F"] = 0x42

  suite "when using flags (F register)":
    setup:
      var regs = initRegisters()
      regs.AF = 0x0

    test "can set and read Z Flag":
      regs.flags_Z = true
      check(regs.flags_Z == true)
      check(regs.AF == 0x0080)

      regs.flags_Z = false
      check(regs.flags_Z == false)
      check(regs.AF == 0x0000)
    
    test "can set and read N Flag":
      regs.flags_N = true
      check(regs.flags_N == true)
      check(regs.AF == 0x0040)

      regs.flags_N = false
      check(regs.flags_N == false)
      check(regs.AF == 0x0000)
    
    test "can set and read H Flag":
      regs.flags_H = true
      check(regs.flags_H == true)
      check(regs.AF == 0x0020)

      regs.flags_H = false
      check(regs.flags_H == false)
      check(regs.AF == 0x0000)
    
    test "can set and read C Flag":
      regs.flags_C = true
      check(regs.flags_C == true)
      check(regs.AF == 0x0010)

      regs.flags_C = false
      check(regs.flags_C == false)
      check(regs.AF == 0x0000)
