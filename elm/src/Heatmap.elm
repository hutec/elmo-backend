module Heatmap exposing (Bounds, Heatmap, HeatmapCell, boundsDecoder, heatmapDecoder, heatmapEncoder)

import Json.Decode exposing (Decoder, Value, float, index)
import Json.Encode as E


type alias HeatmapCell =
    { minLatitude : Float
    , minLongitude : Float
    , maxLatitude : Float
    , maxLongitude : Float
    , value : Float
    }


type alias Heatmap =
    { cells : List HeatmapCell
    }


type alias Bounds =
    { minLatitude : Float
    , maxLatitude : Float
    , minLongitude : Float
    , maxLongitude : Float
    }


heatmapDecoder : Decoder (List HeatmapCell)
heatmapDecoder =
    Json.Decode.list heatmapCellDecoder


heatmapCellDecoder : Decoder HeatmapCell
heatmapCellDecoder =
    Json.Decode.map5 HeatmapCell
        (index 0 float)
        (index 1 float)
        (index 2 float)
        (index 3 float)
        (index 4 float)


boundsDecoder : Json.Decode.Value -> Result Json.Decode.Error Bounds
boundsDecoder =
    let
        decoder =
            Json.Decode.map4 Bounds
                (index 0 float)
                (index 1 float)
                (index 2 float)
                (index 3 float)
    in
    Json.Decode.decodeValue decoder


heatmapCellEncoder : HeatmapCell -> E.Value
heatmapCellEncoder cell =
    E.list E.float [ cell.minLatitude, cell.minLongitude, cell.maxLatitude, cell.maxLongitude, cell.value ]


heatmapEncoder : List HeatmapCell -> E.Value
heatmapEncoder cells =
    E.list heatmapCellEncoder cells
