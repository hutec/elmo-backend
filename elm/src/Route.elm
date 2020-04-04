module Route exposing (Route, RouteFilter, filterRoute, routeListDecoder, routeToURL)

import Json.Decode exposing (Decoder, field, float, string)
import Time exposing (Posix)


type alias Route =
    { id : String
    , distance : Float
    , date : Posix
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


routeDecoder : Decoder Route
routeDecoder =
    Json.Decode.map3 Route
        (field "id" string)
        (field "distance" float)
        (field "start_date" decodeTime)


routeListDecoder : Decoder (List Route)
routeListDecoder =
    Json.Decode.list routeDecoder


decodeTime : Decoder Time.Posix
decodeTime =
    Json.Decode.int
        |> Json.Decode.andThen
            (\ms ->
                Json.Decode.succeed <| Time.millisToPosix ms
            )
