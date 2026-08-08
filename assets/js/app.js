import '../css/app.css'

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import 'phoenix_html'
import { Socket } from 'phoenix'
import { LiveSocket } from 'phoenix_live_view'
import Presence from './hook/read_tag'
import { hooks as colocatedHooks } from 'phoenix-colocated/blog'
import topbar from '../vendor/topbar'

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute('content')

let params = { _csrf_token: csrfToken }
let hooks = { Presence, ...colocatedHooks }
let liveSocket = new LiveSocket('/live', Socket, { params, hooks })

topbar.config({
  barColors: { 0: getComputedStyle(document.documentElement).getPropertyValue('--signal') || '#d4573a' },
  shadowColor: 'rgba(0, 0, 0, .2)',
})
window.addEventListener('phx:page-loading-start', () => topbar.show(200))
window.addEventListener('phx:page-loading-stop', () => topbar.hide())

liveSocket.connect()
setTimeout(() => liveSocket.main.channel.push('reader', { csrfToken }), 10000)
window.liveSocket = liveSocket

document.addEventListener('click', (event) => {
  const toggle = event.target.closest('[data-theme-toggle]')
  if (!toggle) return

  const next =
    document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark'
  document.documentElement.setAttribute('data-theme', next)
  try {
    localStorage.setItem('theme', next)
  } catch (e) {}
})

document.addEventListener('click', async (event) => {
  const button = event.target.closest('[data-copy]')
  if (!button) return

  const source = button.closest('.code')?.querySelector('.code__source')
  if (!source) return

  try {
    await navigator.clipboard.writeText(source.innerText)
    button.textContent = 'copied'
    button.dataset.state = 'done'
  } catch (e) {
    button.textContent = 'press ⌘C'
  }

  setTimeout(() => {
    button.textContent = 'copy'
    delete button.dataset.state
  }, 1600)
})
