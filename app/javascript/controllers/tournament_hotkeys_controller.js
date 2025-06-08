import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (!window.hotkeys) {
      console.error('Hotkeys not available!');
      return;
    }

    // Initialize focus on first tabbable element
    let tabbed_elements = document.querySelectorAll('a[tabindex="1"]');
    let tabbed_keys = Array.from(tabbed_elements).map(el => el.getAttribute("id"));
    
    if (tabbed_keys.length > 0) {
      let current_element = tabbed_keys[1];
      document.getElementById(current_element)?.focus();
    }

    // Set up hotkeys
    window.hotkeys('*', this.handleHotkey.bind(this));
  }

  handleHotkey(event) {
    const keyMap = {
      33: "key_a", // Page Up
      37: "key_a", // Left Arrow
      34: "key_b", // Page Down
      39: "key_b", // Right Arrow
      66: "key_c", // B
      38: "key_c", // Up Arrow
      116: "key_d", // F5
      27: "key_d", // Escape
      40: "key_d", // Down Arrow
      13: "key_d", // Enter
    };

    let tabbed_elements = document.querySelectorAll('a[tabindex="1"]');
    let tabbed_keys = Array.from(tabbed_elements).map(el => el.getAttribute("id"));

    let current_element = document.activeElement.getAttribute("id");
    if (current_element == null) {
      current_element = tabbed_keys[0];
      document.getElementById(current_element)?.focus();
    }

    if (event.key in keyMap) {
      let key = keyMap[event.key];
      
      switch (key) {
        case "key_c":
          if (current_element === tabbed_keys[0]) {
            window.history.back();
          } else {
            document.getElementById(tabbed_keys[0])?.focus();
          }
          break;

        case "key_b":
          this.focusNextElement(tabbed_keys, current_element);
          break;

        case "key_a":
          this.focusPreviousElement(tabbed_keys, current_element);
          break;

        case "key_d":
          document.activeElement?.click();
          break;
      }
    }

    event.preventDefault();
    return true;
  }

  focusNextElement(tabbed_keys, current_element) {
    for (let i = 0; i < tabbed_keys.length; i++) {
      if (tabbed_keys[i] === current_element) {
        let nextIndex = i + 1;
        if (nextIndex >= tabbed_keys.length) nextIndex = 0;
        document.getElementById(tabbed_keys[nextIndex])?.focus();
        break;
      }
    }
  }

  focusPreviousElement(tabbed_keys, current_element) {
    for (let i = 0; i < tabbed_keys.length; i++) {
      if (tabbed_keys[i] === current_element) {
        let prevIndex = i - 1;
        if (prevIndex < 0) prevIndex = tabbed_keys.length - 1;
        document.getElementById(tabbed_keys[prevIndex])?.focus();
        break;
      }
    }
  }
} 