import loadjs from 'loadjs'

// Methods

export type Method = (
  Init |
    SignIn |
    SignOut |
    LoadRooms |
    CreateRoom |
    ShareRoom
)
export function isMethod (obj: any): obj is Method {
  return isInit(obj) ||
    isSignIn(obj) ||
    isSignOut(obj) ||
    isLoadRooms(obj) ||
    isCreateRoom(obj) ||
    isShareRoom(obj)
}

export interface Init {
  command: 'init'
}
export function isInit (obj: any): obj is Init {
  return obj?.command === 'init'
}

export interface SignIn {
  command: 'signIn'
}
export function isSignIn (obj: any): obj is SignIn {
  return obj?.command === 'signIn'
}

export interface SignOut {
  command: 'signOut'
}
export function isSignOut (obj: any): obj is SignOut {
  return obj?.command === 'signOut'
}

export interface LoadRooms {
  command: 'loadRooms'
}
export function isLoadRooms (obj: any): obj is LoadRooms {
  return obj?.command === 'loadRooms'
}

export interface CreateRoom {
  command: 'createRoom'
  name: string
}
export function isCreateRoom (obj: any): obj is CreateRoom {
  return obj?.command === 'createRoom' &&
    typeof obj?.name === 'string'
}

export interface ShareRoom {
  command: 'shareRoom'
  roomId: string
  userEmail: string
}
export function isShareRoom (obj: any): obj is ShareRoom {
  return obj?.command === 'shareRoom' &&
    typeof obj?.roomId === 'string' &&
    typeof obj?.userEmail === 'string'
}

// Channel Data

export type Channel = (data: Data) => void

export type Data = CurrentUser | Rooms

export interface CurrentUser {
  type: 'currentUser'
  user: null | SignedInUser
}

export interface Rooms {
  type: 'rooms'
  rooms: Room[]
}

export interface Room {
  id: string
  name: string
}

export interface SignedInUser {
  id: string
  email: string
  name: string
  imageUrl: string
}

export async function call (method: Method, channel: Channel): Promise<void> {
  switch (method.command) {
    case 'init': {
      return await init(channel)
    }
    case 'signIn': {
      return await signIn()
    }
    case 'signOut': {
      return await signOut()
    }
    case 'loadRooms': {
      return await loadRooms(channel)
    }
    case 'createRoom': {
      return await createRoom(method.name, channel)
    }
    case 'shareRoom': {
      return await shareRoom(method.roomId, method.userEmail)
    }
    default: {
      const exhaustiveCheck: never = method
      throw new Error(`Unhandled method ${JSON.stringify(exhaustiveCheck)}`)
    }
  }
}

async function init (channel: Channel): Promise<void> {
  loadjs('https://apis.google.com/js/api.js', () => {
    const apiKey = 'AIzaSyDt8wWjIsQI0eixi3zKKHrJYcfvv4QIxys'
    const discoveryDocs = [
      'https://sheets.googleapis.com/$discovery/rest?version=v4',
      'https://www.googleapis.com/discovery/v1/apis/drive/v3/rest'
    ]
    const clientId = '125968645830-o3dha59lhl1vf4n0gq6bl1it1b2es0m8.apps.googleusercontent.com'
    const scopes = [
      'profile',
      'https://www.googleapis.com/auth/drive.file'
    ]
    const scope = scopes.join(' ')

    gapi.load('client:auth2', async () => {
      await gapi.client.init({
        apiKey,
        discoveryDocs,
        clientId,
        scope
      })

      const authInstance = gapi.auth2.getAuthInstance()
      authInstance.currentUser.listen(onCurrentUserChanged)
      onCurrentUserChanged(authInstance.currentUser.get())
      function onCurrentUserChanged (currentUser: gapi.auth2.GoogleUser): void {
        const data: CurrentUser = {
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
        channel(data)
      }
    })
  })
}

async function signIn (): Promise<void> {
  await gapi.auth2.getAuthInstance().signIn()
}

async function signOut (): Promise<void> {
  await gapi.auth2.getAuthInstance().signOut()
}

async function loadRooms (channel: Channel): Promise<void> {
  const propKey = 'type'
  const propValue = 'room'
  gapi.client.drive.files
    .list({
      spaces: 'drive',
      q: `appProperties has { key='${propKey}' and value='${propValue}' }`
    })
    .then((fileList) => {
      const files = fileList.result.files ?? []
      const rooms: Room[] = files
        .map((f) => f.id !== undefined && f.name !== undefined ? [f.id, f.name] : false)
        .filter((f): f is [string, string] => f !== false)
        .map(([id, name]): Room => ({ id, name }))
      const data: Data = {
        type: 'rooms',
        rooms
      }
      channel(data)
    })
}

async function createRoom (name: string, channel: Channel): Promise<void> {
  const response = await gapi.client.sheets.spreadsheets.create(
    {},
    {
      properties: {
        title: name
      }
    }
  )
  const fileId = response.result.spreadsheetId
  if (fileId === undefined) {
    throw new Error('Unable to get file id')
  }
  await gapi.client.drive.files.update(
    {
      fileId
    },
    {
      appProperties: {
        type: 'room'
      }
    }
  )
  await loadRooms(channel)
}

async function shareRoom (roomId: string, userEmail: string): Promise<void> {
  // TODO
}
