import time
import requests
import swagger_client
import polyline
import json

import secrets


def activity_to_dict(
    activity: swagger_client.models.summary_activity.SummaryActivity,
) -> dict:
    return {
        "id": str(activity.id),
        "distance": activity.distance / 1000.0,
        # In milliseconds
        "start_date": activity.start_date.timestamp() * 1000,
        "average_speed": activity.average_speed * 3.6,
        "moving_time": activity.moving_time,
        "elevation": activity.total_elevation_gain,
        "route": polyline.codec.PolylineCodec().decode(activity.map.summary_polyline),
    }

def user_to_dict(user: dict) -> dict:
    return {
             "id": str(user["athlete"]["id"]),
            "name": str(user["athlete"]["firstname"])
        }


def check_and_refresh(app, user_id):
    """Refreshes the user access token if it's expired"""
    if time.time() > app.config["USERS"][user_id]["expires_at"]:
        refresh_user(app, user_id)


def refresh_user(app, user_id):
    print("refreshing user")
    refresh_token = app.config["USERS"][user_id]["refresh_token"]
    r = requests.post(
        "https://www.strava.com/api/v3/oauth/token",
        data={
            "client_id": secrets.STRAVA_CLIENT_ID,
            "client_secret": secrets.STRAVA_CLIENT_SECRET,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        },
    )
    token_update = r.json()
    del token_update["token_type"]
    app.config["USERS"][user_id].update(token_update)
    with open(f"users/{user_id}.json", "w") as f:
        json.dump(app.config["USERS"][user_id], f)
