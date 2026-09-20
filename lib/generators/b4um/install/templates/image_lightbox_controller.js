import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['item', 'overlay', 'stage', 'image', 'caption', 'counter', 'previousButton', 'nextButton']

  connect() {
    this.currentIndex = 0
    this.isSliding = false

    this.isDragging = false
    this.dragStartX = 0
    this.dragCurrentX = 0
    this.dragPointerId = null
  }

  open(event) {
    event.preventDefault()

    const item = event.currentTarget
    const index = this.itemTargets.indexOf(item)

    if (index === -1) return

    this.currentIndex = index
    this.showCurrentImage()

    this.overlayTarget.hidden = false
    document.body.classList.add('image-lightbox-open')

    this.overlayTarget.focus()
  }

  close() {
    if (this.isSliding) return

    this.overlayTarget.hidden = true
    document.body.classList.remove('image-lightbox-open')
  }

  /*
  closeOnBackground(event) {
    if (event.target !== this.overlayTarget) return

    this.close()
  }*/

  closeOnBackground(event) {
    if (this.isDragging || this.isSliding) return

    const image = this.imageTarget
    const rect = image.getBoundingClientRect()

    const clickedOnImage =
      event.clientX >= rect.left &&
      event.clientX <= rect.right &&
      event.clientY >= rect.top &&
      event.clientY <= rect.bottom

    if (clickedOnImage) return

    this.close()
  }

  previous(event) {
    event.stopPropagation()

    if (this.itemTargets.length <= 1) return

    const nextIndex = (this.currentIndex - 1 + this.itemTargets.length) % this.itemTargets.length

    this.slideTo(nextIndex, 'previous')
  }

  next(event) {
    event.stopPropagation()

    if (this.itemTargets.length <= 1) return

    const nextIndex = (this.currentIndex + 1) % this.itemTargets.length

    this.slideTo(nextIndex, 'next')
  }

  keydown(event) {
    if (this.overlayTarget.hidden) return

    switch (event.key) {
      case 'Escape':
        event.preventDefault()
        this.close()
        break

      case 'ArrowLeft':
        event.preventDefault()
        this.previous(event)
        break

      case 'ArrowRight':
        event.preventDefault()
        this.next(event)
        break
    }
  }

  prefersReducedMotion() {
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches
  }

  pointerDown(event) {
    if (this.isSliding) return
    if (this.itemTargets.length <= 1) return

    this.isDragging = true
    this.dragStartX = event.clientX
    this.dragCurrentX = event.clientX
    this.dragPointerId = event.pointerId

    const previousIndex = (this.currentIndex - 1 + this.itemTargets.length) % this.itemTargets.length

    const nextIndex = (this.currentIndex + 1) % this.itemTargets.length

    this.dragPreviousImage = this.createDragImage(previousIndex, 'previous')

    this.dragNextImage = this.createDragImage(nextIndex, 'next')

    this.stageTarget.appendChild(this.dragPreviousImage)
    this.stageTarget.appendChild(this.dragNextImage)

    this.stageTarget.setPointerCapture(event.pointerId)
  }

  pointerMove(event) {
    if (!this.isDragging) return
    if (event.pointerId !== this.dragPointerId) return

    this.dragCurrentX = event.clientX

    const offset = this.dragCurrentX - this.dragStartX
    const width = this.stageTarget.clientWidth

    if (width <= 0) return

    this.imageTarget.style.transform = `translateX(${offset}px)`

    this.dragPreviousImage.style.transform = `translateX(${offset - width}px)`

    this.dragNextImage.style.transform = `translateX(${offset + width}px)`
  }

  pointerCancel(event) {
    if (!this.isDragging) return
    if (event.pointerId !== this.dragPointerId) return

    this.dragCurrentX = this.dragStartX
    this.pointerUp(event)
  }

  pointerUp(event) {
    if (!this.isDragging) return
    if (event.pointerId !== this.dragPointerId) return

    const offset = this.dragCurrentX - this.dragStartX
    const width = this.stageTarget.clientWidth
    const threshold = Math.min(width * 0.2, 140)
    const reducedMotion = this.prefersReducedMotion()

    this.isDragging = false

    if (this.stageTarget.hasPointerCapture(event.pointerId)) {
      this.stageTarget.releasePointerCapture(event.pointerId)
    }

    this.dragPointerId = null

    const currentImage = this.imageTarget
    const previousImage = this.dragPreviousImage
    const nextImage = this.dragNextImage

    if (Math.abs(offset) < 3) {
      currentImage.style.transform = ''

      previousImage?.remove()
      nextImage?.remove()

      this.dragPreviousImage = null
      this.dragNextImage = null
      this.isSliding = false

      return
    }

    const finishDrag = (newIndex, activeImage) => {
      currentImage.remove()

      if (activeImage !== previousImage) {
        previousImage?.remove()
      }

      if (activeImage !== nextImage) {
        nextImage?.remove()
      }

      activeImage.classList.remove('image-lightbox__image--dragging')
      activeImage.style.transition = ''
      activeImage.style.transform = ''
      activeImage.dataset.imageLightboxTarget = 'image'

      this.currentIndex = newIndex
      this.updateInformation()

      this.dragPreviousImage = null
      this.dragNextImage = null
      this.isSliding = false
    }

    const resetDrag = () => {
      if (reducedMotion) {
        currentImage.style.transform = ''

        previousImage?.remove()
        nextImage?.remove()

        this.dragPreviousImage = null
        this.dragNextImage = null
        this.isSliding = false

        return
      }

      currentImage.style.transition = 'transform 0.28s cubic-bezier(0.4, 0, 0.2, 1)'

      previousImage.style.transition = 'transform 0.28s cubic-bezier(0.4, 0, 0.2, 1)'

      nextImage.style.transition = 'transform 0.28s cubic-bezier(0.4, 0, 0.2, 1)'

      requestAnimationFrame(() => {
        currentImage.style.transform = 'translateX(0)'
        previousImage.style.transform = 'translateX(-100%)'
        nextImage.style.transform = 'translateX(100%)'
      })

      currentImage.addEventListener(
        'transitionend',
        () => {
          currentImage.style.transition = ''
          currentImage.style.transform = ''

          previousImage.remove()
          nextImage.remove()

          this.dragPreviousImage = null
          this.dragNextImage = null
          this.isSliding = false
        },
        { once: true }
      )
    }

    if (Math.abs(offset) < threshold) {
      this.isSliding = true
      resetDrag()
      return
    }

    this.isSliding = true

    const newIndex =
      offset < 0
        ? (this.currentIndex + 1) % this.itemTargets.length
        : (this.currentIndex - 1 + this.itemTargets.length) % this.itemTargets.length

    const activeImage = offset < 0 ? nextImage : previousImage

    if (reducedMotion) {
      finishDrag(newIndex, activeImage)
      return
    }

    currentImage.style.transition = 'transform 0.28s cubic-bezier(0.4, 0, 0.2, 1)'

    previousImage.style.transition = 'transform 0.28s cubic-bezier(0.4, 0, 0.2, 1)'

    nextImage.style.transition = 'transform 0.28s cubic-bezier(0.4, 0, 0.2, 1)'

    if (offset < 0) {
      requestAnimationFrame(() => {
        currentImage.style.transform = 'translateX(-100%)'
        nextImage.style.transform = 'translateX(0)'
      })

      nextImage.addEventListener('transitionend', () => finishDrag(newIndex, nextImage), { once: true })
    } else {
      requestAnimationFrame(() => {
        currentImage.style.transform = 'translateX(100%)'
        previousImage.style.transform = 'translateX(0)'
      })

      previousImage.addEventListener('transitionend', () => finishDrag(newIndex, previousImage), { once: true })
    }
  }

  createDragImage(index, direction) {
    const item = this.itemTargets[index]
    const image = document.createElement('img')

    image.src = item.dataset.imageLightboxUrl
    image.alt = item.dataset.imageLightboxAlt || ''

    image.className = ['image-lightbox__image', 'image-lightbox__image--dragging'].join(' ')

    image.style.transform = direction === 'next' ? 'translateX(100%)' : 'translateX(-100%)'

    return image
  }

  slideTo(index, direction) {
    if (this.isSliding) return

    const nextItem = this.itemTargets[index]

    if (!nextItem) return

    this.isSliding = true

    const currentImage = this.imageTarget
    const nextImage = document.createElement('img')

    nextImage.alt = nextItem.dataset.imageLightboxAlt || ''
    nextImage.className = [
      'image-lightbox__image',
      'image-lightbox__image--sliding',
      direction === 'next' ? 'image-lightbox__image--waiting-right' : 'image-lightbox__image--waiting-left'
    ].join(' ')

    nextImage.addEventListener(
      'load',
      () => {
        this.stageTarget.appendChild(nextImage)

        requestAnimationFrame(() => {
          requestAnimationFrame(() => {
            currentImage.classList.add(
              'image-lightbox__image--sliding',
              direction === 'next' ? 'image-lightbox__image--exit-left' : 'image-lightbox__image--exit-right'
            )

            nextImage.classList.remove('image-lightbox__image--waiting-right', 'image-lightbox__image--waiting-left')

            nextImage.classList.add('image-lightbox__image--active')
          })
        })

        const finishSlide = () => {
          if (!currentImage.isConnected) return

          currentImage.remove()

          nextImage.classList.remove('image-lightbox__image--sliding', 'image-lightbox__image--active')

          nextImage.dataset.imageLightboxTarget = 'image'

          this.currentIndex = index
          this.updateInformation()

          this.isSliding = false
        }

        if (this.prefersReducedMotion()) {
          finishSlide()
        } else {
          nextImage.addEventListener('transitionend', finishSlide, { once: true })
        }
      },
      { once: true }
    )

    nextImage.src = nextItem.dataset.imageLightboxUrl
  }

  showCurrentImage() {
    const item = this.itemTargets[this.currentIndex]

    if (!item) return

    this.imageTarget.src = item.dataset.imageLightboxUrl
    this.imageTarget.alt = item.dataset.imageLightboxAlt || ''

    this.updateInformation()
  }

  updateInformation() {
    const item = this.itemTargets[this.currentIndex]

    if (!item) return

    if (this.hasCaptionTarget) {
      this.captionTarget.textContent = item.dataset.imageLightboxAlt || ''
    }

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.currentIndex + 1} von ${this.itemTargets.length}`
    }

    const hasMultipleImages = this.itemTargets.length > 1

    if (this.hasPreviousButtonTarget) {
      this.previousButtonTarget.hidden = !hasMultipleImages
    }

    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.hidden = !hasMultipleImages
    }
  }
}
