import vegaEmbed from 'vega-embed'
const Dashboard = {
  mounted() {
    this.handleEvent(`draw`, ({ spec }) => {
      console.log(this.el)
      console.log(spec)
      vegaEmbed(this.el, spec)
        .then((result) => result.view)
        .catch((error) => console.error(error))
    })
  },
  destroyed() {
    if (this.viewPromise) {
      this.viewPromise.then((view) => view.finalize())
    }
  },
}

export default Dashboard
