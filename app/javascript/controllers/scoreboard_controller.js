
document.addEventListener('alpine:init', () => {
  Alpine.data('scoreboardGameConfig', () => ({
    multiset: 0,
    games: 0,
    gametime: 0,
    warntime: 0,
    increment: 5,

    initConfig() {
      // Your initialization code
    },
  }))
})
