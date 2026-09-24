import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['title']

  connect() {
    this.reset()
  }

  toggle(event) {
    if (window.matchMedia('(min-width: 78rem)').matches) return

    const title = event.currentTarget
    const item = title.closest('.b4um-sitemap__item')

    if (!item) return

    const isOpen = title.getAttribute('aria-expanded') === 'true'

    title.setAttribute('aria-expanded', String(!isOpen))
    item.classList.toggle('is-open', !isOpen)
  }

  reset() {
    const isDesktop = window.matchMedia('(min-width: 78rem)').matches

    this.titleTargets.forEach((title) => {
      title.setAttribute('aria-expanded', String(isDesktop))
    })

    this.element.querySelectorAll('.b4um-sitemap__item.is-open').forEach((item) => {
      item.classList.remove('is-open')
    })
  }
}
