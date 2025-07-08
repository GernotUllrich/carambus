const Keyboard = {
  multiMode: true,
  capsKeyElement: "",
  selectedElement: "",
  elements: {
    main: null,
    keysContainer: null,
    keys: []
  },
  keyboard_type: "numeric",
  eventHandlers: {
    oninput: null,
    onclose: null
  },

  properties: {
    value: "",
    capsLock: false,
    altPressed: false
  },

  init() {
    // Create main elements
    Keyboard.elements.main = document.createElement("div");
    Keyboard.elements.keysContainer = document.createElement("div");

    // Setup main elements
    Keyboard.elements.main.classList.add("keyboard", "keyboard--hidden");
    Keyboard.elements.keysContainer.classList.add("keyboard__keys");

    if (Keyboard.multiMode == false) {
      // Run only full keyboard
      Keyboard._setupKeyboard("alfa");
    }

    Keyboard.elements.keys = Keyboard.elements.keysContainer.querySelectorAll(".keyboard__key");
    Keyboard.elements.main.appendChild(Keyboard.elements.keysContainer);
    document.querySelector('body').appendChild(Keyboard.elements.main);

    document.addEventListener('click', function (event) {
      if (event.target.matches('input[type="email"]')) {
        Keyboard._setupKeyboard("alfa");
        Keyboard.selectedElement = event.target;
        Keyboard.open(event.target.value, currentValue => {
          event.target.value = currentValue;
        });

      }

      if (event.target.matches('input[type="number"]')) {
        Keyboard._setupKeyboard("numeric");
        Keyboard.selectedElement = event.target;
        Keyboard.open(event.target.value, currentValue => {
          event.target.value = currentValue;
        });
      }

      if (event.target.matches('input[type="text"]')) {
        Keyboard._setupKeyboard("alfa");
        Keyboard.selectedElement = event.target;
        Keyboard.open(event.target.value, currentValue => {
          event.target.value = currentValue;
        });

      }

      if (event.target.matches('input[type="password"]')) {
        Keyboard._setupKeyboard("alfa");
        Keyboard.selectedElement = event.target;
        Keyboard.open(event.target.value, currentValue => {
          event.target.value = currentValue;
        });

      }

      if (event.target.matches('input[class="p-input--bonus"]')) {
        Keyboard._setupKeyboard("alfa");
        Keyboard.selectedElement = event.target;
        Keyboard.open(event.target.value, currentValue => {
          event.target.value = currentValue;
        });

      }

    }, true);
  },

  _setupKeyboard(type) {
    Keyboard.elements.keysContainer.innerHTML = "";
    Keyboard.elements.keysContainer.appendChild(Keyboard._createKeys(type));
  },
  _createKeys(keyboard_type) {
    const fragment = document.createDocumentFragment();
    var keyLayout = [];
    if (keyboard_type == "numeric") {
      keyLayout = [
        "7", "8", "9", "br", "4", "5", "6", "br", "1", "2", "3", "br", "0", "backspace", "done"
      ];
    } else if (keyboard_type == "kiosk") {
      // Special keyboard for kiosk mode exit
      keyLayout = [
        "alt", "space", "br",
        "exit_kiosk", "done"
      ];
    } else {
      // No spacebar
      // keyLayout = [
      //     "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "backspace",
      //     "q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
      //     "caps", "a", "s", "d", "f", "g", "h", "j", "k", "l", "enter",
      //     "z", "x", "c", "v", "b", "n", "m", "-", "_", ".", "@", ".com",
      //     "done"
      //     ];

      // With spacebar
      keyLayout = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "ß", "?", "backspace",
        "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "ü", "+",
        "a", "s", "d", "f", "g", "h", "j", "k", "l", "ö", "ä", "enter",
        "caps", "z", "x", "c", "v", "b", "n", "m", ",", ".", "-", "!", "done",
        "space"
      ];
    }


    // Creates HTML for an icon
    const createIconHTML = (icon_name) => {
      return `<i class="material-icons">${icon_name}</i>`;
    };

    keyLayout.forEach(key => {
      const keyElement = document.createElement("button");
      const insertLineBreak = ["backspace", "+", "enter", "!", "br"].indexOf(key) !== -1;

      // Add attributes/classes
      keyElement.setAttribute("type", "button");
      keyElement.classList.add("keyboard__key");

      switch (key) {
        case "alt":
          keyElement.classList.add("keyboard__key--wide", "keyboard__key--activatable");
          keyElement.textContent = "ALT";
          keyElement.style.backgroundColor = "#4a5568";

          keyElement.addEventListener("click", () => {
            this.properties.altPressed = !this.properties.altPressed;
            keyElement.classList.toggle("keyboard__key--active", this.properties.altPressed);
            keyElement.style.backgroundColor = this.properties.altPressed ? "#2d3748" : "#4a5568";
          });

          break;

        case "space":
          keyElement.classList.add("keyboard__key--extra-wide");
          keyElement.innerHTML = createIconHTML("space_bar");

          keyElement.addEventListener("click", () => {
            if (this.properties.altPressed) {
              // Simulate ALT+SPACE combination
              this._fireAltSpaceEvent();
              this.properties.altPressed = false;
              // Reset ALT key appearance
              const altKey = this.elements.keysContainer.querySelector('.keyboard__key--activatable');
              if (altKey) {
                altKey.classList.remove("keyboard__key--active");
                altKey.style.backgroundColor = "#4a5568";
              }
            } else {
              this.properties.value += " ";
              this._triggerEvent("oninput");
            }
          });

          break;

        case "exit_kiosk":
          keyElement.classList.add("keyboard__key--wide", "keyboard__key--dark");
          keyElement.textContent = "EXIT KIOSK";
          keyElement.style.backgroundColor = "#e53e3e";

          keyElement.addEventListener("click", () => {
            this._fireAltSpaceEvent();
          });

          break;

        case "backspace":
          keyElement.classList.add("backspace-btn");
          keyElement.innerHTML = createIconHTML("backspace");

          keyElement.addEventListener("click", () => {
            this.properties.value = this.properties.value.substring(0, this.properties.value.length - 1);
            this._triggerEvent("oninput");
          });

          break;

        // case "0":
        //     keyElement.classList.add("nr-0");
        //     keyElement.textContent = key.toLowerCase();
        //     keyElement.addEventListener("click", () => {
        //         this.properties.value += this.properties.capsLock ? key.toUpperCase() : key.toLowerCase();
        //         this._triggerEvent("oninput");
        //     });

        //     break;

        case "caps":
          keyElement.classList.add("keyboard__key--wide", "keyboard__key--activatable");
          Keyboard.capsKeyElement = keyElement
          keyElement.innerHTML = createIconHTML("keyboard_capslock");

          keyElement.addEventListener("click", () => {
            this._toggleCapsLock();
            keyElement.classList.toggle("keyboard__key--active", this.properties.capsLock);
          });

          break;

        case "enter":
          keyElement.classList.add("keyboard__key--wide");
          keyElement.innerHTML = createIconHTML("keyboard_return");

          keyElement.addEventListener("click", () => {
            this.properties.value += "\n";
            this._triggerEvent("oninput");
          });

          break;

        case "done":
          keyElement.classList.add("keyboard__key--wide", "keyboard__key--dark");
          keyElement.innerHTML = createIconHTML("check_circle");

          keyElement.addEventListener("click", () => {
            this.close();
            this._triggerEvent("onclose");
          });

          break;

        case "br":
          keyElement.classList.add("hide-me");
          break;

        default:
          keyElement.textContent = key.toLowerCase();
          keyElement.addEventListener("click", () => {
            this.properties.value += this.properties.capsLock ? key.toUpperCase() : key.toLowerCase();
            this.properties.capsLock = this.properties.value == ""
            Keyboard.capsKeyElement.classList.remove("keyboard__key--active");
            this._triggerEvent("oninput");

            // Propagate Keyboard event
            this._fireKeyEvent();

          });

          break;
      }

      fragment.appendChild(keyElement);

      if (insertLineBreak) {
        fragment.appendChild(document.createElement("br"));
      }
    });


    return fragment;
  },

  _fireAltSpaceEvent() {
    // Create ALT keydown event
    const altDownEvent = new KeyboardEvent("keydown", {
      key: "Alt",
      code: "AltLeft",
      keyCode: 18,
      which: 18,
      altKey: true,
      bubbles: true,
      cancelable: true,
      view: window
    });

    // Create SPACE keydown event
    const spaceDownEvent = new KeyboardEvent("keydown", {
      key: " ",
      code: "Space",
      keyCode: 32,
      which: 32,
      altKey: true,
      bubbles: true,
      cancelable: true,
      view: window
    });

    // Create SPACE keyup event
    const spaceUpEvent = new KeyboardEvent("keyup", {
      key: " ",
      code: "Space",
      keyCode: 32,
      which: 32,
      altKey: true,
      bubbles: true,
      cancelable: true,
      view: window
    });

    // Create ALT keyup event
    const altUpEvent = new KeyboardEvent("keyup", {
      key: "Alt",
      code: "AltLeft",
      keyCode: 18,
      which: 18,
      altKey: false,
      bubbles: true,
      cancelable: true,
      view: window
    });

    // Dispatch events in sequence
    document.dispatchEvent(altDownEvent);
    setTimeout(() => {
      document.dispatchEvent(spaceDownEvent);
      setTimeout(() => {
        document.dispatchEvent(spaceUpEvent);
        setTimeout(() => {
          document.dispatchEvent(altUpEvent);
        }, 50);
      }, 50);
    }, 50);

    console.log("ALT+SPACE combination fired to exit kiosk mode");
  },

  _fireKeyEvent() {
    let evt = new KeyboardEvent("input", {
      bubbles: true,
      cancelable: true,
      view: window
    });

    // Create and dispatch keyboard simulated Event
    Keyboard.selectedElement.dispatchEvent(evt);
  },

  _triggerEvent(handlerName) {
    if (typeof this.eventHandlers[handlerName] == "function") {
      console.log(this.eventHandlers[handlerName]);
      this.eventHandlers[handlerName](this.properties.value);
    }
  },

  _toggleCapsLock() {
    this.properties.capsLock = !this.properties.capsLock;

    for (const key of this.elements.keys) {
      if (key.childElementCount === 0) {
        key.textContent = this.properties.capsLock ? key.textContent.toUpperCase() : key.textContent.toLowerCase();
      }
    }
  },

  open(initialValue, oninput, onclose) {
    this.properties.value = initialValue || "";
    this.eventHandlers.oninput = oninput;
    this.eventHandlers.onclose = onclose;
    this.elements.main.classList.remove("keyboard--hidden");

  },

  close() {
    this.properties.value = "";
    this.eventHandlers.oninput = oninput;
    this.eventHandlers.onclose = onclose;
    this.elements.main.classList.add("keyboard--hidden");
  }
};

setTimeout(function () {
  console.log("###### Keyboard -  The page has loaded succ.");
  Keyboard.init();
}, 500);
