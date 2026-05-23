const BELL_EVENTS = new Set([
  "permission.asked",
  "session.idle",
  "session.error",
])

export const ZedBellPlugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (!event || !BELL_EVENTS.has(event.type)) {
        return
      }

      await $`bash -lc '$HOME/.local/bin/zed-bell --raw'`
    },
  }
}
