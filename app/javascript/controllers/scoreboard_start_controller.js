document.addEventListener('turbo:load', function () {
  console.log('Window.hotkeys in view:', window.hotkeys); // Check availability
  if (!window.hotkeys) {
    console.error('Hotkeys not available!');
    return;
  }
  let current_element = document.activeElement.getAttribute("id");
  console.log("active: " + current_element);
  if (current_element == null) {
    current_element = "tournament";
    console.log("active now: " + current_element);
    document.getElementById(current_element).focus();
  }
  // backspace, tab, clear, enter, return, esc, escape, space, up, down, left, right, home, end, pageup, pagedown, del, delete and f1 through f19
  window.hotkeys('*', function (event) {
// Prevent the default refresh event under WINDOWS system

    //console.log(hotkeys.getPressedKeyCodes());
    //alert('you pressed ' + hotkeys.getPressedKeyCodes());
    const keyMap = {
      33: "key_a",
      37: "key_a",
      34: "key_b",
      39: "key_b",
      66: "key_c",
      38: "key_c",
      116: "key_d",
      27: "key_d",
      40: "key_d",
      13: "key_d",
    };
    const tabbed_elements = {
      "tournament": "training",
      "training": "tournament",
    };
    let current_element = document.activeElement.getAttribute("id");
    console.log("active: " + current_element);
    if (current_element == null) {
      current_element = "tournament";
      console.log("active now: " + current_element);
      document.getElementById(current_element).focus();
    }

    if (event.key in keyMap) {
      let key = keyMap[event.key];
      if (key === "key_c") {
        window.history.back();
      }
      if (key === "key_b") {
        current_element = document.activeElement.getAttribute("id")
        console.log("active becomes (b): " + tabbed_elements[current_element]);
        document.getElementById(tabbed_elements[current_element]).focus();
      }
      if (key === "key_a") {
        current_element = document.activeElement.getAttribute("id");
        for (let k in tabbed_elements) {
          if (tabbed_elements[k] === current_element) {
            console.log("active becomes (a): " + k);
            document.getElementById(k).focus();
            break;
          }
        }
      }
      if (key === "key_d") {
        console.log("activate: " + document.activeElement.getAttribute("id"));
        document.activeElement.click();
      }
    }
    event.preventDefault();
    return true
  });
});
