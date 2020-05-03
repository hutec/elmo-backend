port module Main exposing (..)

import Browser
import Date
import Debug exposing (toString)
import Html exposing (..)
import Html.Attributes exposing (class, href, id, placeholder, style, type_)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Encode as E
import Route exposing (Route, RouteFilter, encodeRoutes, filterRoute, routeListDecoder, routeToURL)
import Time exposing (Month(..))



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
    ( Model Loading Nothing initRouteFilter, getRoutes )


initRouteFilter : RouteFilter
initRouteFilter =
    RouteFilter ( Nothing, Nothing ) ( Nothing, Nothing ) ( Nothing, Nothing )



-- UPDATE


type Msg
    = MorePlease
    | GotRoutes (Result Http.Error (List Route))
    | UpdateFilterMinDistance String
    | UpdateFilterMaxDistance String
    | UpdateFilterMinSpeed String
    | UpdateFilterMaxSpeed String
    | UpdateFilterMinDate String
    | UpdateFilterMaxDate String
    | UpdateMap


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateFilterMinDate dateString ->
            let
                newDate =
                    case Date.fromIsoString dateString of
                        Ok date ->
                            Just date

                        Err _ ->
                            Nothing

                oldFilter =
                    model.filter
            in
            ( { model | filter = { oldFilter | date = ( newDate, Tuple.second oldFilter.date ) } }, Cmd.none )

        UpdateFilterMaxDate dateString ->
            let
                newDate =
                    case Date.fromIsoString dateString of
                        Ok date ->
                            Just date

                        Err _ ->
                            Nothing

                oldFilter =
                    model.filter
            in
            ( { model | filter = { oldFilter | date = ( Tuple.first oldFilter.date, newDate ) } }, Cmd.none )

        MorePlease ->
            ( { model | status = Loading }, getRoutes )

        GotRoutes result ->
            case result of
                Ok routes ->
                    ( { model | status = Success, routes = Just routes }, Cmd.none )

                Err errmsg ->
                    ( { model | status = Failure errmsg }, Cmd.none )

        UpdateFilterMinDistance newVal ->
            let
                old_filter =
                    model.filter

                new_filter =
                    { old_filter | distance = ( String.toFloat newVal, Tuple.second old_filter.distance ) }
            in
            ( { model | filter = new_filter }, Cmd.none )

        UpdateFilterMaxDistance newVal ->
            let
                old_filter =
                    model.filter

                new_filter =
                    { old_filter | distance = ( Tuple.first old_filter.distance, String.toFloat newVal ) }
            in
            ( { model | filter = new_filter }, Cmd.none )

        UpdateFilterMinSpeed newVal ->
            let
                old_filter =
                    model.filter

                new_filter =
                    { old_filter | speed = ( String.toFloat newVal, Tuple.second old_filter.speed ) }
            in
            ( { model | filter = new_filter }, Cmd.none )

        UpdateFilterMaxSpeed newVal ->
            let
                old_filter =
                    model.filter

                new_filter =
                    { old_filter | speed = ( Tuple.first old_filter.speed, String.toFloat newVal ) }
            in
            ( { model | filter = new_filter }, Cmd.none )

        UpdateMap ->
            ( model, cache (encodeRoutes (filteredRoutes model)) )


filteredRoutes : Model -> List Route
filteredRoutes model =
    case model.routes of
        Nothing ->
            []

        Just routes ->
            List.filter (filterRoute model.filter) routes



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
            [ viewFilterForm model
            , button [ onClick UpdateMap ] [ text "Update Map" ]
            , nav []
                [ h2 [] [ viewStravaStatus model ]
                , viewRoutes model
                ]
            ]
        , div [ class "route-detail" ]
            [ div [ id "mapid", style "height" "80vh", style "width" "100%" ] []
            ]
        ]


viewFilterForm : Model -> Html Msg
viewFilterForm model =
    div [ id "route-filter" ]
        [ input [ placeholder "Min Distance", onInput UpdateFilterMinDistance ] []
        , input [ placeholder "Max Distance", onInput UpdateFilterMaxDistance ] []
        , br [] []
        , input [ placeholder "Min Speed", onInput UpdateFilterMinSpeed ] []
        , input [ placeholder "Max Speed", onInput UpdateFilterMaxSpeed ] []
        , br [] []
        , input [ type_ "date", onInput UpdateFilterMinDate ] []
        , input [ type_ "date", onInput UpdateFilterMaxDate ] []
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
