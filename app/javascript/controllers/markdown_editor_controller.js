import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "preview", "previewButton", "editButton"]
  
  connect() {
    console.log("Markdown editor controller connected")
  }
  
  showPreview() {
    const markdownContent = this.editorTarget.value
    
    fetch('/pages/preview', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ content: markdownContent })
    })
    .then(response => response.json())
    .then(data => {
      this.previewTarget.innerHTML = data.html
      this.previewTarget.classList.remove('hidden')
      this.editorTarget.classList.add('hidden')
      this.previewButtonTarget.classList.add('hidden')
      this.editButtonTarget.classList.remove('hidden')
    })
  }
  
  showEditor() {
    this.previewTarget.classList.add('hidden')
    this.editorTarget.classList.remove('hidden')
    this.previewButtonTarget.classList.remove('hidden')
    this.editButtonTarget.classList.add('hidden')
  }
} 