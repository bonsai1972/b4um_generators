import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['title', 'list']

  connect() {
    this.reset()
  }

  toggle(event) {
    if (window.matchMedia('(min-width: 78rem)').matches) return

    const title = event.currentTarget
    const item = title.closest('.b4um-sitemap__item')
    const list = item?.querySelector('.b4um-sitemap__list')

    if (!list) return

    const isOpen = title.getAttribute('aria-expanded') === 'true'

    title.setAttribute('aria-expanded', String(!isOpen))
    list.hidden = isOpen
    item.classList.toggle('is-open', !isOpen)
  }

  reset() {
    const isDesktop = window.matchMedia('(min-width: 78rem)').matches

    this.titleTargets.forEach((title) => {
      title.setAttribute('aria-expanded', String(isDesktop))
    })

    this.listTargets.forEach((list) => {
      list.hidden = !isDesktop
    })

    this.element.querySelectorAll('.b4um-sitemap__item.is-open').forEach((item) => item.classList.remove('is-open'))
  }
}
