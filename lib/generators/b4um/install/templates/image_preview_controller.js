import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'container', 'image']

  preview() {
    const file = this.inputTarget.files[0]

    if (!file) {
      this.clear()
      return
    }

    if (!file.type.startsWith('image/')) {
      this.clear()
      return
    }

    const reader = new FileReader()

    reader.onload = (event) => {
      this.imageTarget.src = event.target.result
      this.containerTarget.hidden = false
    }

    reader.readAsDataURL(file)
  }

  previewMultiple() {
    const files = Array.from(this.inputTarget.files)

    this.element.querySelectorAll('[data-image-preview-new]').forEach((image) => image.remove())

    if (files.length === 0) {
      return
    }

    files
      .filter((file) => file.type.startsWith('image/'))
      .forEach((file) => {
        const reader = new FileReader()

        reader.onload = (event) => {
          const image = document.createElement('img')

          image.src = event.target.result
          image.alt = file.name
          image.className = 'form-image-preview__image'
          image.dataset.imagePreviewNew = ''

          this.containerTarget.appendChild(image)
          this.containerTarget.hidden = false
        }

        reader.readAsDataURL(file)
      })
  }

  toggleRemoval(event) {
    const item = event.currentTarget

    const checkbox = item.querySelector('[data-image-preview-target="removeCheckbox"]')

    if (!checkbox) return

    checkbox.checked = !checkbox.checked

    item.classList.toggle('form-image-preview__item--removed', checkbox.checked)

    item.setAttribute('aria-pressed', checkbox.checked.toString())
  }

  toggleRemovalWithKeyboard(event) {
    if (event.key !== 'Enter' && event.key !== ' ') return

    event.preventDefault()

    this.toggleRemoval(event)
  }

  clear() {
    this.imageTarget.removeAttribute('src')
    this.containerTarget.hidden = true
  }
}
