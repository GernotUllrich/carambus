import CableReady from 'cable_ready'

const enableAlpine = (options, fromEl, toEl) => {
  if (fromEl.__x) {
    window.Alpine.clone(fromEl.__x, toEl)
  }
  return true
}

CableReady.shouldMorphCallbacks.push(enableAlpine)

import { Turbo } from "@hotwired/turbo-rails"

Turbo.setProgressBarDelay(Infinity)

