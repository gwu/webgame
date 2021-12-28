module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
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
    , onUrlRequest = LinkClicked
    }



-- MODEL


type alias Model =
  { key : Nav.Key
  , route : Route
  }


type Route
  = Home
  | Servers
  | NotFound


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
  ( Model key (parseRoute url), Cmd.none )



-- UPDATE


type Msg
  = LinkClicked Browser.UrlRequest
  | UrlChanged Url.Url


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    LinkClicked urlRequest ->
      case urlRequest of
        Browser.Internal url ->
          ( model, Nav.pushUrl model.key (Url.toString url) )

        Browser.External href ->
          ( model, Nav.load href )

    UrlChanged url ->
      ( { model | route = parseRoute url }
      , Cmd.none
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
    Just "servers" ->
      Servers
    Nothing ->
      Home
    _ ->
      NotFound



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
  Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
  { title = "Web Game"
  , body =
    [ div [] [ text "Hello, world!" ]
    ]
  }


routeName : Route -> String
routeName route =
  case route of
    Home ->
      "Home"

    Servers ->
      "Servers"

    NotFound ->
      "Not Found"
