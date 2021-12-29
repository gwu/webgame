import './index.css'
import { Elm } from './Main.elm'
import loadjs from 'loadjs'

const app = Elm.Main.init()

type GapiData = (
  GapiCurrentUser |
    GapiGameRooms
)

interface GapiCurrentUser {
  type: 'currentUser'
  user: null | SignedInUser
}

interface GapiGameRooms {
  type: 'gameRooms'
  rooms: GapiGameRoom[]
}

interface GapiGameRoom {
  id: string
  name: string
}

interface SignedInUser {
  id: string
  email: string
  name: string
  imageUrl: string
}

type GapiMessage = (
  GapiMessage$Load |
    GapiMessage$SignIn |
    GapiMessage$SignOut |
    GapiMessage$LoadGameRooms |
    GapiMessage$CreateGameRoom
)

interface GapiMessage$Load {
  command: 'load'
}

interface GapiMessage$SignIn {
  command: 'signIn'
}

interface GapiMessage$SignOut {
  command: 'signOut'
}

interface GapiMessage$LoadGameRooms {
  command: 'loadGameRooms'
}

interface GapiMessage$CreateGameRoom {
  command: 'createGameRoom'
  name: string
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
    case 'loadGameRooms': {
      return handleGapiLoadGameRooms()
    }
    case 'createGameRoom': {
      return handleGapiCreateGameRoom(msg.name)
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

    const discoveryDocs = [
      'https://sheets.googleapis.com/$discovery/rest?version=v4',
      'https://www.googleapis.com/discovery/v1/apis/drive/v3/rest'
    ]

    // Enter a client ID for a web application from the Google API Console:
    //   https://console.developers.google.com/apis/credentials?project=_
    // In your API Console project, add a JavaScript origin that corresponds
    //   to the domain where you will be running the script.
    const clientId = '125968645830-o3dha59lhl1vf4n0gq6bl1it1b2es0m8.apps.googleusercontent.com'

    // Enter one or more authorization scopes. Refer to the documentation for
    // the API or https://developers.google.com/people/v1/how-tos/authorizing
    // for details.
    const scope = [
      'profile',
      'https://www.googleapis.com/auth/drive.file'
    ].join(' ')

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
            const data: GapiData = {
              type: 'currentUser',
              user: currentUser.isSignedIn()
                ? {
                  id: currentUser.getBasicProfile().getId(),
                  email: currentUser.getBasicProfile().getEmail(),
                  name: currentUser.getBasicProfile().getName(),
                  imageUrl: currentUser.getBasicProfile().getImageUrl()
                }
                : null
            }
            app.ports.gapiReceive.send(data)
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

function handleGapiLoadGameRooms (): void {
  const propKey = 'type'
  const propValue = 'room'
  gapi.client.drive.files
    .list({
      spaces: 'drive',
      q: `appProperties has { key='${propKey}' and value='${propValue}' }`
    })
    .then((fileList) => {
      const files = fileList.result.files ?? []
      const rooms = files
        .map((f) => f.id !== undefined && f.name !== undefined ? [f.id, f.name] : false)
        .filter((f): f is [string, string] => f !== false)
        .map(([id, name]) => ({ id, name }))
      const data: GapiData = {
        type: 'gameRooms',
        rooms
      }
      app.ports.gapiReceive.send(data)
    })
}

function handleGapiCreateGameRoom (name: string): void {
  console.log('Create game room ' + name)

  // We store all of the game rooms in Google Drive
  // Each Google Sheet tagged with type=room corresponds to a room.
  // Each Sheet within the Spreadsheet is a game.
  // Data in the sheet keeps track of the game state.

  // Therefore:
  // - Searching the drive for tagged sheets is how you find rooms.
  // - Sharing the sheets is how you make the room accessible.
  gapi.client.sheets.spreadsheets
    .create({
    }, {
      properties: {
        title: name
      }
    })
    .then((response) => {
      const fileId = response.result.spreadsheetId
      if (fileId === undefined) {
        throw new Error('Unable to get file id')
      }
      return gapi.client.drive.files.update({
        fileId
      }, {
        appProperties: {
          type: 'room'
        }
      })
    })
    .then(() => {
      handleGapiLoadGameRooms()
    })
    .catch((err) => {
      console.log(err)
    })

  // TODO: Handle errors.
}
