import chip8
import raylib
import os

const
  DISPLAY_WIDTH = 64
  DISPLAY_HEIGHT = 32
  SCALE_FACTOR = 30
  SCREEN_WIDTH = DISPLAY_WIDTH * SCALE_FACTOR
  SCREEN_HEIGHT = DISPLAY_HEIGHT * SCALE_FACTOR
  KEYMAP = [
    X,
    One,
    Two,
    Three,
    Q,
    W,
    E,
    A,
    S,
    D,
    Z,
    C,
    Four,
    R,
    F,
    V,
  ]

when isMainModule:
  var emulator = initChip8()
  emulator.loadROM(paramStr(1))
  initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Chip8 emulator")
  setTargetFPS(60)

  while not windowShouldClose():
    for idx, k in KEYMAP:
      if isKeyDown(k):
        emulator.keypad[idx] = true
      elif isKeyUp(k):
        emulator.keypad[idx] = false
    emulator.cycle()

    if emulator.drawFlag:
      beginDrawing()
      clearBackground(Black)
      drawFPS(0, 0)
      for idx, pixel in emulator.display:
        var x = int32(idx mod 64)
        var y = int32(idx div 64)
        if pixel:
          drawRectangle(x * SCALE_FACTOR, y * SCALE_FACTOR, SCALE_FACTOR, SCALE_FACTOR, RayWhite)
      endDrawing()
  closeWindow()