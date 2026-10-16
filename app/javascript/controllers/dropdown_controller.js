import { Controller } from "@hotwired/stimulus"

const openDropdowns = new Set()

export default class extends Controller {
  static targets = ["panel", "summary"]

  connect() {
    this.boundClose = this.close.bind(this)
    this.boundEscape = this.closeOnEscape.bind(this)
    document.addEventListener("click", this.boundClose)
    document.addEventListener("keydown", this.boundEscape)

    if (openDropdowns.has(this.element.id)) {
      this.panelTarget.classList.remove("hidden")
    }
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
    document.removeEventListener("keydown", this.boundEscape)
  }

  toggle(event) {
    event.stopPropagation()
    const opening = this.panelTarget.classList.contains("hidden")
    this.panelTarget.classList.toggle("hidden")
    this.setOpen(opening)
  }

  close(event) {
    if (this.panelTarget.classList.contains("hidden")) return
    if (!this.element.contains(event.target)) {
      this.panelTarget.classList.add("hidden")
      this.setOpen(false)
    }
  }

  closeOnEscape(event) {
    if (event.key !== "Escape" || this.panelTarget.classList.contains("hidden")) return

    this.panelTarget.classList.add("hidden")
    this.setOpen(false)
  }

  setOpen(open) {
    if (open) {
      openDropdowns.add(this.element.id)
    } else {
      openDropdowns.delete(this.element.id)
    }
  }

  submit() {
    this.updateSummary()
    this.element.closest("form").requestSubmit()
  }

  updateSummary() {
    if (!this.hasSummaryTarget) return

    const checked = Array.from(this.element.querySelectorAll('input[type="checkbox"]:checked'))

    if (checked.length === 0) {
      this.summaryTarget.textContent = this.summaryTarget.dataset.placeholder
    } else if (checked.length === 1) {
      this.summaryTarget.textContent = checked[0].dataset.label
    } else {
      this.summaryTarget.textContent = `${checked.length} selected`
    }
  }
}
