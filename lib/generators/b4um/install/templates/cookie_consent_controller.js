import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'b4um-cookie-consent'

export default class extends Controller {
  static targets = ['banner']

  connect() {
    const consent = window.localStorage.getItem(STORAGE_KEY)

    if (consent === null) {
      this.bannerTarget.hidden = false
      return
    }

    if (consent === 'accepted') {
      window.dispatchEvent(new CustomEvent('b4um:cookie-consent-accepted'))
    }

    if (consent === 'rejected') {
      window.dispatchEvent(new CustomEvent('b4um:cookie-consent-rejected'))
    }
  }

  accept() {
    window.localStorage.setItem(STORAGE_KEY, 'accepted')

    window.dispatchEvent(new CustomEvent('b4um:cookie-consent-accepted'))

    this.hide()
  }

  reject() {
    window.localStorage.setItem(STORAGE_KEY, 'rejected')

    window.dispatchEvent(new CustomEvent('b4um:cookie-consent-rejected'))

    this.hide()
  }

  hide() {
    this.bannerTarget.hidden = true
  }
}
