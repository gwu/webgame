module Api exposing (Room, User, createRoom, init, loadRooms, shareRoom, signIn, signOut)

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
            [ ( "command", Encode.string "init" ) ]
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
            [ ( "command", Encode.string "loadRooms" ) ]
        )


createRoom : String -> (Encode.Value -> a) -> a
createRoom name sendPort =
    sendPort
        (Encode.object
            [ ( "command", Encode.string "createRoom" )
            , ( "name", Encode.string name )
            ]
        )


shareRoom : String -> String -> (Encode.Value -> a) -> a
shareRoom roomId email sendPort =
    sendPort
        (Encode.object
            [ ( "command", Encode.string "shareRoom" )
            , ( "room", Encode.string roomId )
            , ( "email", Encode.string email )
            ]
        )
