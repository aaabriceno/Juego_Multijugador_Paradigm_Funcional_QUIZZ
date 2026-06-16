// Sonidos sinteticos via WebAudio. Sin archivos: tonos generados en el
// navegador. El AudioContext se crea perezosamente y se reanuda tras el primer
// gesto del usuario (los navegadores bloquean audio sin interaccion).

let ctx = null

function audioCtx() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext
    if (!AC) return null
    ctx = new AC()
  }
  if (ctx.state === "suspended") ctx.resume()
  return ctx
}

// Desbloquea el audio en el primer gesto. Llamar desde un handler de click.
export function unlockAudio() {
  audioCtx()
}

// Toca un tono simple con envolvente para que no suene a "click" duro.
function tone(freq, { duration = 0.18, type = "sine", gain = 0.2, delay = 0 } = {}) {
  const ac = audioCtx()
  if (!ac) return

  const start = ac.currentTime + delay
  const osc = ac.createOscillator()
  const env = ac.createGain()

  osc.type = type
  osc.frequency.setValueAtTime(freq, start)

  env.gain.setValueAtTime(0, start)
  env.gain.linearRampToValueAtTime(gain, start + 0.01)
  env.gain.exponentialRampToValueAtTime(0.0001, start + duration)

  osc.connect(env)
  env.connect(ac.destination)
  osc.start(start)
  osc.stop(start + duration + 0.02)
}

// Acierto: dos notas ascendentes alegres.
export function playDing() {
  tone(660, { type: "triangle", gain: 0.22 })
  tone(990, { type: "triangle", gain: 0.22, delay: 0.1 })
}

// Error: zumbido grave y corto.
export function playBuzz() {
  tone(160, { type: "sawtooth", gain: 0.18, duration: 0.3 })
}

// Tic de cuenta regresiva (ultimos segundos).
export function playTick() {
  tone(880, { type: "square", gain: 0.08, duration: 0.06 })
}

// Fanfarria final corta para la pantalla de ganador.
export function playFanfare() {
  ;[523, 659, 784, 1047].forEach((f, i) =>
    tone(f, { type: "triangle", gain: 0.2, duration: 0.25, delay: i * 0.12 })
  )
}

export function playSound(name) {
  switch (name) {
    case "ding":
      return playDing()
    case "buzz":
      return playBuzz()
    case "tick":
      return playTick()
    case "fanfare":
      return playFanfare()
  }
}
