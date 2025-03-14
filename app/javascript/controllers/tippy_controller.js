// tippy_controller.js

import { Controller } from "stimulus";
import tippy from "tippy.js";

export default class extends Controller {
  initialize() {
    document.addEventListener(
      "cable-ready:after-morph",
      this.initializeTippys.bind(this),
      true
    );
  }

  connect() {
    this.initializeTippys();
  }

  disconnect() {
    this.destroyTippys();
  }

  initializeTippys() {
    this.destroyTippys();
    tippy(document.querySelectorAll("[data-tippy-content]"));
  }

  destroyTippys() {
    let tips = document.querySelectorAll("[data-tippy-content]");
    tips.forEach((e) => {
      if (e._tippy) e._tippy.destroy();
    });
  }
}
