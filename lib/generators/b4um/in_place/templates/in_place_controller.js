import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    url: String,
    outsideSave: { type: Boolean, default: true },
    cancelUrl: String
  }

  connect() {
    this.handlePointerDown = this.handlePointerDown.bind(this)
    this.handleKeyDown = this.handleKeyDown.bind(this)

    if (this.element.querySelector('form')) {
      document.addEventListener('pointerdown', this.handlePointerDown)
      document.addEventListener('keydown', this.handleKeyDown)
      this.focusEditor()
    }
  }

  disconnect() {
    document.removeEventListener('pointerdown', this.handlePointerDown)
    document.removeEventListener('keydown', this.handleKeyDown)
  }

  edit(event) {
    if (event?.type === 'keydown') {
      event.preventDefault()
    }

    if (!this.hasUrlValue) return

    const frame = this.element.closest('turbo-frame')
    if (!frame) return

    frame.src = this.urlValue
  }

  handlePointerDown(event) {
    if (this.element.contains(event.target)) return

    if (this.outsideSaveValue) {
      this.save()
    } else {
      this.cancel()
    }
  }

  handleKeyDown(event) {
    if (event.key !== 'Escape') return

    event.preventDefault()
    this.cancel()
  }

  focusEditor() {
    const control = this.element.querySelector(
      'input:not([type="hidden"]):not([type="file"]), select, textarea, trix-editor'
    )

    if (!control) return

    requestAnimationFrame(() => {
      control.focus()
    })
  }

  save() {
    const form = this.element.querySelector('form')
    if (!form) return

    form.requestSubmit()
  }

  cancel() {
    if (!this.hasCancelUrlValue) return

    const frame = this.element.closest('turbo-frame')
    if (!frame) return

    frame.src = this.cancelUrlValue
  }
}
