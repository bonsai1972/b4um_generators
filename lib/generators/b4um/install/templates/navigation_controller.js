import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['menu', 'toggle']

  toggle() {
    const isOpen = this.element.classList.contains('navigation--open')

    if (isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.element.classList.add('navigation--open')
    this.toggleTarget.setAttribute('aria-expanded', 'true')
  }

  close() {
    this.element.classList.remove('navigation--open')
    this.toggleTarget.setAttribute('aria-expanded', 'false')
  }
}
