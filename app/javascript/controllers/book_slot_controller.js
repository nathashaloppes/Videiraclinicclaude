import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["availabilityId", "search", "select"]

  open({ params: { id } }) {
    this.availabilityIdTarget.value = id
    this.searchTarget.value = ""
    Array.from(this.selectTarget.options).forEach(opt => { opt.hidden = false })
    document.getElementById("book-slot-modal").showModal()
  }

  filter() {
    const q = this.searchTarget.value.toLowerCase()
    Array.from(this.selectTarget.options).forEach(opt => {
      opt.hidden = opt.value !== "" && !opt.text.toLowerCase().includes(q)
    })
  }

  openQuickCreate() {
    document.getElementById("book-slot-modal").close()
    document.getElementById("quick-create-dentist-modal").showModal()
  }
}
