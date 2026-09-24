import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'b4um-cookie-consent'
const OPEN_EVENT = 'b4um:cookie-consent-open'

export default class extends Controller {
  static targets = ['banner']

  connect() {
    this.open = this.open.bind(this)

    window.addEventListener(OPEN_EVENT, this.open)
    document.addEventListener('click', this.handleSettingsClick)

    const consent = window.localStorage.getItem(STORAGE_KEY)

    if (consent === null) {
      this.show()
      return
    }

    this.dispatchConsentEvent(consent)
  }

  disconnect() {
    window.removeEventListener(OPEN_EVENT, this.open)
    document.removeEventListener('click', this.handleSettingsClick)
  }

  accept() {
    this.storeConsent('accepted')
    this.hide()
  }

  reject() {
    this.storeConsent('rejected')
    this.hide()
  }

  handleSettingsClick(event) {
    const trigger = event.target.closest('[data-b4um-cookie-consent-open]')

    if (!trigger) return

    event.preventDefault()

    window.dispatchEvent(new CustomEvent(OPEN_EVENT))
  }

  open() {
    this.show()
  }

  show() {
    this.bannerTarget.hidden = false
  }

  hide() {
    this.bannerTarget.hidden = true
  }

  storeConsent(consent) {
    window.localStorage.setItem(STORAGE_KEY, consent)
    this.dispatchConsentEvent(consent)
  }

  dispatchConsentEvent(consent) {
    if (consent === 'accepted') {
      window.dispatchEvent(new CustomEvent('b4um:cookie-consent-accepted'))
    }

    if (consent === 'rejected') {
      window.dispatchEvent(new CustomEvent('b4um:cookie-consent-rejected'))
    }
  }
}
