module Api exposing (Room, User)

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
