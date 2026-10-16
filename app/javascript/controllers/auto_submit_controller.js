import { Controller } from "@hotwired/stimulus"

let pendingFocus = null

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    if (pendingFocus) this.restoreFocus()
  }

  submit() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }

  debouncedSubmit(event) {
    clearTimeout(this.timeout)
    this.rememberFocus(event.target)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  rememberFocus(field) {
    pendingFocus = { name: field.name, selectionStart: field.selectionStart, selectionEnd: field.selectionEnd }
  }

  restoreFocus() {
    const { name, selectionStart, selectionEnd } = pendingFocus
    pendingFocus = null

    const field = this.element.querySelector(`[name="${name}"]`)
    if (!field) return

    field.focus()
    if (typeof selectionStart === "number" && field.setSelectionRange) {
      field.setSelectionRange(selectionStart, selectionEnd)
    }
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
