/* -------------------------------------------------------------------------- */
/*                               B4UM Trix                                    */
/* -------------------------------------------------------------------------- */

const HEADING_LEVELS = [1, 2, 3, 4, 5, 6]

const ALIGNMENTS = {
  alignLeft: 'left',
  alignCenter: 'center',
  alignRight: 'right'
}

const FOREGROUND_COLORS = [
  'rgb(136, 118, 38)',
  'rgb(185, 94, 6)',
  'rgb(207, 0, 0)',
  'rgb(216, 28, 170)',
  'rgb(144, 19, 254)',
  'rgb(5, 98, 185)',
  'rgb(17, 138, 15)',
  'rgb(148, 82, 22)',
  'rgb(102, 102, 102)'
]

const BACKGROUND_COLORS = [
  'rgb(250, 247, 133)',
  'rgb(255, 240, 219)',
  'rgb(255, 229, 229)',
  'rgb(255, 228, 247)',
  'rgb(242, 237, 255)',
  'rgb(225, 239, 252)',
  'rgb(228, 248, 226)',
  'rgb(238, 226, 215)',
  'rgb(242, 242, 242)'
]

Trix.config.dompurify.ADD_TAGS = ['align-left', 'align-center', 'align-right']
Trix.config.dompurify.ADD_ATTR = ['id']

allowB4umHtmlAttributes()

configureHeadingAttributes()
configureAlignmentAttributes()
configureContainerAttributes()
configureColorAttributes()
registerAlignmentElements()

document.addEventListener('trix-initialize', (event) => {
  const editor = event.target

  if (!(editor instanceof HTMLElement)) return

  installB4umToolbar(editor)
})

document.addEventListener('trix-action-invoke', (event) => {
  const editor = event.target.editor

  if (!editor) return

  if (event.actionName === 'x-horizontal-rule') {
    const attachment = new Trix.Attachment({
      content: '<hr>',
      contentType: 'vnd.rubyonrails.horizontal-rule.html'
    })

    editor.insertAttachment(attachment)
    return
  }
})

function insertContainer(editor, tagName) {
  const selectedRange = editor.getSelectedRange()

  if (!selectedRange || selectedRange[0] === selectedRange[1]) {
    window.alert('Bitte markieren Sie zuerst den Inhalt.')
    return
  }

  const id = window.prompt('Bitte geben Sie die ID ein:')

  if (id === null) return

  const trimmedId = id.trim()

  if (!trimmedId) {
    window.alert('Bitte geben Sie eine ID ein.')
    return
  }

  editor.recordUndoEntry(`Insert ${tagName.toUpperCase()} Container`)

  editor.setSelectedRange(selectedRange)

  const attributeName = tagName === 'div' ? 'b4umDiv' : tagName

  editor.activateAttribute(attributeName)

  editor.composition.setHTMLAtributeAtPosition(selectedRange[0], 'id', trimmedId)

  editor.setSelectedRange(selectedRange)
}

/* -------------------------------------------------------------------------- */
/*                              Configuration                                 */
/* -------------------------------------------------------------------------- */

function allowB4umHtmlAttributes() {
  const originalSetHTML = Trix.HTMLSanitizer.setHTML

  Trix.HTMLSanitizer.setHTML = function (element, html, options = {}) {
    const allowedAttributes = [
      'style',
      'href',
      'src',
      'width',
      'height',
      'language',
      'class',
      'id',
      ...(options.allowedAttributes || [])
    ]

    return originalSetHTML.call(this, element, html, {
      ...options,
      allowedAttributes: [...new Set(allowedAttributes)]
    })
  }
}

function configureHeadingAttributes() {
  HEADING_LEVELS.forEach((level) => {
    Trix.config.blockAttributes[`heading${level}`] = {
      tagName: `h${level}`,
      terminal: true,
      breakOnReturn: true,
      group: false
    }
  })
}

function configureAlignmentAttributes() {
  Object.entries(ALIGNMENTS).forEach(([attribute, alignment]) => {
    Trix.config.blockAttributes[attribute] = {
      tagName: `align-${alignment}`,
      parse: true,
      nestable: false,
      exclusive: true,
      group: false
    }
  })
}

function configureContainerAttributes() {
  Trix.config.blockAttributes.default.htmlAttributes = ['id']

  Trix.config.blockAttributes.b4umDiv = {
    tagName: 'div',
    parse: true,
    nestable: false,
    exclusive: true,
    group: false,
    htmlAttributes: ['id'],
    test(element) {
      return element.hasAttribute('id')
    }
  }

  Trix.config.blockAttributes.section = {
    tagName: 'section',
    parse: true,
    nestable: false,
    exclusive: true,
    group: false,
    htmlAttributes: ['id']
  }

  Trix.config.blockAttributes.article = {
    tagName: 'article',
    parse: true,
    nestable: false,
    exclusive: true,
    group: false,
    htmlAttributes: ['id']
  }
}

function configureColorAttributes() {
  FOREGROUND_COLORS.forEach((color, index) => {
    Trix.config.textAttributes[`fgColor${index + 1}`] = {
      style: { color },
      inheritable: true,
      parser: (element) => element.style.color === color
    }
  })

  BACKGROUND_COLORS.forEach((color, index) => {
    Trix.config.textAttributes[`bgColor${index + 1}`] = {
      style: { backgroundColor: color },
      inheritable: true,
      parser: (element) => element.style.backgroundColor === color
    }
  })
}

function registerAlignmentElements() {
  registerAlignmentElement('align-left', 'left')
  registerAlignmentElement('align-center', 'center')
  registerAlignmentElement('align-right', 'right')
}

function registerAlignmentElement(tagName, alignment) {
  if (customElements.get(tagName)) return

  customElements.define(
    tagName,
    class extends HTMLElement {
      constructor() {
        super()

        const shadow = this.attachShadow({ mode: 'open' })

        shadow.innerHTML = `
          <style>
            :host {
              display: block;
              width: 100%;
              text-align: ${alignment};
            }
          </style>

          <slot></slot>
        `
      }
    }
  )
}

/* -------------------------------------------------------------------------- */
/*                                Toolbar                                     */
/* -------------------------------------------------------------------------- */

function installB4umToolbar(editor) {
  const toolbar = editor.toolbarElement

  if (!toolbar) return
  if (toolbar.dataset.b4umTrixInitialized === 'true') return

  toolbar.dataset.b4umTrixInitialized = 'true'

  replaceHeadingButton(toolbar)
  installHeadingDialog(toolbar)
  installAlignmentButtons(toolbar)

  installHorizontalRuleButton(toolbar)
  installContainerButtons(toolbar)
  installContainerButtonHandlers(editor, toolbar)
  installColorButton(toolbar)

  installColorDialog(toolbar)
}

function replaceHeadingButton(toolbar) {
  const originalButton = toolbar.querySelector('[data-trix-attribute="heading1"]')

  if (!originalButton) return

  originalButton.insertAdjacentHTML('beforebegin', headingButtonTemplate())

  originalButton.remove()
}

function installHeadingDialog(toolbar) {
  const dialogs = toolbar.querySelector('[data-trix-dialogs]')

  if (!dialogs) return
  if (dialogs.querySelector('[data-trix-dialog="x-heading"]')) return

  dialogs.insertAdjacentHTML('beforeend', headingDialogTemplate())
}

function installAlignmentButtons(toolbar) {
  const blockTools = toolbar.querySelector('[data-trix-button-group="block-tools"]')

  if (!blockTools) return
  if (toolbar.querySelector('.trix-button-group--alignment-tools')) return

  blockTools.insertAdjacentHTML('afterend', alignmentButtonsTemplate())
}

function installHorizontalRuleButton(toolbar) {
  const quoteButton = toolbar.querySelector('[data-trix-attribute="quote"]')

  if (!quoteButton) return
  if (toolbar.querySelector('[data-trix-action="x-horizontal-rule"]')) return

  quoteButton.insertAdjacentHTML('afterend', horizontalRuleButtonTemplate())
}

function installContainerButtons(toolbar) {
  const blockTools = toolbar.querySelector('[data-trix-button-group="block-tools"]')

  if (!blockTools) return
  if (toolbar.querySelector('.trix-button-group--container-tools')) return

  blockTools.insertAdjacentHTML('afterend', containerButtonsTemplate())
}

function installContainerButtonHandlers(editorElement, toolbar) {
  const editor = editorElement.editor

  if (!editor) return

  toolbar
    .querySelectorAll(
      '[data-trix-attribute="b4umDiv"], [data-trix-attribute="section"], [data-trix-attribute="article"]'
    )
    .forEach((button) => {
      if (button.dataset.b4umContainerHandler === 'true') return

      button.dataset.b4umContainerHandler = 'true'

      button.addEventListener(
        'mousedown',
        (event) => {
          const attributeName = button.dataset.trixAttribute

          if (!attributeName) return

          if (button.hasAttribute('data-trix-active')) {
            return
          }

          event.preventDefault()
          event.stopImmediatePropagation()

          const tagName = attributeName === 'b4umDiv' ? 'div' : attributeName

          insertContainer(editor, tagName)
        },
        true
      )
    })
}

function installColorButton(toolbar) {
  const textTools = toolbar.querySelector('[data-trix-button-group="text-tools"]')

  if (!textTools) return
  if (toolbar.querySelector('[data-trix-action="x-color"]')) return

  textTools.insertAdjacentHTML('beforeend', colorButtonTemplate())
}

function installColorDialog(toolbar) {
  const dialogs = toolbar.querySelector('[data-trix-dialogs]')

  if (!dialogs) return
  if (dialogs.querySelector('[data-trix-dialog="x-color"]')) return

  dialogs.insertAdjacentHTML('beforeend', colorDialogTemplate())
}

/* -------------------------------------------------------------------------- */
/*                               Templates                                    */
/* -------------------------------------------------------------------------- */

function headingButtonTemplate() {
  return `
    <button
      type="button"
      class="trix-button trix-button--icon trix-button--icon-heading-1"
      data-trix-action="x-heading"
      title="Heading"
      aria-label="Heading"
      tabindex="-1">
      Heading
    </button>
  `
}

function headingDialogTemplate() {
  const buttons = HEADING_LEVELS.map((level) => {
    return `
      <button
        type="button"
        class="trix-button trix-button--dialog"
        data-trix-attribute="heading${level}">
        H${level}
      </button>
    `
  }).join('')

  return `
    <div
      class="trix-dialog trix-dialog--heading"
      data-trix-dialog="x-heading"
      data-trix-dialog-attribute="x-heading">

      <div class="trix-dialog__link-fields">
        <div class="trix-button-group">
          ${buttons}
        </div>
      </div>
    </div>
  `
}

function alignmentButtonsTemplate() {
  return `
    <div class="trix-button-group trix-button-group--alignment-tools">
      <button
        type="button"
        class="trix-button trix-button--icon trix-button--icon-align-left"
        data-trix-attribute="alignLeft"
        title="Align left"
        aria-label="Align left"
        tabindex="-1">
        Align left
      </button>

      <button
        type="button"
        class="trix-button trix-button--icon trix-button--icon-align-center"
        data-trix-attribute="alignCenter"
        title="Align center"
        aria-label="Align center"
        tabindex="-1">
        Align center
      </button>

      <button
        type="button"
        class="trix-button trix-button--icon trix-button--icon-align-right"
        data-trix-attribute="alignRight"
        title="Align right"
        aria-label="Align right"
        tabindex="-1">
        Align right
      </button>
    </div>
  `
}

function containerButtonsTemplate() {
  return `
    <span
      class="trix-button-group trix-button-group--container-tools"
      data-trix-button-group="container-tools">
      <button
        type="button"
        class="trix-button"
        data-trix-attribute="b4umDiv"
        title="DIV"
        aria-label="DIV"
        tabindex="-1">
        div
      </button>
      <button
        type="button"
        class="trix-button"
        data-trix-attribute="section"
        title="SECTION"
        aria-label="SECTION"
        tabindex="-1">
        section
      </button>
      <button
        type="button"
        class="trix-button"
        data-trix-attribute="article"
        title="ARTICLE"
        aria-label="ARTICLE"
        tabindex="-1">
        article
      </button>
    </span>
  `
}

function horizontalRuleButtonTemplate() {
  return `
    <button
      type="button"
      class="trix-button trix-button--icon trix-button--icon-horizontal-rule"
      data-trix-action="x-horizontal-rule"
      title="Divider"
      aria-label="Divider"
      tabindex="-1">
      Divider
    </button>
  `
}

function colorButtonTemplate() {
  return `
    <button
      type="button"
      class="trix-button trix-button--icon trix-button--icon-color"
      data-trix-action="x-color"
      title="Color"
      aria-label="Color"
      tabindex="-1">
      Color
    </button>
  `
}

function colorDialogTemplate() {
  const foregroundButtons = FOREGROUND_COLORS.map((color, index) => {
    return `
      <button
        type="button"
        class="trix-button trix-button--dialog"
        data-trix-attribute="fgColor${index + 1}"
        data-b4um-color="${color}"
        aria-label="Text color ${index + 1}">
      </button>
    `
  }).join('')

  const backgroundButtons = BACKGROUND_COLORS.map((color, index) => {
    return `
      <button
        type="button"
        class="trix-button trix-button--dialog"
        data-trix-attribute="bgColor${index + 1}"
        data-b4um-background-color="${color}"
        aria-label="Background color ${index + 1}">
      </button>
    `
  }).join('')

  return `
    <div
      class="trix-dialog trix-dialog--color"
      data-trix-dialog="x-color"
      data-trix-dialog-attribute="x-color">

      <div class="trix-dialog__link-fields">
        <div class="trix-button-group trix-button-group--foreground-colors">
          ${foregroundButtons}
        </div>

        <div class="trix-button-group trix-button-group--background-colors">
          ${backgroundButtons}
        </div>
      </div>
    </div>
  `
}
