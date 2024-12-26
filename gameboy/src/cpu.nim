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

proc debugUnknownOperand(op: Opcode, operandNum: int) =
  let errMsg: string = "Unknown Operand " & intToStr(operandNum) & ": " & repr(op)
  raise newException(ValueError, errMsg)

proc a16(cpu: var CPU): uint16 =
  let lo = cpu.mmu.read8(cpu.pc + 1).uint16
  let hi = cpu.mmu.read8(cpu.pc + 2).uint16
  return (hi shl 8) or lo

proc d8(cpu: var CPU): uint8 =
  cpu.mmu.read8(cpu.pc + 1)

proc i8(cpu: var CPU): int8 =
  cast[int8](cpu.mmu.read8(cpu.pc + 1))

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
  cpu.regs.flags_H = (cpu.regs["A"] and 0x0F) < (val and 0x0F)
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

proc ADC(cpu: var CPU, val: uint8) =
  var carry: uint8 = if cpu.regs.flags_C: 1 else: 0
  cpu.regs.flags_C = (cpu.regs["A"].int32 + val.int32 + carry.int32) > 0xFF
  cpu.regs.flags_H = (cpu.regs["A"] and 0x0F) + (val and 0x0F) + carry > 0x0F
  cpu.regs.flags_N = false
  cpu.regs["A"] = cpu.regs["A"] + val + carry
  cpu.regs.flags_Z = cpu.regs["A"] == 0

proc executeOp(cpu: var CPU, opcode: Opcode) =
  # debugOp(opcode, cpu)
  var skipInc = false
  case opcode.mnemonic:
    of "NOP":
      discard
    of "JP":
      # NO condition jump
      if opcode.operandOne != "" and opcode.operandTwo == "":
        var src: uint16
        case opcode.operandOne:
          of "A16":
            src = cpu.a16
          of "HL":
            src = cpu.regs.HL
          else:
            debugUnknownOperand(opcode, 1)
        skipInc = true
        cpu.pc = src
      else:
        if opcode.operandTwo == "A16":
          case opcode.operandOne:
            # of "Z":
            #   if cpu.regs.flags_Z:
            #     cpu.pc = (cpu.pc.int32 + cpu.i8.int32).uint16
            of "NZ":
              if not cpu.regs.flags_Z:
                cpu.pc = cpu.a16
            # of "C":
            #   if cpu.regs.flags_C:
            #     cpu.pc = (cpu.pc.int32 + cpu.i8.int32).uint16
            # of "NC":
            #   if not cpu.regs.flags_C:
            #     cpu.pc = (cpu.pc.int32 + cpu.i8.int32).uint16
            else:
              debugUnknownOperand(opcode, 1)
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
        of "(A16)":
          src = cpu.mmu.read8(cpu.a16)
        of "(BC)":
          src = cpu.mmu.read8(cpu.regs.BC)
        of "(DE)":
          src = cpu.mmu.read8(cpu.regs.DE)
        of "(HL)":
          src = cpu.mmu.read8(cpu.regs.HL)
        of "(HL+)":
          src = cpu.mmu.read8(cpu.regs.HL)
          cpu.regs.HL.inc()
        else:
          echo "Unknown Operand 2: ", opcode.operandTwo, " opCode:", toHex(opcode.opcode)
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
        of "DE":
          cpu.regs.DE = src
        of "(DE)":
          cpu.mmu.write8(cpu.regs.DE, src.uint8)
        of "HL":
          cpu.regs.HL = src
        of "(HL)":
          cpu.mmu.write8(cpu.regs.HL, src.uint8)
        of "(HL-)":
          cpu.mmu.write8(cpu.regs.HL, src.uint8)
          cpu.regs.HL.dec()
        of "(HL+)":
          cpu.mmu.write8(cpu.regs.HL, src.uint8)
          cpu.regs.HL.inc()
        else:
          echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
          quit()
    of "LDH":
      var src: uint16
      case opcode.operandTwo:
        of "A", "B", "C", "D", "E", "H", "L":
          src = cpu.regs[opcode.operandTwo]
        of "(A8)":
          src = cpu.d8.uint16
        else:
          echo "Unknown Operand 2: ", opcode.operandTwo, " opCode:", toHex(opcode.opcode)
          quit()
      
      case opcode.operandOne:
        of "(A8)":
          cpu.mmu.write8(0xFF00 + cpu.d8.uint16, src.uint8)
        of "A", "B", "C", "D", "E", "H", "L":
          # TODO : This is not right, why pc + 3 and not the imediate src ? It seems like we're incrementing PC too late
          # echo "SRC ", src
          # echo "ADDR ", 0xFF00'u16 + src
          # echo "MEM ", cpu.mmu.read8(0xFF00'u16 + src)
          # echo "MEM16 ", cpu.mmu.read16(0xFF00'u16 + src)
          # echo "MEM PC", cpu.mmu.read8(cpu.pc + 2)
          # echo "MEM PC+1", cpu.mmu.read8(cpu.pc + 3)
          cpu.regs[opcode.operandOne] = cpu.mmu.read8(cpu.pc + 3)
        else:
          echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
          quit()
    of "CALL":
      case opcode.operandOne:
        of "A16":
          skipInc = true
          cpu.push(cpu.pc + 3)
          cpu.pc = cpu.a16 
        of "NZ":
          if opcode.operandTwo != "A16":
            raise newException(ValueError, toHex(opcode.opcode))
          else:
            if not cpu.regs.flags_Z:
              skipInc = true
              cpu.push(cpu.pc + 3)
              cpu.pc = cpu.a16 
        else:
          echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
          quit()
    of "JR":
      # Not sure we need to increment here or not
      # skipInc = true

      # NO condition jump
      if opcode.operandOne != "" and opcode.operandTwo == "":
        case opcode.operandOne:
          of "R8":
            cpu.pc = (cpu.pc.int32 + cpu.i8.int32).uint16
          else:
            echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
            quit()
      # Jump with condition
      else:
        if opcode.operandTwo == "R8":
          case opcode.operandOne:
            of "Z":
              if cpu.regs.flags_Z:
                cpu.pc = (cpu.pc.int32 + cpu.i8.int32).uint16
            of "NZ":
              if not cpu.regs.flags_Z:
                cpu.pc = (cpu.pc.int32 + cpu.i8.int32).uint16
            of "C":
              if cpu.regs.flags_C:
                cpu.pc = (cpu.pc.int32 + cpu.i8.int32).uint16
            of "NC":
              if not cpu.regs.flags_C:
                cpu.pc = (cpu.pc.int32 + cpu.i8.int32).uint16
            else:
              echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
              quit()
        else:
          echo "Unknown Operand 2: ", opcode.operandTwo, " opCode:", toHex(opcode.opcode)
          quit()
    of "RET":
      if opcode.operandOne == "" and opcode.operandTwo == "":
        skipInc = true
        cpu.pc = cpu.pop()
      else:
        case opcode.operandOne:
          of "Z":
            if cpu.regs.flags_Z:
              skipInc = true
              cpu.pc = cpu.pop()
          of "NZ":
            if not cpu.regs.flags_Z:
              skipInc = true
              cpu.pc = cpu.pop()
          of "NC":
            if not cpu.regs.flags_C:
              skipInc = true
              cpu.pc = cpu.pop()
          else:
            echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
            quit()
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
          echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
          quit()
    of "POP":
      case opcode.operandOne:
        of "AF":
          cpu.regs.AF = cpu.pop() and 0xFFF0
        of "BC":
          cpu.regs.BC = cpu.pop()
        of "DE":
          cpu.regs.DE = cpu.pop()
        of "HL":
          cpu.regs.HL = cpu.pop()
        else:
          echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
          quit()
    of "INC":
      case opcode.operandOne:
        of "A", "B", "C", "D", "E", "H", "L":
          var src = cpu.regs[opcode.operandOne]
          cpu.regs.flags_H = (src and 0x0F) == 0x0F
          src.inc()
          cpu.regs.flags_Z = src == 0
          cpu.regs.flags_N = false
          cpu.regs[opcode.operandOne] = src
        of "BC":
          cpu.regs.BC.inc()
        of "DE":
          cpu.regs.DE.inc()
        of "HL":
          cpu.regs.HL.inc()
        else:
          echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
          quit()
    of "OR":
      var src: uint8
      case opcode.operandOne:
        of "A", "B", "C", "D", "E", "H", "L":
          src = cpu.regs[opcode.operandOne]
          cpu.OR(src)
        of "(HL)":
          cpu.OR(cpu.mmu.read8(cpu.regs.HL))
        else:
          debugUnknownOperand(opcode, 1)
    of "CP":
      var src: uint8
      case opcode.operandOne:
        of "A", "B", "C", "D", "E", "H", "L":
          src = cpu.regs[opcode.operandOne]
        of "D8":
          src = cpu.d8
        else:
          debugUnknownOperand(opcode, 1)
      cpu.CP(src)
    of "DEC":
      case opcode.operandOne:
        of "A", "B", "C", "D", "E", "H", "L":
          var src = cpu.regs[opcode.operandOne]
          src.dec()
          cpu.regs.flags_H = (src and 0x0F) == 0x0F
          cpu.regs.flags_Z = src == 0
          cpu.regs.flags_N = true
          cpu.regs[opcode.operandOne] = src
        of "(HL)":
          var src = cpu.mmu.read8(cpu.regs.HL)
          src.dec()
          cpu.regs.flags_H = (src and 0x0F) == 0x0F
          cpu.regs.flags_Z = src == 0
          cpu.regs.flags_N = true
          cpu.mmu.write8(cpu.regs.HL, src)
        else:
          debugUnknownOperand(opcode, 1)
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
            echo "Unknown Operand 2: ", opcode.operandTwo, " opCode:", toHex(opcode.opcode)
        cpu.regs.flags_H = ((cpu.regs.HL and 0x0FFF) + (src and 0x0FFF) > 0x0FFF)
        cpu.regs.flags_C = (cpu.regs.HL.int32 + src.int32 > 0xFFFF)
        cpu.regs.HL += src
        cpu.regs.flags_N = false
      elif opcode.operandOne != "A":
          echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
          quit()
      else:
        var src: uint8
        case opcode.operandTwo:
          of "D8":
            src = cpu.d8
            cpu.ADD(src)
          else:
            echo "Unknown Operand 2: ", opcode.operandTwo, " opCode:", toHex(opcode.opcode)
            quit()
    of "SUB":
      var src: uint8
      case opcode.operandOne:
        of "D8":
          src = cpu.d8
          cpu.SUB(src)
        else:
          echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
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
        of "A", "B", "C", "D", "E", "H", "L":
          src = cpu.regs[opcode.operandOne]
          cpu.XOR(src)
        else:
          echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
          quit()
    of "AND":
      var src: uint8
      case opcode.operandOne:
        of "D8":
          src = cpu.d8
          cpu.AND(src)
        else:
          echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
          quit()
    of "ADC":
      case opcode.operandOne:
        of "A":
          case opcode.operandTwo:
            of "D8":
              cpu.ADC(cpu.d8)
            else:
              echo "Unknown Operand 2: ", opcode.operandTwo, " opCode:", toHex(opcode.opcode)
              quit()
        of "B", "C", "D", "E", "H", "L":
          cpu.ADC(cpu.regs[opcode.operandOne])
        else:
          echo "Unknown Operand 1: ", opcode.operandOne, " opCode:", toHex(opcode.opcode)
          quit()
    of "HALT":
      cpu.halt = true
    of "RLCA", "RRA":
      if opcode.mnemonic == "RLCA":
        cpu.regs.flags_C = (cpu.regs["A"] and (1 shl 7)) != 0
        cpu.regs["A"] = (cpu.regs["A"] shl 1) or (cpu.regs["A"] shr 7)
      elif opcode.mnemonic == "RRA":
        let carry: uint8 = if cpu.regs.flags_C: 1 else: 0
        cpu.regs.flags_C = (cpu.regs["A"] and (1 shl 0)) != 0
        cpu.regs["A"] = (cpu.regs["A"] shr 1) or (carry shl 7)
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
      # debugOp(prefixOpcode, cpu)
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
      cpu.pc.inc(prefixOpcode.len - 1)
    else:
      raise newException(ValueError, "Unknown mnemonic: " & opcode.mnemonic)

  if not skipInc:
    cpu.pc.inc(opcode.len)

proc currentOpcode*(cpu: CPU): Opcode = 
  opcs[cpu.mmu.read8(cpu.pc)]

proc update*(cpu: var CPU): int =
  var opcode = cpu.currentOpcode()
  cpu.executeOp(opcode)
  # TODO: We need to make sure we handle all flags here
  # if opcode.z != '-': echo "Should have assigned Z flag here"
  # if opcode.h != '-': echo "Should have assigned H flag here"
  # if opcode.n != '-': echo "Should have assigned N flag here"
  # if opcode.c != '-': echo "Should have assigned C flag here"
  
  # FOR DEBUG:
  cpu.mmu.debugSerialPort()

  return opcode.cycles

proc buildBlarggOutput*(cpu: var CPU): string =
    return "A: $1 F: $2 B: $3 C: $4 D: $5 E: $6 H: $7 L: $8 SP: $9 PC: 00:$10 ($11 $12 $13 $14)" % [
      toHex(cpu.regs["A"]), 
      toHex(cpu.regs.F),
      toHex(cpu.regs["B"]), 
      toHex(cpu.regs["C"]), 
      toHex(cpu.regs["D"]), 
      toHex(cpu.regs["E"]), 
      toHex(cpu.regs["H"]), 
      toHex(cpu.regs["L"]), 
      toHex(cpu.sp),
      toHex(cpu.pc),
      toHex(cpu.mmu.read8(cpu.pc)),
      toHex(cpu.mmu.read8(cpu.pc + 1)),
      toHex(cpu.mmu.read8(cpu.pc + 2)),
      toHex(cpu.mmu.read8(cpu.pc + 3))
    ]