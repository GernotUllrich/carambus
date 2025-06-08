import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["start", "intro", "language"]

  connect() {
    console.log('Window.hotkeys in view:', window.hotkeys); // Check availability
    if (!window.hotkeys) {
      console.error('Hotkeys not available!');
      return;
    }

    this.setupInitialFocus();
    this.setupHotkeys();
  }

  setupInitialFocus() {
    let current_element = document.activeElement.getAttribute("id");
    console.log("active: " + current_element);
    if (current_element == null) {
      current_element = "start";
    }
    console.log("active now: " + current_element);
    const elementToFocus = document.getElementById(current_element);
    if (elementToFocus) {
      elementToFocus.focus();
    }
  }

  setupHotkeys() {
    const keyMap = {
      33: "key_a", // Page Up
      37: "key_a", // Left Arrow
      34: "key_b", // Page Down
      39: "key_b", // Right Arrow
      66: "key_c", // B key
      38: "key_c", // Up Arrow
      116: "key_d", // F5
      27: "key_d", // Escape
      40: "key_d", // Down Arrow
      13: "key_d", // Enter
    }

    const tabbed_elements = {
      "start": "intro",
      "intro": "language",
      "language": "start"
    }

    window.hotkeys('*', (event) => {
      // Prevent the default refresh event under WINDOWS system
      if (event.keyCode == 116) {
        event.preventDefault();
      }

      if (event.keyCode in keyMap) {
        const key = keyMap[event.keyCode];
        
        if (key === "key_c") {
          window.history.back();
        }
        
        if (key === "key_b") {
          const current_element = document.activeElement.getAttribute("id");
          console.log("active becomes (b): " + tabbed_elements[current_element]);
          const nextElement = document.getElementById(tabbed_elements[current_element]);
          if (nextElement) {
            nextElement.focus();
          }
        }
        
        if (key === "key_a") {
          const current_element = document.activeElement.getAttribute("id");
          for (const k in tabbed_elements) {
            if (tabbed_elements[k] === current_element) {
              console.log("active becomes (a): " + k);
              const prevElement = document.getElementById(k);
              if (prevElement) {
                prevElement.focus();
              }
              break;
            }
          }
        }
        
        if (key === "key_d") {
          console.log("activate: " + document.activeElement.getAttribute("id"));
          document.activeElement.click();
        }

        event.preventDefault();
        return true;
      } else {
        console.warn("Unhandled Keycode:", event.keyCode);
      }
    });
  }

  toggleFullScreen(elem) {
    if ((document.fullScreenElement !== undefined && document.fullScreenElement === null) || 
        (document.msFullscreenElement !== undefined && document.msFullscreenElement === null) || 
        (document.mozFullScreen !== undefined && !document.mozFullScreen) || 
        (document.webkitIsFullScreen !== undefined && !document.webkitIsFullScreen)) {
      if (elem.requestFullScreen) {
        elem.requestFullScreen();
      } else if (elem.mozRequestFullScreen) {
        elem.mozRequestFullScreen();
      } else if (elem.webkitRequestFullScreen) {
        elem.webkitRequestFullScreen(Element.ALLOW_KEYBOARD_INPUT);
      } else if (elem.msRequestFullscreen) {
        elem.msRequestFullscreen();
      }
    } else {
      if (document.cancelFullScreen) {
        document.cancelFullScreen();
      } else if (document.mozCancelFullScreen) {
        document.mozCancelFullScreen();
      } else if (document.webkitCancelFullScreen) {
        document.webkitCancelFullScreen();
      } else if (document.msExitFullscreen) {
        document.msExitFullscreen();
      }
    }
  }

  simulateKey(keyCode, type, modifiers) {
    const evtName = (typeof (type) === "string") ? "key" + type : "keydown";
    const modifier = (typeof (modifiers) === "object") ? modifier : {};

    const event = document.createEvent("HTMLEvents");
    event.initEvent(evtName, true, false);
    event.keyCode = keyCode;

    for (const i in modifiers) {
      event[i] = modifiers[i];
    }

    document.dispatchEvent(event);
  }
} 