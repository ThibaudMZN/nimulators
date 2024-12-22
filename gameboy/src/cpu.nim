import mmu
import registers
import strutils
import opcodes

type
  CPU* = object
    mmu*: Memory
    sp, pc: uint16      # Stack Pointer and Program Counter
    interrupts: bool
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
        of "(HL+)":
          src = cpu.regs.HL
          cpu.regs.HL.inc()
        else:
          echo "Unknown Operand 2: ", opcode.operandTwo
          quit()
      
      case opcode.operandOne:
        of "SP":
          cpu.sp = src
        of "(A16)":
          cpu.mmu.write8(cpu.a16, src.uint8)
        of "A":
          cpu.regs.A = src.uint8
        of "BC":
          cpu.regs.BC = src
        of "HL":
          cpu.regs.HL = src
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "LDH":
      var src: uint16
      case opcode.operandTwo:
        of "A":
          src = cpu.regs.A
        else:
          echo "Unknown Operand 2: ", opcode.operandTwo
          quit()
      
      case opcode.operandOne:
        of "(A8)":
          cpu.mmu.write8(0xFF00 + cpu.d8.uint16, src.uint8)
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
      case opcode.operandOne:
        of "R8":
          cpu.pc = (cpu.pc.int32 + cpu.d8.int32).uint16
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
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
        of "HL":
          cpu.push(cpu.regs.HL)
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "POP":
      case opcode.operandOne:
        of "AF":
          cpu.regs.AF = cpu.pop()
        of "HL":
          cpu.regs.HL = cpu.pop()
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    of "INC":
      case opcode.operandOne:
        of "BC":
          cpu.regs.BC.inc()
        of "HL":
          cpu.regs.HL.inc()
        else:
          echo "Unknown Operand 1: ", opcode.operandOne
          quit()
    else:
      echo "Unknown mnemonic: ", opcode.mnemonic
      quit()

  if not skipInc:
    cpu.pc.inc(opcode.len)

proc update*(cpu: var CPU): int =
  var opcode = opcs[cpu.mmu.read8(cpu.pc)]
  cpu.executeOp(opcode)
  # TODO: We need to handle flags here
  return opcode.cycles