port module Main exposing (gapiReceive, gapiSend, main)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events
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



-- MODEL


type alias Model =
    { key : Nav.Key
    , route : Route
    , currentUser : Maybe CurrentUser
    }


type Route
    = Home
    | Servers
    | NotFound


type CurrentUser
    = SignedOut
    | SignedIn SignedInUser


type alias SignedInUser =
    { id : String
    , email : String
    , name : Maybe String
    , imageUrl : String
    }


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( Model key (parseRoute url) Nothing, sendGapiMessage GapiMessageLoad )



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url
    | GapiMessageReceived Json.Decode.Value
    | SignIn
    | SignOut


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
                gapiMessageDecoder =
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
            in
            ( { model
                | currentUser =
                    parseDecodingResult (Json.Decode.decodeValue gapiMessageDecoder gapiMessage)
              }
            , Cmd.none
            )

        SignIn ->
            ( model, sendGapiMessage GapiMessageSignIn )

        SignOut ->
            ( model, sendGapiMessage GapiMessageSignOut )


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

        Just "servers" ->
            Servers

        Nothing ->
            Home

        _ ->
            NotFound



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
