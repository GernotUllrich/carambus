// Scoreboard Utilities
// Shared functions for scoreboard pages

// Make tryResizeWindow globally available for all scoreboard/monitor pages
function tryResizeWindow() {
  // Try to resize the window to the screen size
  try {
    window.resizeTo(window.screen.width, window.screen.height);
    window.moveTo(0, 0);
  } catch (e) {
    // Some browsers may block this in kiosk/app mode
    console.log("resizeTo/moveTo failed:", e);
  }

  // Try to enter fullscreen via the browser API
  try {
    if (document.documentElement.requestFullscreen) {
      document.documentElement.requestFullscreen();
    } else if (document.documentElement.webkitRequestFullscreen) {
      document.documentElement.webkitRequestFullscreen();
    } else if (document.documentElement.mozRequestFullScreen) {
      document.documentElement.mozRequestFullScreen();
    } else if (document.documentElement.msRequestFullscreen) {
      document.documentElement.msRequestFullscreen();
    }
  } catch (e) {
    console.log("Fullscreen API failed:", e);
  }
}
window.tryResizeWindow = tryResizeWindow; 