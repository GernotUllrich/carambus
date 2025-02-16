import consumer from './consumer'

consumer.subscriptions.create('TestChannel', {
  connected () {
    this.send({ message: '********* Test Client is live *******' })
  },

  received (data) {
    console.log(data)
  }
})
