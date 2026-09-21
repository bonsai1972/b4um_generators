import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    nextUrl: String,
    container: String
  }

  connect() {
    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        this.loadMore()
      }
    })

    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
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
        this.observer.disconnect()
        this.element.remove()
      }
    } finally {
      this.loading = false
    }
  }
}
