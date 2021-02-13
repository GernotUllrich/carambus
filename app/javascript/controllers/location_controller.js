import ApplicationController from './application_controller';
import StimulusReflex from 'stimulus_reflex';

export default class extends ApplicationController {

  connect() {
    StimulusReflex.register(this)

    this.colors = {
      default: 'white',
      highlight: '#fef8e8',
      hover: '#fbe7b1'
    }
  }

  dragover(event) {
    event.preventDefault();
    this.hover(event.target);
  }

  dragenter(event) {
    this.hover(event.target);
  }

  dragleave(event) {
    this.highlight(event.target);
  }

  dragstart(event) {
    const locations = document.getElementsByClassName('location-item');

    Array.prototype.forEach.call(locations, (location) => {
      location.style.backgroundColor = this.colors.highlight;
    })

    this.draggable = event.target;
  }

  dragend(event) {
    this.clearHighlights();
  }

  drop(event) {
    const locationItem = this.getLocationItem(event.target);

    if (locationItem) {
      const locationId = locationItem.dataset.locationId;

      if (this.draggable.classList.contains('location-item')) {
        this.stimulate('LocationReflex#move', locationItem, { parent: locationId, location: this.draggable.dataset.locationId })
      }
    }

    this.clearHighlights();
  }

  highlight(element) {
    const locationItem = this.getLocationItem(element);

    if (locationItem) {
      locationItem.style.backgroundColor = this.colors.highlight;
    }
  }

  hover(element) {
    const locationItem = this.getLocationItem(element);

    if (locationItem) {
      locationItem.style.backgroundColor = this.colors.hover;
    }
  }

  clearHighlights() {
    const locations = document.getElementsByClassName('location-item');

    Array.prototype.forEach.call(locations, (location) => {
      location.style.backgroundColor = this.colors.default;
    })
  }

  getLocationItem(element) {
    let locationItem = null;
    let parent = element.parentElement;

    while (parent) {
      if (parent.classList.contains('location-item')) {
        locationItem = parent;
        break;
      }

      parent = parent.parentElement;
    }

    return locationItem
  }

}

