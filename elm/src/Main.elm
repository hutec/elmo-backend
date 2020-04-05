port module Main exposing (..)

import Browser
import Debug exposing (toString)
import Html exposing (..)
import Html.Attributes exposing (class, href, placeholder)
import Html.Events exposing (onInput)
import Http
import Json.Encode as E
import Route exposing (Route, RouteFilter, filterRoute, routeListDecoder, routeToURL)
import Time



-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


port cache : E.Value -> Cmd msg



-- MODEL


type StravaAPI
    = Failure Http.Error
    | Loading
    | Success


type alias Model =
    { status : StravaAPI
    , routes : Maybe (List Route)
    , filter : RouteFilter
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Model Loading Nothing Nothing, getRoutes )



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
                    ( { model | status = Success, routes = Just routes }, Cmd.none )

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
                [ h2 [] [ viewStravaStatus model ]
                , viewRoutes model
                ]
            ]
        ]


viewStravaStatus : Model -> Html Msg
viewStravaStatus model =
    case model.status of
        Failure error ->
            text (toString error)

        Loading ->
            text "Loading..."

        Success ->
            text "Routes"


viewRoutes : Model -> Html Msg
viewRoutes model =
    case model.routes of
        Nothing ->
            text "No Routes"

        Just routes ->
            renderRouteList (List.filter (filterRoute model.filter) routes)


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
    padDay (String.fromInt (Time.toDay Time.utc time))
        ++ ". "
        ++ toString (Time.toMonth Time.utc time)
        ++ " "
        ++ String.fromInt (Time.toYear Time.utc time)


padDay : String -> String
padDay day =
    if String.length day == 1 then
        "0" ++ day

    else
        day



-- HTTP


getRoutes : Cmd Msg
getRoutes =
    Http.get
        { url = "https://rbn.uber.space/strava/routes"
        , expect = Http.expectJson GotRoutes routeListDecoder
        }
