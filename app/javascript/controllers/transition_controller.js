import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  enter() {
    this.element.classList.remove(
      this.data.get("enterFrom"),
      this.data.get("leaveTo")
    )
    this.element.classList.add(
      this.data.get("enterTo"),
      this.data.get("enter")
    )
  }

  leave() {
    this.element.classList.remove(
      this.data.get("enterTo"),
      this.data.get("enter")
    )
    this.element.classList.add(
      this.data.get("leaveTo"),
      this.data.get("leave")
    )
  }
} 