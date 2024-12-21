import chip8
import raylib
import os, times

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
  CPU_SPEED = 500
  FPS = 60
let
  cpuCycleTime = 1.0 / CPU_SPEED
  timerCycleTime = 1.0 / FPS
var
  lastCPUTime = epochTime()
  lastTimerTime = epochTime()

when isMainModule:
  var emulator = initChip8()
  emulator.loadROM(paramStr(1))

  initAudioDevice()
  var beep = loadSound("./assets/beep.mp3")

  initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "CHIP-8 emulator")
  setTargetFPS(FPS)

  while not windowShouldClose():
    let currentTime = epochTime()

    while (currentTime - lastCPUTime) >= cpuCycleTime:
      emulator.cycle()
      lastCPUTime += cpuCycleTime

    if (currentTime - lastTimerTime) >= timerCycleTime:
      if emulator.delayTimer > 0: emulator.delayTimer.dec()
      if emulator.soundTimer > 0:
        playSound(beep)
        emulator.soundTimer.dec()
      lastTimerTime += timerCycleTime

    for idx, k in KEYMAP:
      if isKeyDown(k):
        emulator.keypad[idx] = true
      elif isKeyUp(k):
        emulator.keypad[idx] = false

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