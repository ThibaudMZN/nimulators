import mmu, cpu

type
  GameBoy* = object
    mem: Memory
    cpu: CPU

proc initGameBoy*(): GameBoy =
  var mem = initMemory()
  GameBoy(
    mem: mem
  )

proc loadROM*(gb: var GameBoy, romPath: string) =
  gb.mem.loadROM(romPath)
  gb.cpu = initCPU(gb.mem)

proc update*(gb: var Gameboy): int =
  return gb.cpu.update()