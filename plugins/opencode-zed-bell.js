const BELL_EVENTS = new Set([
  "permission.asked",
  "session.idle",
  "session.error",
])

export const ZedBellPlugin = async () => {
  return {
    event: async ({ event }) => {
      if (!event || !BELL_EVENTS.has(event.type)) {
        return
      }
      // stderr bypasses OpenCode's TUI stdout capture and reaches the host terminal (Zed).
      process.stderr.write('\x07')
    },
  }
}
