import './index.css'
import { Elm } from './Main.elm'
import loadjs from 'loadjs'

const app = Elm.Main.init()

type GapiMessage = GapiMessage$Load | GapiMessage$SignIn | GapiMessage$SignOut

interface GapiMessage$Load {
  command: 'load'
}

interface GapiMessage$SignIn {
  command: 'signIn'
}

interface GapiMessage$SignOut {
  command: 'signOut'
}

app.ports.gapiSend.subscribe((msg: GapiMessage) => {
  switch (msg.command) {
    case 'load': {
      return handleGapiLoad()
    }
    case 'signIn': {
      return handleGapiSignIn()
    }
    case 'signOut': {
      return handleGapiSignOut()
    }
    default: {
      const exhaustiveCheck: never = msg
      throw new Error(`Unhandled gapi message ${JSON.stringify(exhaustiveCheck)}`)
    }
  }
})

function handleGapiLoad (): void {
  loadjs('https://apis.google.com/js/api.js', () => {
    const apiKey = 'AIzaSyDt8wWjIsQI0eixi3zKKHrJYcfvv4QIxys'

    // Enter the API Discovery Docs that describes the APIs you want to
    // access. In this example, we are accessing the People API, so we load
    // Discovery Doc found here: https://developers.google.com/people/api/rest/
    const discoveryDocs = ['https://people.googleapis.com/$discovery/rest?version=v1']

    // Enter a client ID for a web application from the Google API Console:
    //   https://console.developers.google.com/apis/credentials?project=_
    // In your API Console project, add a JavaScript origin that corresponds
    //   to the domain where you will be running the script.
    const clientId = '125968645830-o3dha59lhl1vf4n0gq6bl1it1b2es0m8.apps.googleusercontent.com'

    // Enter one or more authorization scopes. Refer to the documentation for
    // the API or https://developers.google.com/people/v1/how-tos/authorizing
    // for details.
    const scope = 'profile'

    gapi.load('client:auth2', () => {
      gapi.client
        .init({
          apiKey,
          discoveryDocs,
          clientId,
          scope
        })
        .then(() => {
          const authInstance = gapi.auth2.getAuthInstance()
          authInstance.currentUser.listen(onCurrentUserChanged)
          onCurrentUserChanged(authInstance.currentUser.get())
          function onCurrentUserChanged (currentUser: gapi.auth2.GoogleUser): void {
            app.ports.gapiReceive.send(
              currentUser.isSignedIn()
                ? {
                  uid: currentUser.getBasicProfile().getId(),
                  email: currentUser.getBasicProfile().getEmail(),
                  name: currentUser.getBasicProfile().getName()
                }
                : null
            )
          }
        })
    })
  })
}

function handleGapiSignIn (): void {
  gapi.auth2.getAuthInstance().signIn()
}

function handleGapiSignOut (): void {
  gapi.auth2.getAuthInstance().signOut()
}
