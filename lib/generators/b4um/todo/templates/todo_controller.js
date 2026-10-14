import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="b4um-todo"
export default class extends Controller {
  static targets = ['input', 'submit']

  connect() {
    this.updateSubmitState()
  }

  resetAfterSuccess(event) {
    if (!event.detail.success) return

    const contentType = event.detail.fetchResponse?.contentType || ''

    if (!contentType.includes('turbo-stream')) return

    this.reset()
  }

  updateSubmitState() {
    if (!this.hasInputTarget || !this.hasSubmitTarget) return

    const value = this.inputTarget.value.trim()

    this.submitTarget.disabled = value.length === 0
  }

  reset() {
    if (!this.hasInputTarget) return

    this.inputTarget.value = ''
    this.updateSubmitState()
  }
}
