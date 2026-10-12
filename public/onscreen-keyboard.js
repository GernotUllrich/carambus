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

  // Wurde an diesem Geraet eine ECHTE Taste gedrueckt? Dann gibt es eine physische
  // Tastatur und die Bildschirmtastatur haelt sich heraus. Siehe _watchPhysicalKeyboard.
  physicalKeyboardSeen: false,

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
      // Wer eine echte Tastatur hat, will die Bildschirmtastatur nicht — sie deckt
      // das halbe Formular ab. Ein Klick ins Feld oeffnet sie dann gar nicht erst.
      if (Keyboard.physicalKeyboardSeen) return;

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

    Keyboard._watchPhysicalKeyboard();
  },

  // Erkennt eine physische Tastatur — nicht durch Raten, sondern durch Zusehen.
  //
  // Es gibt keine Web-API, die verlaesslich sagt, ob eine Tastatur angeschlossen ist:
  // `navigator.keyboard` liefert nur ein Layout (und existiert auch ohne Geraet),
  // `pointer: coarse` und `maxTouchPoints` sagen etwas ueber Touch, nichts ueber
  // Tasten. Auch die Absender-IP taugt nicht: Die Scoreboards liegen im selben
  // 192.168.2.x wie jedes Handy im Vereins-WLAN, und der Kiosk-Browser meldet sich
  // ohnehin als 127.0.0.1, weil er auf dem Server selbst laeuft.
  //
  // Wer tippt, hat eine Tastatur — das ist keine Heuristik, sondern Beobachtung.
  // `isTrusted` trennt dabei sauber: vom Browser erzeugte Events sind true, per
  // `new KeyboardEvent()` erzeugte (wie in _fireAltSpaceEvent) immer false. Die
  // Bildschirmtastatur kann sich also nicht selbst wegblenden.
  _watchPhysicalKeyboard() {
    // sessionStorage, nicht localStorage: Die Erkennung soll einen Reload ueberleben,
    // aber nicht das Geraet fuer immer festlegen. Ein Kiosk, an den heute jemand eine
    // Tastatur haengt, ist morgen wieder ein Kiosk.
    try {
      if (sessionStorage.getItem("carambus_physical_keyboard") === "1") {
        Keyboard.physicalKeyboardSeen = true;
      }
    } catch (e) {
      // Privater Modus oder blockierte Speicherung: dann eben je Seitenaufruf neu.
    }

    document.addEventListener("keydown", function (event) {
      if (!event.isTrusted) return;
      if (Keyboard.physicalKeyboardSeen) return;

      Keyboard.physicalKeyboardSeen = true;
      try {
        sessionStorage.setItem("carambus_physical_keyboard", "1");
      } catch (e) {
        // s.o. — die Erkennung gilt dann nur fuer diese Seite.
      }

      // Steht sie gerade offen, verschwindet sie sofort. Bewusst nicht ueber close():
      // das setzt zusaetzlich die Event-Handler zurueck und haengt an zwei freien
      // Variablen (oninput/onclose), die nur zufaellig auf window aufloesen. Hier
      // reicht Ausblenden — der Wert im Feld bleibt, wo er ist.
      if (Keyboard.elements.main) {
        Keyboard.elements.main.classList.add("keyboard--hidden");
      }
    }, true);
  },

  _setupKeyboard(type) {
    Keyboard.keyboard_type = type;

    // Beim Ebenenwechsel zeigt capsKeyElement sonst auf ein Element, das gleich aus
    // dem DOM fliegt — und in einer Ebene ohne Caps-Taste (numeric, symbols) bliebe
    // die alte Referenz stehen. Zuruecksetzen; `case "caps"` setzt sie neu, wo es
    // eine gibt. Der capsLock-Zustand geht mit, sonst widersprechen sich Anzeige
    // und Verhalten nach dem Wechsel.
    Keyboard.capsKeyElement = "";
    Keyboard.properties.capsLock = false;

    Keyboard.elements.keysContainer.innerHTML = "";
    Keyboard.elements.keysContainer.appendChild(Keyboard._createKeys(type));

    // Tastenliste neu einlesen. Bis 2026-09-10 geschah das NUR in init(); nach jedem
    // Ebenenwechsel arbeitete _toggleCapsLock damit auf Elementen, die nicht mehr im
    // DOM hingen — die Umschaltung blieb wirkungslos. Faellt erst bei mehreren Ebenen
    // auf, deshalb lag es lange unbemerkt.
    Keyboard.elements.keys = Keyboard.elements.keysContainer.querySelectorAll(".keyboard__key");
  },

  // Wechselt zwischen Buchstaben- und Symbolebene. Der eingegebene Wert lebt in
  // properties.value und bleibt dabei unberuehrt — nur die Tasten werden neu gebaut.
  _switchLayer(type) {
    Keyboard._setupKeyboard(type);
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
      //
      // `@` steht bewusst in DIESER Ebene, nicht nur unter "?123": Die Anmeldung
      // laeuft ueber die E-Mail-Adresse, `@` ist dort kein Sonderzeichen, sondern
      // Pflicht. Es hat den Platz von `!` uebernommen (das jetzt unter "?123"
      // liegt) — dadurch bleibt die Zeilenlaenge gleich. `!` war zugleich der
      // Zeilenumbruch-Marker; siehe breakAfter weiter unten.
      keyLayout = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "ß", "?", "backspace",
        "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "ü", "+",
        "a", "s", "d", "f", "g", "h", "j", "k", "l", "ö", "ä", "enter",
        "caps", "z", "x", "c", "v", "b", "n", "m", ",", ".", "-", "@", "done",
        "symbols", "space", "_"
      ];
    }

    // Symbolebene (2026-09-10). Erreichbar ueber "?123", zurueck ueber "ABC".
    //
    // Zeilenumbrueche hier ausschliesslich ueber explizite "br"-Eintraege, nicht
    // ueber die zeichenbasierte Liste der Buchstabenebene: `+` und `!` stehen dort
    // als Umbruch-Marker und kommen hier als normale Zeichen vor — sie wuerden das
    // Raster sonst mitten in der Zeile zerreissen.
    if (keyboard_type == "symbols") {
      keyLayout = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "backspace", "br",
        "@", "#", "$", "€", "%", "&", "*", "(", ")", "+", "br",
        "-", "_", "=", "/", "\\", ":", ";", "\"", "'", "~", "br",
        "abc", "!", "?", "<", ">", "[", "]", "{", "}", "|", "§", "done", "br",
        "space"
      ];
    }


    // Creates HTML for an icon
    const createIconHTML = (icon_name) => {
      return `<i class="material-icons">${icon_name}</i>`;
    };

    // Die Buchstabenebene bricht an festen Zeichen um; die Symbolebene nutzt
    // ausschliesslich explizite "br"-Marker (Begruendung oben am Layout).
    const breakAfter = keyboard_type == "symbols"
      ? ["br"]
      : ["backspace", "+", "enter", "@", "br"];

    keyLayout.forEach(key => {
      const keyElement = document.createElement("button");
      const insertLineBreak = breakAfter.indexOf(key) !== -1;

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

        case "symbols":
          keyElement.classList.add("keyboard__key--wide");
          keyElement.textContent = "?123";

          keyElement.addEventListener("click", () => {
            Keyboard._switchLayer("symbols");
          });

          break;

        case "abc":
          keyElement.classList.add("keyboard__key--wide");
          keyElement.textContent = "ABC";

          keyElement.addEventListener("click", () => {
            Keyboard._switchLayer("alfa");
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
            // Ebenen ohne Caps-Taste (numeric, symbols) haben kein capsKeyElement —
            // der Initialwert ist "", und "".classList wirft. Bis 2026-09-10 lag der
            // Fehler latent: er trifft jede Ziffer, die als ERSTES nach dem Laden in
            // einem input[type=number] getippt wird.
            if (Keyboard.capsKeyElement) {
              Keyboard.capsKeyElement.classList.remove("keyboard__key--active");
            }
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
