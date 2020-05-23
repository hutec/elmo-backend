module User exposing (StravaUser, userListDecoder)

import Json.Decode exposing (Decoder, field, string)


type alias StravaUser =
    { name : String
    , id : String
    }


userDecoder : Decoder StravaUser
userDecoder =
    Json.Decode.map2 StravaUser
        (field "name" string)
        (field "id" string)


userListDecoder : Decoder (List StravaUser)
userListDecoder =
    Json.Decode.list userDecoder
