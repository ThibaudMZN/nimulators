import unittest, strutils, deques
import ../src/cpu
import ../src/mmu
import ../src/opcodes


suite "The CPU, running Blargg's tests":
  test "can pass Test 01":
    var mem = initMemory()
    mem.loadROM("./gb-test-roms/cpu_instrs/individual/01-special.gb")
    var cpu = initCPU(mem)

    let f = open("./tests/BlarggExpectedOutput/Blargg1LYStubbed/EpicLog.txt")
    defer: f.close()

    let totalLines = 1_258_895
    var q = toDeque[Opcode]([])
    for i in 0..totalLines:
        q.addFirst(cpu.currentOpcode())
        if q.len > 2:
            discard q.popLast()
        let actual = cpu.buildBlarggOutput()
        let expected = f.readLine()
        if actual != expected:
            echo "Failed OpCode: 0x$1" % [toHex(q[1].opcode)]
            echo q[1]
            echo expected, "\t expected"
            echo actual, "\t actual"
            echo "failed on line ", i + 1
            quit(-1)
        discard cpu.update()