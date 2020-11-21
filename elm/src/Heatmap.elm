module Heatmap exposing (Heatmap, HeatmapCell, heatmapDecoder, heatmapEncoder)

import Json.Decode exposing (Decoder, float, index)
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


heatmapCellEncoder : HeatmapCell -> E.Value
heatmapCellEncoder cell =
    E.list E.float [ cell.minLatitude, cell.minLongitude, cell.maxLatitude, cell.maxLongitude, cell.value ]


heatmapEncoder : List HeatmapCell -> E.Value
heatmapEncoder cells =
    E.list heatmapCellEncoder cells
