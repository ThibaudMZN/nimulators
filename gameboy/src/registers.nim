import strutils

const
  FLAG_Z: uint8 = 0b1000_0000
  FLAG_N: uint8 = 0b0100_0000
  FLAG_H: uint8 = 0b0010_0000
  FLAG_C: uint8 = 0b0001_0000

type 
  Registers* = object
    AF*: uint16
    BC*: uint16
    DE*: uint16
    HL*: uint16

proc initRegisters*(): Registers =
  Registers(
    AF: 0x01B0,
    BC: 0x0013,
    DE: 0x00D8,
    HL: 0x014D
  )

proc hi(val: uint16): uint8 =
  return uint8((val and 0xFF00) shr 8)

proc lo(val: uint16): uint8 =
  return uint8(val and 0x00FF)

proc `[]`*(regs: var Registers, idx: string): uint8 =
  case idx:
    of "A":
      return regs.AF.hi
    of "B":
      return regs.BC.hi
    of "C":
      return regs.BC.lo
    of "D":
      return regs.DE.hi
    of "E":
      return regs.DE.lo
    of "H":
      return regs.HL.hi
    of "L":
      return regs.HL.lo
    else:
      raise newException(IndexDefect, "No register $1 found" % [idx])

proc `[]=`*(regs: var Registers, idx: string, val: uint8) =
  case idx:
    of "A":
      regs.AF = regs.AF.lo().uint16 or (uint16(val) shl 8)
    of "B":
      regs.BC = regs.BC.lo().uint16 or (uint16(val) shl 8)
    of "C":
      regs.BC = (regs.BC and 0xFF00) or uint16(val)
    of "D":
      regs.DE = regs.DE.lo().uint16 or (uint16(val) shl 8)
    of "E":
      regs.DE = (regs.DE and 0xFF00) or uint16(val)
    of "H":
      regs.HL = regs.HL.lo().uint16 or (uint16(val) shl 8)
    of "L":
      regs.HL = (regs.HL and 0xFF00) or uint16(val)
    else:
      raise newException(IndexDefect, "No register $1 found" % [idx])

proc F(regs: Registers): uint8 =
 regs.AF.lo

proc `F=`(regs: var Registers, val: uint8) =
  regs.AF = (regs.AF and 0xFF00) or uint16(val)

proc `flags_Z`*(regs: Registers): bool =
  (regs.F and FLAG_Z) != 0

proc `flags_Z=`*(regs: var Registers, value: bool) =
  regs.F = if value: (regs.F or FLAG_Z) else: (regs.F and not FLAG_Z)

proc `flags_N`*(regs: Registers): bool =
  (regs.F and FLAG_N) != 0

proc `flags_N=`*(regs: var Registers, value: bool) =
  regs.F = if value: (regs.F or FLAG_N) else: (regs.F and not FLAG_N)

proc `flags_H`*(regs: Registers): bool =
  (regs.F and FLAG_H) != 0

proc `flags_H=`*(regs: var Registers, value: bool) =
  regs.F = if value: (regs.F or FLAG_H) else: (regs.F and not FLAG_H)

proc `flags_C`*(regs: Registers): bool =
  (regs.F and FLAG_C) != 0

proc `flags_C=`*(regs: var Registers, value: bool) =
  regs.F = if value: (regs.F or FLAG_C) else: (regs.F and not FLAG_C)