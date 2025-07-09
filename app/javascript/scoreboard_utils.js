// Scoreboard Utilities
// Shared functions for scoreboard pages

function tryResizeWindow() {
  console.log("Trying to resize window programmatically...");
  
  // Method 1: Try to resize window via window.resizeTo
  try {
    const screenWidth = window.screen.width;
    const screenHeight = window.screen.height;
    console.log("Screen size: " + screenWidth + "x" + screenHeight);
    
    window.resizeTo(screenWidth, screenHeight);
    window.moveTo(0, 0);
    console.log("Window resized to screen size");
  } catch (e) {
    console.log("Window resize failed: " + e.message);
  }
  
  // Method 2: Try to enter fullscreen via API
  setTimeout(() => {
    try {
      console.log("Trying to enter fullscreen after resize...");
      if (document.documentElement.requestFullscreen) {
        document.documentElement.requestFullscreen();
      } else if (document.documentElement.webkitRequestFullscreen) {
        document.documentElement.webkitRequestFullscreen();
      }
      console.log("Fullscreen API called after resize");
    } catch (e) {
      console.log("Fullscreen after resize failed: " + e.message);
    }
  }, 500);
  
  // Method 3: Try to click on maximize button area
  setTimeout(() => {
    try {
      console.log("Trying to click maximize button area...");
      const maximizeClick = new MouseEvent("click", {
        bubbles: true,
        cancelable: true,
        view: window,
        clientX: window.innerWidth - 30,
        clientY: 15
      });
      document.dispatchEvent(maximizeClick);
      console.log("Maximize button click sent");
    } catch (e) {
      console.log("Maximize button click failed: " + e.message);
    }
  }, 1000);
}

// Make function globally available
window.tryResizeWindow = tryResizeWindow; 