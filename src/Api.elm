module Api exposing (Room, User, createRoom, init, loadRooms, signIn, signOut)

import Json.Encode as Encode


type alias Room =
    { id : String
    , name : String
    }


type alias User =
    { id : String
    , email : String
    , name : String
    , imageUrl : String
    }


init : (Encode.Value -> a) -> a
init sendPort =
    sendPort
        (Encode.object
            [ ( "command", Encode.string "load" ) ]
        )


signIn : (Encode.Value -> a) -> a
signIn sendPort =
    sendPort
        (Encode.object
            [ ( "command", Encode.string "signIn" ) ]
        )


signOut : (Encode.Value -> a) -> a
signOut sendPort =
    sendPort
        (Encode.object
            [ ( "command", Encode.string "signOut" ) ]
        )


loadRooms : (Encode.Value -> a) -> a
loadRooms sendPort =
    sendPort
        (Encode.object
            [ ( "command", Encode.string "loadGameRooms" ) ]
        )


createRoom : String -> (Encode.Value -> a) -> a
createRoom name sendPort =
    sendPort
        (Encode.object
            [ ( "command", Encode.string "createGameRoom" )
            , ( "name", Encode.string name )
            ]
        )
