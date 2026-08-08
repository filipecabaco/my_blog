// Reports how far down the article this reader is, as a 0-1 fraction.
const Presence = {
  mounted() {
    // Your own position lives on <html>, not on the track. LiveView re-renders the
    // track's style attribute and would wipe anything written there.
    this.root = document.documentElement

    let dirty = false
    this.onScroll = () => {
      dirty = true
    }
    addEventListener('scroll', this.onScroll, { passive: true })

    this.timer = setInterval(() => {
      if (!dirty) return
      dirty = false

      const max = document.documentElement.scrollHeight - innerHeight
      const at = max > 0 ? Math.min(1, Math.max(0, scrollY / max)) : 0

      this.root.style.setProperty('--reading-at', at.toFixed(4))

      this.pushEvent('scroll_position', {
        position: at,
        title: this.el.dataset.title,
      })
    }, 100)

    this.handleEvent('update_tag', ({ id, position }) => {
      const lamp = document.getElementById(id)
      if (lamp) lamp.style.setProperty('--at', position)
    })
  },

  destroyed() {
    removeEventListener('scroll', this.onScroll)
    clearInterval(this.timer)
    this.root.style.removeProperty('--reading-at')
  },
}

export default Presence
