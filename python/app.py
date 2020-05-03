"""This module contains the Flask App."""

import time
import json
import os

from flask import request
from flask import Flask
from flask import redirect
from flask import jsonify
from flask import json
import requests
import polyline

import secrets
import swagger_client

RESPONSE_TYPE = "code"
SCOPE = "read_all,activity:read_all,activity:read,profile:read_all"

app = Flask(__name__)
if os.path.isfile("strava_user.json"):
    with open("strava_user.json", "r") as user_config_file:
        print("Loading existing strava user")
        strava_user = json.load(user_config_file)
        app.config["STRAVA_USER"] = strava_user


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


@app.route("/refresh")
def refresh_user():
    refresh_token = strava_user["refresh_token"]
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
    strava_user.update(token_update)
    with open("strava_user.json", "w") as f:
        json.dump(strava_user, f)


def check_and_refresh():
    """Refreshes the user access token if it's expired"""
    if time.time() > app.config["STRAVA_USER"]["expires_at"]:
        refresh_user()


@app.route("/routes")
def home():
    """List the last routes."""
    check_and_refresh()
    api = swagger_client.ActivitiesApi()
    api.api_client.configuration.access_token = app.config["STRAVA_USER"][
        "access_token"
    ]
    r = api.get_logged_in_athlete_activities(per_page=100)
    response = jsonify(list(map(activity_to_dict, r)))
    response.headers.add("Access-Control-Allow-Origin", "*")
    return response


@app.route("/start")
def start():
    """Starts the authentication process."""
    url = f"https://www.strava.com/oauth/authorize?client_id={secrets.STRAVA_CLIENT_ID}&response_type=code&redirect_uri={secrets.REDIRECT_URI}&scope={SCOPE}"
    return redirect(url)


@app.route("/user_token_exchange")
def user_token_exchange():
    """Receive the user code and query Strava to get the final access token."""
    user_code = request.args.get("code")
    scopes = request.args.get("scope")

    r = requests.post(
        "https://www.strava.com/api/v3/oauth/token",
        data={
            "client_id": secrets.STRAVA_CLIENT_ID,
            "client_secret": secrets.STRAVA_CLIENT_SECRET,
            "code": user_code,
            "grant_type": "authorization_code",
        },
    )
    strava_user = r.json()
    with open("strava_user.json", "w") as user_file:
        json.dump(strava_user, user_file)
    app.config["STRAVA_USER"] = strava_user

    return f"Welcome {strava_user['athlete']['firstname']}"


if __name__ == "__main__":
    app.run()
