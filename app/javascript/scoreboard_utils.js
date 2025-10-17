// Scoreboard Utilities
// Shared functions for scoreboard pages

// Make tryResizeWindow globally available for all scoreboard/monitor pages
function tryResizeWindow() {
  // Check if we're currently in fullscreen
  const isFullscreen = !!(
    document.fullscreenElement || 
    document.webkitFullscreenElement || 
    document.mozFullScreenElement || 
    document.msFullscreenElement
  );

  console.log("🖥️ Toggle fullscreen - currently:", isFullscreen ? "FULLSCREEN" : "WINDOWED");

  if (isFullscreen) {
    // Exit fullscreen mode
    console.log("🖥️ Attempting to EXIT fullscreen...");
    
    // Try browser API (should work now that we removed wmctrl)
    try {
      if (document.exitFullscreen) {
        document.exitFullscreen();
      } else if (document.webkitExitFullscreen) {
        document.webkitExitFullscreen();
      } else if (document.mozCancelFullScreen) {
        document.mozCancelFullScreen();
      } else if (document.msExitFullscreen) {
        document.msExitFullscreen();
      }
      console.log("✅ Browser API exit fullscreen called");
    } catch (e) {
      console.log("❌ Browser API exit failed:", e);
    }

  } else {
    // Enter fullscreen mode
    console.log("🖥️ Attempting to ENTER fullscreen...");
    
    // Try to resize the window to the screen size first (helps on some systems)
    try {
      window.resizeTo(window.screen.width, window.screen.height);
      window.moveTo(0, 0);
      console.log("✅ Window resized to screen size");
    } catch (e) {
      console.log("❌ resizeTo/moveTo failed:", e);
    }

    // Try browser API
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
      console.log("✅ Browser API enter fullscreen called");
    } catch (e) {
      console.log("❌ Browser API enter failed:", e);
    }
  }
}
window.tryResizeWindow = tryResizeWindow; 