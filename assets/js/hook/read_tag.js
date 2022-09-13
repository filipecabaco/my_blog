const ReadTag = {
  mounted() {
    let scrolling = false
    addEventListener('scroll', () => {
      scrolling = true
    })

    this.handleEvent('update_tag', (event) => {
      let tag = document.getElementById(event.id)
      if (tag) {
        tag.style.top = `${event.position}px`
      }
    })

    setInterval(() => {
      if (scrolling) {
        scrolling = false
        this.pushEvent('scroll_position', {
          position: window.scrollY,
          title: this.el.title,
        })
      }
    }, 50)
  },
}

export default ReadTag
