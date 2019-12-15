module Main exposing (..)
import Browser
import Html exposing (..)
import Debug exposing (toString)
import Http
import Json.Decode exposing (Decoder, field, string, float, Error)
import Time exposing (Posix)


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
    distance : Float,
    date: Posix
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
        (List.map (\l -> li [] [text (toUtcString l.date ++ " - " ++ toString (truncate l.distance) ++ "km")]) lst)

toUtcString : Time.Posix -> String
toUtcString time =
  String.fromInt (Time.toDay Time.utc time)
  ++ ". " ++
  toString (Time.toMonth Time.utc time)
  ++ " " ++
  String.fromInt (Time.toYear Time.utc time)


-- HTTP


decodeTime : Decoder Time.Posix
decodeTime =
    Json.Decode.int
        |> Json.Decode.andThen
            (\ms ->
                Json.Decode.succeed <| Time.millisToPosix ms
            )

routeDecoder : Decoder Route
routeDecoder =
    Json.Decode.map3 Route
        (field "id" string)
        (field "distance" float)
        (field "start_date" decodeTime)

routeListDecoder : Decoder (List Route)
routeListDecoder =
    Json.Decode.list routeDecoder


getRoutes : Cmd Msg
getRoutes =
    Http.get
        { url = "http://127.0.0.1:5000/routes"
        , expect = Http.expectJson GotRoutes routeListDecoder
        }

