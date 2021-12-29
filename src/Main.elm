port module Main exposing (gapiReceive, gapiSend, main)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events
import Html.Keyed
import Json.Decode
import Json.Encode
import Url
import Url.Parser as UP



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }



-- PORTS


port gapiSend : Json.Encode.Value -> Cmd msg


port gapiReceive : (Json.Encode.Value -> msg) -> Sub msg


type GapiMessage
    = GapiMessageLoad
    | GapiMessageSignIn
    | GapiMessageSignOut
    | GapiMessageLoadGameRooms
    | GapiMessageCreateGameRoom String


sendGapiMessage : GapiMessage -> Cmd msg
sendGapiMessage gapiMessage =
    gapiSend (encodeGapiMessage gapiMessage)


encodeGapiMessage : GapiMessage -> Json.Encode.Value
encodeGapiMessage gapiMessage =
    case gapiMessage of
        GapiMessageLoad ->
            Json.Encode.object
                [ ( "command", Json.Encode.string "load" )
                ]

        GapiMessageSignIn ->
            Json.Encode.object
                [ ( "command", Json.Encode.string "signIn" )
                ]

        GapiMessageSignOut ->
            Json.Encode.object
                [ ( "command", Json.Encode.string "signOut" )
                ]

        GapiMessageLoadGameRooms ->
            Json.Encode.object
                [ ( "command", Json.Encode.string "loadGameRooms" )
                ]

        GapiMessageCreateGameRoom name ->
            Json.Encode.object
                [ ( "command", Json.Encode.string "createGameRoom" )
                , ( "name", Json.Encode.string name )
                ]



-- MODEL


type alias Model =
    { key : Nav.Key
    , route : Route
    , currentUser : Maybe CurrentUser
    , gameRooms : Maybe (List GameRoom)
    , gameRoomDialog : GameRoomDialogState
    }


type Route
    = Home
    | Room String
    | NotFound


type GapiData
    = UserData CurrentUser
    | GameRoomData (List GameRoom)


type CurrentUser
    = SignedOut
    | SignedIn SignedInUser


type alias SignedInUser =
    { id : String
    , email : String
    , name : Maybe String
    , imageUrl : String
    }


type alias GameRoom =
    { id : String
    , name : String
    }


type GameRoomDialogState
    = GameRoomDialogClosed
    | GameRoomDialogOpened String


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( Model key (parseRoute url) Nothing Nothing GameRoomDialogClosed
    , sendGapiMessage GapiMessageLoad
    )



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url
    | GapiMessageReceived Json.Decode.Value
    | SignIn
    | SignOut
    | LoadGameRooms
    | CreateGameRoomDialogOpen
    | CreateGameRoomDialogClose
    | CreateGameRoomDialogNameChange String
    | CreateGameRoom String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequested req ->
            case req of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | route = parseRoute url }
            , Cmd.none
            )

        GapiMessageReceived gapiMessage ->
            let
                decodeByType : String -> Json.Decode.Decoder GapiData
                decodeByType t =
                    case t of
                        "currentUser" ->
                            Json.Decode.map
                                UserData
                                (Json.Decode.field "user" currentUserMessageDecoder)

                        "gameRooms" ->
                            Json.Decode.map
                                GameRoomData
                                (Json.Decode.field
                                    "rooms"
                                    (Json.Decode.list
                                        (Json.Decode.map2
                                            GameRoom
                                            (Json.Decode.field "id" Json.Decode.string)
                                            (Json.Decode.field "name" Json.Decode.string)
                                        )
                                    )
                                )

                        _ ->
                            Json.Decode.fail "Unhandled type"

                gapiMessageDecoder =
                    Json.Decode.andThen
                        decodeByType
                        (Json.Decode.field "type" Json.Decode.string)

                currentUserMessageDecoder =
                    Json.Decode.map
                        (Maybe.withDefault SignedOut)
                        (Json.Decode.nullable
                            (Json.Decode.map
                                SignedIn
                                (Json.Decode.map4
                                    SignedInUser
                                    (Json.Decode.field "id" Json.Decode.string)
                                    (Json.Decode.field "email" Json.Decode.string)
                                    (Json.Decode.field "name" (Json.Decode.maybe Json.Decode.string))
                                    (Json.Decode.field "imageUrl" Json.Decode.string)
                                )
                            )
                        )

                parseDecodingResult result =
                    Result.toMaybe result

                parsedMessage =
                    parseDecodingResult (Json.Decode.decodeValue gapiMessageDecoder gapiMessage)
            in
            case parsedMessage of
                Just (UserData currentUser) ->
                    ( { model | currentUser = Just currentUser }
                    , case currentUser of
                        SignedIn _ ->
                            sendGapiMessage GapiMessageLoadGameRooms

                        _ ->
                            Cmd.none
                    )

                Just (GameRoomData gameRooms) ->
                    ( { model | gameRooms = Just gameRooms }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        SignIn ->
            ( model, sendGapiMessage GapiMessageSignIn )

        SignOut ->
            ( model, sendGapiMessage GapiMessageSignOut )

        LoadGameRooms ->
            ( model, sendGapiMessage GapiMessageLoadGameRooms )

        CreateGameRoomDialogOpen ->
            ( { model | gameRoomDialog = GameRoomDialogOpened "" }
            , Cmd.none
            )

        CreateGameRoomDialogClose ->
            ( { model | gameRoomDialog = GameRoomDialogClosed }
            , Cmd.none
            )

        CreateGameRoomDialogNameChange name ->
            ( { model | gameRoomDialog = GameRoomDialogOpened name }
            , Cmd.none
            )

        CreateGameRoom name ->
            ( { model | gameRoomDialog = GameRoomDialogClosed }
            , sendGapiMessage (GapiMessageCreateGameRoom name)
            )


parseRoute : Url.Url -> Route
parseRoute url =
    Maybe.withDefault NotFound (UP.parse routeParser url)


routeParser : UP.Parser (Route -> a) a
routeParser =
    UP.fragment fragmentParser


fragmentParser : Maybe String -> Route
fragmentParser fragment =
    case fragment of
        Just "" ->
            Home

        Just path ->
            case String.split "/" path of
                [ "room", roomId ] ->
                    Room roomId

                _ ->
                    NotFound

        Nothing ->
            Home



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    gapiReceive GapiMessageReceived



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Web Game"
    , body =
        [ div
            [ class "absolute h-full w-full bg-slate-700 overflow-auto text-slate-200" ]
            (case model.currentUser of
                Nothing ->
                    [ text "Loading..." ]

                Just SignedOut ->
                    [ div
                        [ class "h-full flex justify-center items-center" ]
                        [ button [ class "bg-slate-600 px-4 py-2 rounded", Html.Events.onClick SignIn ]
                            [ text "Sign in" ]
                        ]
                    ]

                Just (SignedIn signedInUser) ->
                    [ div
                        [ class "h-full flex justify-center items-center" ]
                        [ div []
                            [ div []
                                [ text (formatUser signedInUser)
                                , img [ src signedInUser.imageUrl, class "w-10 h-10 rounded-full" ] []
                                ]
                            , button
                                [ class "bg-slate-600 px-4 p-2 rounded", Html.Events.onClick SignOut ]
                                [ text "Sign out" ]
                            , Html.Keyed.ul
                                []
                                (List.map viewGameRoom (Maybe.withDefault [] model.gameRooms))
                            , button
                                [ class "bg-purple-600 px-4 p-2 rounded"
                                , Html.Events.onClick CreateGameRoomDialogOpen
                                ]
                                [ text "Create a room" ]
                            , viewCreateRoomDialog model.gameRoomDialog
                            ]
                        ]
                    ]
            )
        ]
    }


formatUser : SignedInUser -> String
formatUser user =
    case user.name of
        Nothing ->
            "<" ++ user.email ++ ">"

        Just name ->
            name ++ " <" ++ user.email ++ ">"


viewGameRoom : GameRoom -> ( String, Html Msg )
viewGameRoom gameRoom =
    ( gameRoom.id
    , li []
        [ a [ href ("#room/" ++ gameRoom.id) ] [ text gameRoom.name ] ]
    )


viewCreateRoomDialog : GameRoomDialogState -> Html Msg
viewCreateRoomDialog dialog =
    case dialog of
        GameRoomDialogClosed ->
            text ""

        GameRoomDialogOpened roomName ->
            div
                [ class "absolute top-0 left-0 w-full h-full bg-slate-600" ]
                [ div [] [ text "Create a room" ]
                , input
                    [ placeholder "Room name"
                    , value roomName
                    , Html.Events.onInput CreateGameRoomDialogNameChange
                    ]
                    []
                , button
                    [ class "bg-slate-500 px-4 py-2 rounded", Html.Events.onClick CreateGameRoomDialogClose ]
                    [ text "Cancel" ]
                , button
                    [ class "bg-slate-500 px-4 py-2 rounded", Html.Events.onClick (CreateGameRoom roomName) ]
                    [ text "Create" ]
                ]
