import './index.css'
import { Elm } from './Main.elm'
import * as Api from './api'

const app = Elm.Main.init()

app.ports.apiPort.subscribe((method: any) => {
  if (!Api.isMethod(method)) {
    throw new Error(`Expected method but found ${JSON.stringify(method)}`)
  }

  Api.call(method, app.ports.dataPort.send)
})
