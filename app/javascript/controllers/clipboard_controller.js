import { Controller } from "@hotwired/stimulus"
import ClipboardJS from "clipboard"

export default class extends Controller {
  connect() {
    this.clipboard = new ClipboardJS(this.element)
    
    this.clipboard.on('success', (e) => {
      const originalText = e.trigger.textContent
      const successContent = this.element.dataset.clipboardSuccessContent || 'Copied!'
      
      e.trigger.textContent = successContent
      
      setTimeout(() => {
        e.trigger.textContent = originalText
      }, 2000)
      
      e.clearSelection()
    })
    
    this.clipboard.on('error', (e) => {
      console.error('Clipboard error:', e.action)
    })
  }
  
  disconnect() {
    if (this.clipboard) {
      this.clipboard.destroy()
    }
  }
} 