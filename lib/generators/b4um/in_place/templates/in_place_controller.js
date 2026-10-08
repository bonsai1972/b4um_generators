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
      this.rememberFormState()

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

  rememberFormState() {
    this.initialFormStates = new WeakMap()

    this.element.querySelectorAll('form').forEach((form) => {
      this.initialFormStates.set(form, new URLSearchParams(new FormData(form)).toString())
    })
  }

  formChanged(form) {
    if (!this.initialFormStates?.has(form)) return true

    const initialState = this.initialFormStates.get(form)
    const currentState = new URLSearchParams(new FormData(form)).toString()

    return initialState !== currentState
  }

  save(event) {
    const form = event?.target?.closest('form') || this.element.querySelector('form')

    if (!form) return

    const fileInput = event?.target instanceof HTMLInputElement && event.target.type === 'file' ? event.target : null

    if (fileInput?.files?.length) {
      form.requestSubmit()
      return
    }

    if (!this.formChanged(form)) {
      this.cancel()
      return
    }

    form.requestSubmit()
  }

  cancel() {
    if (!this.hasCancelUrlValue) return

    const frame = this.element.closest('turbo-frame')
    if (!frame) return

    frame.src = this.cancelUrlValue
  }
}
