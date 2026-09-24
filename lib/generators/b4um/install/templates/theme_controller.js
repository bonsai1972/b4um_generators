import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'b4um-theme'
const DARK_MEDIA_QUERY = '(prefers-color-scheme: dark)'
const THEMES = ['system', 'light', 'dark']

export default class extends Controller {
  static targets = ['menu', 'toggle', 'icon', 'option']

  connect() {
    this.systemTheme = window.matchMedia(DARK_MEDIA_QUERY)

    this.handleSystemThemeChange = this.handleSystemThemeChange.bind(this)
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)

    this.systemTheme.addEventListener('change', this.handleSystemThemeChange)
    document.addEventListener('click', this.handleOutsideClick)
    document.addEventListener('keydown', this.handleKeydown)

    this.applyTheme()
    this.close()
  }

  disconnect() {
    this.systemTheme?.removeEventListener('change', this.handleSystemThemeChange)

    document.removeEventListener('click', this.handleOutsideClick)
    document.removeEventListener('keydown', this.handleKeydown)
  }

  toggle(event) {
    event.stopPropagation()

    if (this.menuTarget.hidden) {
      this.open()
    } else {
      this.close()
    }
  }

  select(event) {
    const theme = event.currentTarget.dataset.themeValue

    if (!THEMES.includes(theme)) return

    if (theme === 'system') {
      localStorage.removeItem(STORAGE_KEY)
    } else {
      localStorage.setItem(STORAGE_KEY, theme)
    }

    this.applyTheme()
    this.close()
  }

  open() {
    this.menuTarget.hidden = false
    this.toggleTarget.setAttribute('aria-expanded', 'true')
  }

  close() {
    this.menuTarget.hidden = true
    this.toggleTarget.setAttribute('aria-expanded', 'false')
  }

  applyTheme() {
    const preference = this.preference
    const resolvedTheme = this.resolveTheme(preference)

    document.documentElement.dataset.b4umTheme = resolvedTheme

    this.updateOptions(preference)
    this.updateIcon(resolvedTheme)
  }

  get preference() {
    const storedTheme = localStorage.getItem(STORAGE_KEY)

    return THEMES.includes(storedTheme) ? storedTheme : 'system'
  }

  resolveTheme(preference) {
    if (preference === 'dark') return 'dark'
    if (preference === 'light') return 'light'

    return this.systemTheme.matches ? 'dark' : 'light'
  }

  updateOptions(preference) {
    this.optionTargets.forEach((option) => {
      const active = option.dataset.themeValue === preference

      option.classList.toggle('is-active', active)
      option.setAttribute('aria-checked', String(active))
    })
  }

  updateIcon(theme) {
    this.iconTarget.textContent = theme === 'dark' ? '☾' : '☀'
  }

  handleSystemThemeChange() {
    if (this.preference !== 'system') return

    this.applyTheme()
  }

  handleOutsideClick(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  handleKeydown(event) {
    if (event.key !== 'Escape') return
    if (this.menuTarget.hidden) return

    this.close()
    this.toggleTarget.focus()
  }
}
