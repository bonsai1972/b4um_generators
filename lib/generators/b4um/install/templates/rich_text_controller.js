import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.prepareLinks()
  }

  prepareLinks() {
    const links = this.element.querySelectorAll('a[href]')

    links.forEach((link) => {
      link.setAttribute('target', '_blank')

      const rel = new Set((link.getAttribute('rel') || '').split(/\s+/).filter(Boolean))

      rel.add('noopener')
      rel.add('noreferrer')

      link.setAttribute('rel', Array.from(rel).join(' '))
    })
  }
}
