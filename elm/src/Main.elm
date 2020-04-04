module Main exposing (..)

import Browser
import Debug exposing (toString)
import Html exposing (..)
import Html.Attributes exposing (class, href, placeholder)
import Html.Events exposing (onInput)
import Http
import Json.Decode exposing (Decoder, Error, field, float, string)
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


type alias RouteFilter =
    Maybe Float


type StravaAPI
    = Failure Http.Error
    | Loading
    | Success (List Route)


type alias Model =
    { status : StravaAPI
    , filter : RouteFilter
    }


type alias Route =
    { id : String
    , distance : Float
    , date : Posix
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Model Loading Nothing, getRoutes )



-- UPDATE


type Msg
    = MorePlease
    | GotRoutes (Result Http.Error (List Route))
    | UpdateFilter String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MorePlease ->
            ( { model | status = Loading }, getRoutes )

        GotRoutes result ->
            case result of
                Ok routes ->
                    ( { model | status = Success routes }, Cmd.none )

                Err errmsg ->
                    ( { model | status = Failure errmsg }, Cmd.none )

        UpdateFilter newFilter ->
            ( { model | filter = String.toFloat newFilter }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "content" ]
        [ div [ class "header" ]
            [ h1 [] [ text "Strava" ]
            , nav []
                [ ul []
                    [ li [] [ a [ href "https://rbn.uber.space/strava/start" ] [ text "Start" ] ]
                    , li [] [ a [ href "https://rbn.uber.space/strava/refresh" ] [ text "Refresh" ] ]
                    ]
                ]
            ]
        , div [ class "route-list" ]
            [ input [ placeholder "Min Kilometers", onInput UpdateFilter ] []
            , nav []
                [ h2 [] [ text "Routes" ]
                , viewRoutes model
                ]
            ]
        ]


viewRoutes : Model -> Html Msg
viewRoutes model =
    case model.status of
        Failure error ->
            text (toString error)

        Loading ->
            text "Loading..."

        Success routeList ->
            renderRouteList (List.filter (isBigRoute model.filter) routeList)


isBigRoute : RouteFilter -> Route -> Bool
isBigRoute filter route =
    case filter of
        Nothing ->
            True

        Just distance ->
            route.distance > distance


renderRouteList : List Route -> Html msg
renderRouteList lst =
    ul []
        (List.map
            (\l ->
                li []
                    [ a [ href (routeToURL l) ] [ text (toUtcString l.date ++ " - " ++ toString (truncate l.distance) ++ "km") ]
                    ]
            )
            lst
        )


toUtcString : Time.Posix -> String
toUtcString time =
    String.fromInt (Time.toDay Time.utc time)
        ++ ". "
        ++ toString (Time.toMonth Time.utc time)
        ++ " "
        ++ String.fromInt (Time.toYear Time.utc time)


routeToURL : Route -> String
routeToURL route =
    "https://www.strava.com/activities/" ++ route.id



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
        { url = "https://rbn.uber.space/strava/routes"
        , expect = Http.expectJson GotRoutes routeListDecoder
        }
