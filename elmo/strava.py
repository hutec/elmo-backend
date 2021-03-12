"""This module handles Strava API specific classes and API-calls."""

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


def refresh_user(refresh_token) -> dict:
    """Requests updated access credentials from the Strava API."""
    r = requests.post(
        "https://www.strava.com/api/v3/oauth/token",
        data={
            "client_id": secrets.STRAVA_CLIENT_ID,
            "client_secret": secrets.STRAVA_CLIENT_SECRET,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        },
    )
    return r.json()
