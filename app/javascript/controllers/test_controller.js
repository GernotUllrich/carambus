import { Controller } from "@hotwired/stimulus"

export default class TestController extends Controller {
  static targets = ["output"]
  
  connect() {
    console.log('TestController: Connected!')
    console.log('TestController: Element:', this.element)
    console.log('TestController: Targets:', this.hasOutputTarget ? 'output target found' : 'no output target')
    console.log('TestController: Available actions:', this.element.dataset)
  }
  
  test(event) {
    console.log('TestController: Test action called!')
    console.log('TestController: Event:', event)
    console.log('TestController: Current element:', event.currentTarget)
  }
} 