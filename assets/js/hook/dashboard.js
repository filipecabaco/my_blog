import vegaEmbed from 'vega-embed'
const Dashboard = {
  mounted() {
    this.handleEvent(`draw`, ({ spec }) => {
      vegaEmbed(this.el, spec, {
        actions: false,
        renderer: 'svg',
        tooltip: { theme: 'dark' }
      })
        .then((result) => {
          this.view = result.view
        })
        .catch((error) => console.error(error))
    })
  },
  destroyed() {
    if (this.view) {
      this.view.finalize()
    }
  },
}

export default Dashboard
