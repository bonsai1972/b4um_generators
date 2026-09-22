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

configureHeadingAttributes()
configureAlignmentAttributes()
configureColorAttributes()
registerAlignmentElements()

document.addEventListener('trix-initialize', (event) => {
  const editor = event.target

  if (!(editor instanceof HTMLElement)) return

  installB4umToolbar(editor)
})

document.addEventListener('trix-action-invoke', (event) => {
  if (event.actionName !== 'x-horizontal-rule') return

  const editor = event.target.editor

  if (!editor) return

  const attachment = new Trix.Attachment({
    content: '<hr>',
    contentType: 'vnd.rubyonrails.horizontal-rule.html'
  })

  editor.insertAttachment(attachment)
})

/* -------------------------------------------------------------------------- */
/*                              Configuration                                 */
/* -------------------------------------------------------------------------- */

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
