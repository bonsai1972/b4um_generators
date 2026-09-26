import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    nextUrl: String,
    container: String
  }

  connect() {
    this.loading = false
    this.check = this.check.bind(this)

    window.addEventListener('scroll', this.check, { passive: true })
    window.addEventListener('resize', this.check)

    this.check()
  }

  disconnect() {
    window.removeEventListener('scroll', this.check)
    window.removeEventListener('resize', this.check)
  }

  check() {
    if (!this.hasNextUrlValue || this.loading) return

    const rect = this.element.getBoundingClientRect()

    if (rect.top <= window.innerHeight + 300) {
      this.loadMore()
    }
  }

  async loadMore() {
    if (!this.hasNextUrlValue || this.loading) return

    this.loading = true

    try {
      const response = await fetch(this.nextUrlValue, {
        headers: {
          Accept: 'text/html'
        }
      })

      if (!response.ok) return

      const html = await response.text()

      const nextDocument = new DOMParser().parseFromString(html, 'text/html')

      const nextGrid = nextDocument.querySelector(`#${this.containerValue}`)

      const currentGrid = document.getElementById(this.containerValue)

      if (!currentGrid || !nextGrid) return

      currentGrid.insertAdjacentHTML('beforeend', nextGrid.innerHTML)

      const nextSentinel = nextDocument.querySelector('[data-controller="infinite-scroll"]')

      if (nextSentinel?.dataset.infiniteScrollNextUrlValue) {
        this.nextUrlValue = nextSentinel.dataset.infiniteScrollNextUrlValue
      } else {
        this.element.remove()
      }
    } finally {
      this.loading = false
    }
  }
}
