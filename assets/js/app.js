// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
import '../css/app.css'
import hljs from 'highlight.js/lib/core'
import elixir from 'highlight.js/lib/languages/elixir'
import javascript from 'highlight.js/lib/languages/javascript'
import bash from 'highlight.js/lib/languages/bash'
import sql from 'highlight.js/lib/languages/sql'
import json from 'highlight.js/lib/languages/json'
import xml from 'highlight.js/lib/languages/xml'
import 'highlight.js/styles/github-dark.css'

hljs.registerLanguage('elixir', elixir)
hljs.registerLanguage('javascript', javascript)
hljs.registerLanguage('bash', bash)
hljs.registerLanguage('sql', sql)
hljs.registerLanguage('json', json)
hljs.registerLanguage('xml', xml)
hljs.registerLanguage('html', xml)

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import 'phoenix_html'
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from 'phoenix'
import { LiveSocket } from 'phoenix_live_view'
import Dashboard from './hook/dashboard'
import ReadTag from './hook/read_tag'
import { hooks as colocatedHooks } from 'phoenix-colocated/blog'
import topbar from '../vendor/topbar'


let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute('content')

let params = { _csrf_token: csrfToken }
let hooks = { Dashboard, ReadTag, ...colocatedHooks }
let liveSocket = new LiveSocket('/live', Socket, { params, hooks })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: '#29d' }, shadowColor: 'rgba(0, 0, 0, .3)' })
window.addEventListener('phx:page-loading-start', (info) => topbar.show())
window.addEventListener('phx:page-loading-stop', (info) => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()
setTimeout(() => liveSocket.main.channel.push('reader', { csrfToken }), 10000)
window.liveSocket = liveSocket

// Syntax highlighting
function highlightAll() {
  document.querySelectorAll('pre code').forEach((el) => {
    if (!el.dataset.highlighted) hljs.highlightElement(el)
  })
}
window.addEventListener('phx:page-loading-stop', highlightAll)
highlightAll()
