module Route exposing (Coordinate, Route, RouteFilter, encodeRoutes, filterRoute, routeListDecoder, routeToURL)

import Date exposing (Date, fromPosix)
import Json.Decode exposing (Decoder, field, float, index, string)
import Json.Encode as E
import Time exposing (Posix, utc)


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
    { distance : ( Maybe Float, Maybe Float )
    , speed : ( Maybe Float, Maybe Float )
    , date : ( Maybe Date, Maybe Date )
    }


routeToURL : Route -> String
routeToURL route =
    "https://www.strava.com/activities/" ++ route.id


compareMaybe : Maybe comparable -> comparable -> (comparable -> comparable -> Bool) -> Bool
compareMaybe a b comp =
    case a of
        Nothing ->
            True

        Just x ->
            comp x b


isBetween : ( Maybe comparable, Maybe comparable ) -> comparable -> Bool
isBetween range a =
    let
        lower =
            Tuple.first range

        upper =
            Tuple.second range
    in
    compareMaybe lower a (<) && compareMaybe upper a (>)


isBetweenDate : ( Maybe Date, Maybe Date ) -> Posix -> Bool
isBetweenDate ( lower, upper ) a =
    let
        d =
            fromPosix utc a
    in
    Date.isBetween (Maybe.withDefault d lower) (Maybe.withDefault d upper) d


filterRoute : RouteFilter -> Route -> Bool
filterRoute filter route =
    isBetween filter.distance route.distance && isBetween filter.speed route.speed && isBetweenDate filter.date route.date



-- JSON


encodeRoutes : List Route -> E.Value
encodeRoutes routes =
    E.list encodeRoute routes


encodeRoute : Route -> E.Value
encodeRoute route =
    E.object
        [ ( "route", E.list encodeCoordinate route.route )
        , ( "url", E.string (routeToURL route) )
        ]


encodeCoordinate : Coordinate -> E.Value
encodeCoordinate coord =
    E.list E.float [ coord.latitude, coord.longitude ]


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
