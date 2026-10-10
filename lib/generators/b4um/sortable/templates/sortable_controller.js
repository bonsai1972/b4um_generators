import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    updateUrl: String
  }

  connect() {
    this.draggedItem = null
    this.draggedFromPosition = null
  }

  dragStart(event) {
    const item = event.currentTarget.closest('[data-sortable-id]')

    if (!item) return

    this.draggedItem = item
    this.draggedFromPosition = this.positionFor(item)

    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', item.dataset.sortableId)

    item.classList.add('b4um-sortable__item--dragging')
  }

  dragEnd() {
    if (this.draggedItem) {
      this.draggedItem.classList.remove('b4um-sortable__item--dragging')
    }

    this.draggedItem = null
    this.draggedFromPosition = null
  }

  dragOver(event) {
    event.preventDefault()

    if (!this.draggedItem) return

    const target = event.currentTarget

    if (target === this.draggedItem) return

    const bounds = target.getBoundingClientRect()
    const insertAfter = event.clientY > bounds.top + bounds.height / 2

    if (insertAfter) {
      target.after(this.draggedItem)
    } else {
      target.before(this.draggedItem)
    }
  }

  drop(event) {
    event.preventDefault()

    if (!this.draggedItem) return

    const item = this.draggedItem
    const position = this.positionAfterDrop(item)

    if (!position) {
      window.location.reload()
      return
    }

    this.persist(item.dataset.sortableId, position)
  }

  positionKeydown(event) {
    if (event.key !== 'Enter') return

    event.preventDefault()
    event.currentTarget.blur()
  }

  positionChanged(event) {
    const input = event.currentTarget
    const item = input.closest('[data-sortable-id]')

    if (!item) return

    const position = Number.parseInt(input.value, 10)

    if (Number.isNaN(position) || position < 1) {
      window.location.reload()
      return
    }

    this.persist(item.dataset.sortableId, position)
  }

  positionFor(item) {
    const input = item.querySelector('.b4um-sortable__position')

    if (!input) return null

    const position = Number.parseInt(input.value, 10)

    return Number.isNaN(position) ? null : position
  }

  positionAfterDrop(item) {
    const previousItem = item.previousElementSibling
    const nextItem = item.nextElementSibling

    if (previousItem?.matches('[data-sortable-id]')) {
      const previousPosition = this.positionFor(previousItem)

      if (previousPosition) {
        if (this.draggedFromPosition && this.draggedFromPosition < previousPosition) {
          return previousPosition
        }

        return previousPosition + 1
      }
    }

    if (nextItem?.matches('[data-sortable-id]')) {
      const nextPosition = this.positionFor(nextItem)

      if (nextPosition) {
        if (this.draggedFromPosition && this.draggedFromPosition > nextPosition) {
          return nextPosition
        }

        return Math.max(1, nextPosition - 1)
      }
    }

    return this.draggedFromPosition
  }

  async persist(id, position) {
    if (!this.hasUpdateUrlValue || !this.updateUrlValue) return

    try {
      const response = await fetch(this.updateUrlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          'X-CSRF-Token': this.csrfToken()
        },
        body: JSON.stringify({
          id,
          position
        })
      })

      if (!response.ok) {
        throw new Error(`Sortable update failed: ${response.status}`)
      }

      window.location.reload()
    } catch (error) {
      console.error(error)
      window.location.reload()
    }
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ''
  }
}
