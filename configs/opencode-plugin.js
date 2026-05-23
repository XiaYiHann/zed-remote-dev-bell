export const ZedBellPlugin = async () => {
  return {
    event: async ({ event }) => {
      // Trigger terminal BEL when OpenCode needs attention or finishes.
      // We write to stderr because OpenCode's TUI captures stdout,
      // but stderr passes through to the host terminal (Zed).
      if (
        event.type === "permission.asked" ||
        event.type === "session.idle" ||
        event.type === "session.error"
      ) {
        process.stderr.write('\x07')
      }
    },
  }
}
