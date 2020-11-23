port module Main exposing (..)

import Browser
import Date
import Debug exposing (toString)
import Heatmap exposing (Bounds, HeatmapCell, boundsDecoder, heatmapDecoder, heatmapEncoder)
import Html exposing (..)
import Html.Attributes exposing (checked, class, href, id, placeholder, style, type_)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode exposing (string)
import Json.Encode as E
import Route exposing (Route, RouteFilter, encodeRoutes, filterRoute, routeListDecoder, routeToURL)
import String exposing (fromFloat)
import Time exposing (Month(..))
import Url.Builder as URLBuilder
import User exposing (StravaUser, userListDecoder)



-- exposing (crossOrigin, string)
--backendURL =
--    "https://rbn.uber.space/strava/"


backendURL =
    "http://localhost:5000"



-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


port sendRoutes : E.Value -> Cmd msg


port sendHeatmap : E.Value -> Cmd msg


port requestMapBounds : () -> Cmd msg


port receiveMapBounds : (Json.Decode.Value -> msg) -> Sub msg



-- MODEL


type StravaAPI
    = Failure Http.Error
    | Loading
    | Success


type alias Model =
    { status : StravaAPI
    , routes : Maybe (List Route)
    , filter : RouteFilter
    , autoupdate : Bool
    , users : Maybe (List StravaUser)
    , active_user : Maybe StravaUser
    }


init : () -> ( Model, Cmd Msg )
init _ =
    let
        model =
            Model Loading Nothing initRouteFilter True Nothing Nothing
    in
    ( model, Cmd.batch [ getRoutes model, getUsers ] )


initRouteFilter : RouteFilter
initRouteFilter =
    RouteFilter ( Nothing, Nothing ) ( Nothing, Nothing ) ( Nothing, Nothing )



-- UPDATE


type Msg
    = MorePlease
    | GotRoutes (Result Http.Error (List Route))
    | GotUsers (Result Http.Error (List StravaUser))
    | GotHeatmap (Result Http.Error (List HeatmapCell))
    | UpdateFilterMinDistance String
    | UpdateFilterMaxDistance String
    | UpdateFilterMinSpeed String
    | UpdateFilterMaxSpeed String
    | UpdateFilterMinDate String
    | UpdateFilterMaxDate String
    | ToggleAutoUpdate
    | UpdateActiveUser StravaUser
    | RequestMapBounds -- send message for getting bounds
    | ReceivedMapBounds (Result Json.Decode.Error Bounds)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateActiveUser user ->
            let
                newModel =
                    { model | active_user = Just user }
            in
            ( newModel, Cmd.none )

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

                newModel =
                    { model | filter = { oldFilter | date = ( newDate, Tuple.second oldFilter.date ) } }
            in
            ( newModel, updateMap newModel )

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

                newModel =
                    { model | filter = { oldFilter | date = ( Tuple.first oldFilter.date, newDate ) } }
            in
            ( newModel, updateMap newModel )

        MorePlease ->
            ( { model | status = Loading }, getRoutes model )

        GotRoutes result ->
            case result of
                Ok routes ->
                    let
                        newModel =
                            { model | status = Success, routes = Just routes }
                    in
                    ( newModel, updateMap newModel )

                Err errmsg ->
                    ( { model | status = Failure errmsg }, Cmd.none )

        GotUsers result ->
            case result of
                Ok users ->
                    ( { model | users = Just users }, Cmd.none )

                Err errmsg ->
                    ( { model | status = Failure errmsg }, Cmd.none )

        GotHeatmap result ->
            case result of
                Ok hm ->
                    ( model, updateHeatmap hm )

                Err errmsg ->
                    ( { model | status = Failure errmsg }, Cmd.none )

        UpdateFilterMinDistance newVal ->
            let
                old_filter =
                    model.filter

                new_filter =
                    { old_filter | distance = ( String.toFloat newVal, Tuple.second old_filter.distance ) }

                newModel =
                    { model | filter = new_filter }
            in
            ( newModel, updateMap newModel )

        UpdateFilterMaxDistance newVal ->
            let
                old_filter =
                    model.filter

                new_filter =
                    { old_filter | distance = ( Tuple.first old_filter.distance, String.toFloat newVal ) }

                newModel =
                    { model | filter = new_filter }
            in
            ( newModel, updateMap newModel )

        UpdateFilterMinSpeed newVal ->
            let
                old_filter =
                    model.filter

                new_filter =
                    { old_filter | speed = ( String.toFloat newVal, Tuple.second old_filter.speed ) }

                newModel =
                    { model | filter = new_filter }
            in
            ( newModel, updateMap newModel )

        UpdateFilterMaxSpeed newVal ->
            let
                old_filter =
                    model.filter

                new_filter =
                    { old_filter | speed = ( Tuple.first old_filter.speed, String.toFloat newVal ) }

                newModel =
                    { model | filter = new_filter }
            in
            ( newModel, updateMap newModel )

        ToggleAutoUpdate ->
            let
                newModel =
                    { model | autoupdate = not model.autoupdate }
            in
            ( newModel, updateMap newModel )

        RequestMapBounds ->
            ( model, requestMapBounds () )

        ReceivedMapBounds result ->
            case result of
                Ok bounds ->
                    ( model, getHeatmap model bounds )

                Err errmsg ->
                    ( { model | status = Loading }, Cmd.none )


updateMap : Model -> Cmd msg
updateMap model =
    let
        routes =
            filteredRoutes model
    in
    if model.autoupdate && not (List.isEmpty routes) then
        sendRoutes (encodeRoutes routes)

    else
        Cmd.none


updateHeatmap : List HeatmapCell -> Cmd msg
updateHeatmap cells =
    if not (List.isEmpty cells) then
        sendHeatmap (heatmapEncoder cells)

    else
        Cmd.none


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
    receiveMapBounds (boundsDecoder >> ReceivedMapBounds)



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "content" ]
        [ div [ class "header" ]
            [ h1 [] [ text "Strava" ]
            , viewUserNavigation model
            ]
        , div [ class "route-list" ]
            [ viewFilterForm model
            , nav []
                [ h2 [] [ viewStravaStatus model ]
                , viewRoutes model
                ]
            ]
        , div [ class "route-detail" ]
            [ div [ id "mapid", style "height" "80vh", style "width" "100%" ] []
            , button [ onClick RequestMapBounds ] [ text "Get Bounds!" ]
            ]
        ]


viewUserNavigation : Model -> Html Msg
viewUserNavigation model =
    let
        userListItems =
            case model.users of
                Nothing ->
                    []

                Just users ->
                    List.map
                        (\l ->
                            li []
                                [ a [ onClick (UpdateActiveUser l), href "#" ] [ text l.name ]
                                ]
                        )
                        users

        listItems =
            List.concat
                [ userListItems
                , [ li [] [ a [ href (URLBuilder.crossOrigin backendURL [ "start" ] []) ] [ text "Login" ] ] ]
                ]
    in
    nav []
        [ ul [] listItems
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
        , br [] []
        , label
            [ style "margin-top" "20px" ]
            [ input [ type_ "checkbox", onClick ToggleAutoUpdate, checked model.autoupdate ] []
            , text "Auto-Update Map"
            ]
        ]


viewStravaStatus : Model -> Html Msg
viewStravaStatus model =
    case model.status of
        Failure error ->
            text (toString error)

        Loading ->
            case model.active_user of
                Nothing ->
                    text "Please select user"

                Just user ->
                    text ("Loading routes of " ++ user.name)

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
                    [ a [ href (routeToURL l) ] [ text (toIsoString l.date ++ " - " ++ toString (truncate l.distance) ++ "km") ]
                    ]
            )
            lst
        )


toIsoString : Time.Posix -> String
toIsoString time =
    let
        date =
            Date.fromPosix Time.utc time
    in
    Date.toIsoString date



-- HTTP


getRoutes : Model -> Cmd Msg
getRoutes model =
    case model.active_user of
        Nothing ->
            Cmd.none

        Just user ->
            Http.get
                { url = URLBuilder.crossOrigin backendURL [ user.id, "routes" ] []
                , expect = Http.expectJson GotRoutes routeListDecoder
                }


getUsers : Cmd Msg
getUsers =
    Http.get
        { url = URLBuilder.crossOrigin backendURL [ "users" ] []
        , expect = Http.expectJson GotUsers userListDecoder
        }


getHeatmap : Model -> Bounds -> Cmd Msg
getHeatmap model bounds =
    -- Get  Bounds from current map
    case model.active_user of
        Nothing ->
            Cmd.none

        Just user ->
            let
                url =
                    URLBuilder.crossOrigin
                        backendURL
                        [ user.id, "heatmap" ]
                        [ URLBuilder.string "minlat" (fromFloat bounds.minLatitude)
                        , URLBuilder.string "maxlat" (fromFloat bounds.maxLatitude)
                        , URLBuilder.string "minlon" (fromFloat bounds.minLongitude)
                        , URLBuilder.string "maxlon" (fromFloat bounds.maxLongitude)
                        ]
            in
            Http.get
                { url = url
                , expect = Http.expectJson GotHeatmap heatmapDecoder
                }
