import raylib
import gameboy
import os

const
  DISPLAY_WIDTH = 160
  DISPLAY_HEIGHT = 144
  SCALE_FACTOR = 10
  SCREEN_WIDTH = DISPLAY_WIDTH * SCALE_FACTOR
  SCREEN_HEIGHT = DISPLAY_HEIGHT * SCALE_FACTOR
  FPS = 60
  CYCLES_PER_FRAME = int(4_194_304 / FPS)

when isMainModule:
  var emulator = initGameBoy()
  emulator.loadROM(paramStr(1))

  initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "GameBoy emulator")
  setTargetFPS(FPS)

  while not windowShouldClose():
    var cyclesThisUpdate = 0
    while cyclesThisUpdate < CYCLES_PER_FRAME:
        var nbCycles = emulator.update()
        cyclesThisUpdate.inc(nbCycles)

    beginDrawing()
    clearBackground(Black)
    endDrawing()
  closeWindow()