import mmu
import registers
import strutils
import opcodes

type
  CPU* = object
    mmu*: Memory
    sp, pc: uint16      # Stack Pointer and Program Counter
    halt, interrupts: bool
    regs: Registers

proc initCPU*(memory: Memory): CPU =
  CPU(
    mmu: memory,
    sp: 0xFFFE,
    pc: 0x0100,
    regs: initRegisters()
  )

proc debugOp(op: Opcode, cpu: CPU) = 
  echo "PC:0x$5\tINST: 0x$1:\t$2\t$3\t$4" % [toHex(op.opcode), op.mnemonic, op.operandOne, op.operandTwo, toHex(cpu.pc)]

proc a16(cpu: var CPU): uint16 =
  let lo = cpu.mmu.read8(cpu.pc + 1).uint16
  let hi = cpu.mmu.read8(cpu.pc + 2).uint16
  return (hi shl 8) or lo

proc d8(cpu: var CPU): uint8 =
  cpu.mmu.read8(cpu.pc + 1)

proc push(cpu: var CPU, address: uint16) =
  cpu.mmu.write8(cpu.sp - 1, uint8(address shr 8))
  cpu.mmu.write8(cpu.sp - 2, uint8(address and 0xFF))
  cpu.sp.dec(2)

proc pop(cpu: var CPU): uint16 =
  result = ((cpu.mmu.read8(cpu.sp + 1).uint16) shl 8) or cpu.mmu.read8(cpu.sp).uint16
  cpu.sp += 2

proc OR(cpu: var CPU, val: uint8) =
  cpu.regs["A"] = cpu.regs["A"] or val
  cpu.regs.flags_Z = cpu.regs["A"] == 0
  cpu.regs.flags_N = false
  cpu.regs.flags_H = false
  cpu.regs.flags_C = false

proc CP(cpu: var CPU, val: uint8) =
  cpu.regs.flags_Z = cpu.regs["A"] == val
  cpu.regs.flags_N = true
  cpu.regs.flags_H = (cpu.regs["A"] or 0x0F) < (val and 0x0F)
  cpu.regs.flags_C = cpu.regs["A"] < val

proc ADD(cpu: var CPU, val: uint8) =
  cpu.regs.flags_C = cpu.regs["A"].int32 + val.int32 > 0xFF
  cpu.regs.flags_H = (cpu.regs["A"] and 0x0F) + (val and 0x0F) > 0x0F
  cpu.regs.flags_N = false
  cpu.regs["A"] = cpu.regs["A"] + val
  cpu.regs.flags_Z = cpu.regs["A"] == 0

proc SUB(cpu: var CPU, val: uint8) =
  cpu.regs.flags_C = cpu.regs["A"] < val
  cpu.regs.flags_H = (cpu.regs["A"] and 0x0F) < (val and 0x0F)
  cpu.regs["A"] = cpu.regs["A"] - val
  cpu.regs.flags_Z = cpu.regs["A"] == 0
  cpu.regs.flags_N = true

proc XOR(cpu: var CPU, val: uint8) =
  cpu.regs["A"] = cpu.regs["A"] xor val
  cpu.regs.flags_Z = cpu.regs["A"] == 0
  cpu.regs.flags_N = false
  cpu.regs.flags_H = false
  cpu.regs.flags_C = false

proc AND(cpu: var CPU, val: uint8) =
  cpu.regs["A"] = cpu.regs["A"] and val
  cpu.regs.flags_Z = cpu.regs["A"] == 0
  cpu.regs.flags_N = false
  cpu.regs.flags_H = true
  cpu.regs.flags_C = false

proc executeOp(cpu: var CPU, opcode: Opcode) =
  debugOp(opcode, cpu)
  var skipInc = false
  case opcode.mnemonic:
    of "NOP":
      discard
    of "JP":
      if opcode.operandOne == "A16":
        cpu.pc = cpu.a16
        skipInc = true
      else:
        echo "Unknown case: ", opcode
        quit()
    of "DI":
      cpu.interrupts = false
    of "LD":
      var src: uint16
      case opcode.operandTwo:
        of "D16":
          src = cpu.a16
        of "A", "B", "C", "D", "E", "H", "L":
          src = cpu.regs[opcode.operandTwo]
        of "D8":
          src = cpu.d8
        of "(BC)":
          src = cpu.mmu.read8(cpu.regs.BC)
        of "(HL)":
          src = cpu.mmu.read8(cpu.regs.HL)
        of "(HL+)":
          src = cpu.mmu.read8(cpu.regs.HL)
          cpu.regs.HL.inc()
        else:
          echo "Unknown Operand 2: ", opcode.operandTwo
          quit()
      
      case opcode.operandOne:
        of "SP":
          cpu.sp = src
        of "(A16)":
          cpu.mmu.write8(cpu.a16, src.uint8)
        of "A", "B", "C", "D", "E", "H", "L":
          cpu.regs[opcode.operandOne] = src.uint8
        of "BC":
          cpu.regs.BC = src
        of "(BC)":
          cpu.mmu.write8(cpu.regs.BC, src.uint8)
        of "HL":
          cpu.regs.HL = src
        of "(HL)":
          cpu.mmu.write8(cpu.regs.HL, src.uint8)
        of "(HL-)":
          cpu.mmu.write8(cpu.regs.HL, src.uint8)
          cpu.regs.HL.dec()
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "LDH":
      var src: uint16
      case opcode.operandTwo:
        of "A", "B", "C", "D", "E", "H", "L":
          src = cpu.regs[opcode.operandTwo]
        of "(A8)":
          src = cpu.mmu.read16(cpu.d8)
        else:
          echo "Unknown Operand 2: ", opcode.operandTwo
          quit()
      
      case opcode.operandOne:
        of "(A8)":
          cpu.mmu.write8(0xFF00 + cpu.d8.uint16, src.uint8)
        of "A", "B", "C", "D", "E", "H", "L":
          src = 0xFF00 + src.uint16
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "CALL":
      case opcode.operandOne:
        of "A16":
          skipInc = true
          cpu.push(cpu.pc + 3)
          cpu.pc = cpu.a16 
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "JR":
      # Not sure we need to increment here or not
      # skipInc = true

      # NO condition jump
      if opcode.operandOne != "" and opcode.operandTwo == "":
        case opcode.operandOne:
          of "R8":
            cpu.pc = (cpu.pc.int32 + cpu.d8.int32).uint16
          else:
            echo "Unknown Operand 1: ", opcode.operandOne
            quit()
      # Jump with condition
      else:
        if opcode.operandTwo == "R8":
          case opcode.operandOne:
            of "Z":
              if cpu.regs.flags_Z:
                cpu.pc = (cpu.pc.int32 + cpu.d8.int32).uint16
            of "NZ":
              if not cpu.regs.flags_Z:
                cpu.pc = (cpu.pc.int32 + cpu.d8.int32).uint16
            of "C":
              if cpu.regs.flags_C:
                cpu.pc = (cpu.pc.int32 + cpu.d8.int32).uint16
            of "NC":
              if not cpu.regs.flags_C:
                cpu.pc = (cpu.pc.int32 + cpu.d8.int32).uint16
            else:
              echo "Unknown Operand 1: ", opcode.operandOne
              quit()
        else:
          echo "Unknown Operand 2: ", opcode.operandTwo
          quit()
    of "RET":
      skipInc = true
      cpu.pc = cpu.pop()
    of "PUSH":
      case opcode.operandOne:
        of "AF":
          cpu.push(cpu.regs.AF)
        of "BC":
          cpu.push(cpu.regs.BC)
        of "DE":
          cpu.push(cpu.regs.DE)
        of "HL":
          cpu.push(cpu.regs.HL)
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "POP":
      case opcode.operandOne:
        of "AF":
          cpu.regs.AF = cpu.pop() and 0xFFF0
        of "HL":
          cpu.regs.HL = cpu.pop() and 0xFFF0
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "INC":
      case opcode.operandOne:
        of "A", "B", "C", "D", "E", "H", "L":
          cpu.regs[opcode.operandOne] = cpu.regs[opcode.operandOne] + 1
        of "BC":
          cpu.regs.BC.inc()
        of "HL":
          cpu.regs.HL.inc()
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "OR":
      var src: uint8
      case opcode.operandOne:
        of "A", "B", "C", "D", "E", "H", "L":
          src = cpu.regs[opcode.operandOne]
          cpu.OR(src)
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "CP":
      var src: uint8
      case opcode.operandOne:
        of "D8":
          src = cpu.d8
          cpu.CP(src)
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "DEC":
      case opcode.operandOne:
        of "B", "C", "D", "E", "H", "L":
          var src = cpu.regs[opcode.operandOne]
          src.dec()
          cpu.regs.flags_H = (src and 0x0F) == 0x0F
          cpu.regs.flags_Z = src == 0
          cpu.regs.flags_N = true
          cpu.regs[opcode.operandOne] = src
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "ADD":
      if opcode.operandOne == "HL":
        var src: uint16
        case opcode.operandTwo:
          of "BC":
            src = cpu.regs.BC
          of "DE":
            src = cpu.regs.DE
          of "HL":
            src = cpu.regs.HL
          of "SP":
            src = cpu.sp
          else:
            echo "Unknown Operand 2: ", opcode.operandTwo
        cpu.regs.flags_H = ((cpu.regs.HL and 0x0FFF) + (src and 0x0FFF) > 0x0FFF)
        cpu.regs.flags_C = (cpu.regs.HL.int32 + src.int32 > 0xFFFF)
        cpu.regs.HL += src
        cpu.regs.flags_N = false
      elif opcode.operandOne != "A":
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
      else:
        var src: uint8
        case opcode.operandTwo:
          of "D8":
            src = cpu.d8
            cpu.ADD(src)
          else:
            echo "Unknown Operand 2: ", opcode.operandTwo
            quit()
    of "SUB":
      var src: uint8
      case opcode.operandOne:
        of "D8":
          src = cpu.d8
          cpu.SUB(src)
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "XOR":
      var src: uint8
      case opcode.operandOne:
        of "D8":
          src = cpu.d8
          cpu.XOR(src)
        of "(HL)":
          src = cpu.mmu.read8(cpu.regs.HL)
          cpu.XOR(src)
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "AND":
      var src: uint8
      case opcode.operandOne:
        of "D8":
          src = cpu.d8
          cpu.AND(src)
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "HALT":
      cpu.halt = true
    of "RLCA":
      cpu.regs.flags_C = (cpu.regs["A"] and (1 shl 7)) != 0
      cpu.regs["A"] = (cpu.regs["A"] shl 1) or (cpu.regs["A"] shr 7)
      cpu.regs.flags_N = false
      cpu.regs.flags_H = false
      cpu.regs.flags_Z = false
    of "CPL":
      cpu.regs["A"] = cpu.regs["A"] xor 0xFF
      cpu.regs.flags_N = true
      cpu.regs.flags_H = true
    of "RST":
      skipInc = true
      var targetStr = opcode.operandOne
      targetStr.removeSuffix('H')
      let target = fromHex[uint16](targetStr)
      cpu.push(cpu.pc)
      cpu.pc = target.uint16
    of "PREFIXCB":
      var prefixOpcode = prefixOpcs[cpu.mmu.read8(cpu.pc + 1)]
      debugOp(prefixOpcode, cpu)
      var src: uint8
      var currentFlagC: bool
      var operandTwoIsTarget = false
      case prefixOpcode.operandOne:
        of "A", "B", "C", "D", "E", "H", "L":
          src = cpu.regs[prefixOpcode.operandOne]
        else:
          case prefixOpcode.operandTwo:
            of "A", "B", "C", "D", "E", "H", "L":
              src = cpu.regs[prefixOpcode.operandTwo]
              operandTwoIsTarget = true
            else:
              echo "Unknown Operand for PREFIX: ", prefixOpcode.operandOne, prefixOpcode.operandTwo
              quit()
      case prefixOpcode.mnemonic:
        of "SRL":
          cpu.regs.flags_C = (src and (1 shl 0)) != 0
          src = src shr 1
          cpu.regs.flags_N = false
          cpu.regs.flags_H = false
          cpu.regs.flags_Z = src == 0
        of "RR":
          currentFlagC = cpu.regs.flags_C
          cpu.regs.flags_C = (src and (1 shl 0)) != 0
          src = src shr 1
          if currentFlagC:
              src = src or (1 shl 7)
          cpu.regs.flags_N = false
          cpu.regs.flags_H = false
          cpu.regs.flags_Z = src == 0
        of "BIT":
          let bit = parseInt(prefixOpcode.operandOne)
          cpu.regs.flags_Z = (src and (1 shl bit).uint8) == 0
          cpu.regs.flags_N = false
          cpu.regs.flags_H = true
        else:
          echo "Unknown PREFIX mnemonic: ", prefixOpcode.mnemonic
          quit()
      cpu.regs[if operandTwoIsTarget: prefixOpcode.operandTwo else: prefixOpcode.operandOne] = src
      cpu.pc.inc(prefixOpcode.len)
    else:
      echo "Unknown mnemonic: ", opcode.mnemonic
      quit()

  if not skipInc:
    cpu.pc.inc(opcode.len)

proc update*(cpu: var CPU): int =
  var opcode = opcs[cpu.mmu.read8(cpu.pc)]
  cpu.executeOp(opcode)
  # TODO: We need to make sure we handle all flags here
  # if opcode.z != '-': echo "Should have assigned Z flag here"
  # if opcode.h != '-': echo "Should have assigned H flag here"
  # if opcode.n != '-': echo "Should have assigned N flag here"
  # if opcode.c != '-': echo "Should have assigned C flag here"
  return opcode.cycles