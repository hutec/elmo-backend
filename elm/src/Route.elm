module Route exposing (Coordinate, Route, RouteFilter, filterRoute, routeListDecoder, routeToURL, encodeRoutes)

import Json.Decode exposing (Decoder, field, float, index, string)
import Json.Encode as E
import Time exposing (Posix)


type alias Coordinate =
    { latitude : Float
    , longitude : Float
    }


type alias Route =
    { id : String
    , distance : Float
    , date : Posix
    , speed : Float
    , moving_time : Float
    , elevation : Float
    , route : List Coordinate
    }


type alias RouteFilter =
    Maybe Float


routeToURL : Route -> String
routeToURL route =
    "https://www.strava.com/activities/" ++ route.id


filterRoute : RouteFilter -> Route -> Bool
filterRoute filter route =
    case filter of
        Nothing ->
            True

        Just distance ->
            route.distance > distance



-- JSON

encodeRoutes : List Route -> E.Value
encodeRoutes routes =
    E.list encodeRoute routes 

encodeRoute : Route -> E.Value
encodeRoute route =
    E.list encodeCoordinate route.route

encodeCoordinate : Coordinate -> E.Value
encodeCoordinate coord =
    E.list E.float [coord.latitude, coord.longitude]


routeDecoder : Decoder Route
routeDecoder =
    Json.Decode.map7 Route
        (field "id" string)
        (field "distance" float)
        (field "start_date" decodeTime)
        (field "average_speed" float)
        (field "moving_time" float)
        (field "elevation" float)
        (field "route" decodeCoordinateList)


routeListDecoder : Decoder (List Route)
routeListDecoder =
    Json.Decode.list routeDecoder


decodeCoordinate : Decoder Coordinate
decodeCoordinate =
    Json.Decode.map2 Coordinate (index 0 float) (index 1 float)


decodeCoordinateList : Decoder (List Coordinate)
decodeCoordinateList =
    Json.Decode.list decodeCoordinate


decodeTime : Decoder Time.Posix
decodeTime =
    Json.Decode.int
        |> Json.Decode.andThen
            (\ms ->
                Json.Decode.succeed <| Time.millisToPosix ms
            )
