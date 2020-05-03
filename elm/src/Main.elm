port module Main exposing (..)

import Browser
import Date
import DatePicker exposing (DateEvent(..), defaultSettings)
import Debug exposing (toString)
import Html exposing (..)
import Html.Attributes exposing (class, href, id, placeholder, style)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Encode as E
import Route exposing (Route, RouteFilter, encodeRoutes, filterRoute, routeListDecoder, routeToURL)
import Task
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
    , minDatePicker : DatePicker.DatePicker
    , maxDatePicker : DatePicker.DatePicker
    }


init : () -> ( Model, Cmd Msg )
init _ =
    let
        minDatePicker =
            DatePicker.initFromDate (Date.fromCalendarDate 2020 Mar 25)

        maxDatePicker =
            DatePicker.initFromDate (Date.fromCalendarDate 2020 Mar 25)
    in
    ( Model Loading Nothing initRouteFilter minDatePicker maxDatePicker, getRoutes )


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
    | UpdateFilterMinDate DatePicker.Msg
    | UpdateFilterMaxDate DatePicker.Msg
    | UpdateMap
    | ReceiveDate Date.Date


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateFilterMinDate subMsg ->
            let
                ( newDatePicker, dateEvent ) =
                    DatePicker.update defaultSettings subMsg model.minDatePicker

                newDate =
                    case dateEvent of
                        Picked changedDate ->
                            Just changedDate

                        _ ->
                            Tuple.first model.filter.date

                old_filter =
                    model.filter

                new_filter =
                    { old_filter | date = ( newDate, Tuple.second old_filter.date ) }
            in
            ( { model
                | filter = new_filter
                , minDatePicker = newDatePicker
              }
            , Cmd.none
            )

        UpdateFilterMaxDate subMsg ->
            let
                ( newDatePicker, dateEvent ) =
                    DatePicker.update defaultSettings subMsg model.maxDatePicker

                newDate =
                    case dateEvent of
                        Picked changedDate ->
                            Just changedDate

                        _ ->
                            Tuple.second model.filter.date

                old_filter =
                    model.filter

                new_filter =
                    { old_filter | date = ( Tuple.first old_filter.date, newDate ) }
            in
            ( { model
                | filter = new_filter
                , maxDatePicker = newDatePicker
              }
            , Cmd.none
            )

        MorePlease ->
            ( { model | status = Loading }, getRoutes )

        GotRoutes result ->
            case result of
                Ok routes ->
                    ( { model | status = Success, routes = Just routes }, Date.today |> Task.perform ReceiveDate )

                Err errmsg ->
                    ( { model | status = Failure errmsg }, Date.today |> Task.perform ReceiveDate )

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

        ReceiveDate today ->
            let
                minDatePicker =
                    DatePicker.initFromDate today

                maxDatePicker =
                    DatePicker.initFromDate today
            in
            ( { model | minDatePicker = minDatePicker, maxDatePicker = maxDatePicker }, Cmd.none )


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
            [ div [ id "mapid", style "height" "800px", style "width" "100%" ] []
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
        , DatePicker.view
            (Tuple.first model.filter.date)
            defaultSettings
            model.minDatePicker
            |> Html.map UpdateFilterMinDate
        , DatePicker.view
            (Tuple.second model.filter.date)
            defaultSettings
            model.maxDatePicker
            |> Html.map UpdateFilterMaxDate
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
