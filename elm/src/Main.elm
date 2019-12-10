module Main exposing (..)
import Browser
import Html exposing (..)
import Debug exposing (toString)
import Http
import Json.Decode exposing (Decoder, field, string, float, Error)



-- MAIN


main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }



-- MODEL


-- Model type with possible states
type Model
  = Failure Http.Error
  | Loading
  | Success (List Route)


-- Route Class
type alias Route =
    {
    id : String,
    distance : Float
    }


init : () -> (Model, Cmd Msg)
init _ =
  (Loading, getRoutes)


-- UPDATE


type Msg
  = MorePlease
  | GotRoutes (Result Http.Error (List Route))


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    MorePlease ->
      (Loading, getRoutes)

    GotRoutes result ->
      case result of
        Ok routes ->
          (Success routes, Cmd.none)

        Err errmsg ->
          (Failure errmsg, Cmd.none)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none



-- VIEW


view : Model -> Html Msg
view model =
  div []
    [ h2 [] [ text "Strava Routes" ]
    , viewRoutes model
    ]


viewRoutes : Model -> Html Msg
viewRoutes model =
    case model of
        Failure error ->
            text (toString error)

        Loading ->
            text "Loading..."

        Success routeList ->
            renderRouteList routeList



renderRouteList : List Route -> Html msg
renderRouteList lst =
    ul []
        (List.map (\l -> li [] [text (l.id ++ "-" ++ toString l.distance)]) lst)


-- HTTP

-- How to decode lists


routeDecoder : Decoder Route
routeDecoder =
    Json.Decode.map2 Route
        (field "id" string)
        (field "distance" float)

routeListDecoder : Decoder (List Route)
routeListDecoder =
    Json.Decode.list routeDecoder


getRoutes : Cmd Msg
getRoutes =
    Http.get
        { url = "http://127.0.0.1:5000/routes"
        , expect = Http.expectJson GotRoutes routeListDecoder
        }

