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

import secrets
import swagger_client
from strava import activity_to_dict
from strava import refresh_user
from models import db, User, Route, get_and_store_routes

RESPONSE_TYPE = "code"
SCOPE = "read_all,activity:read_all,activity:read,profile:read_all"


def create_app():
    app = Flask(__name__)
    app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///elmo.db"
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    db.init_app(app)
    return app


app = create_app()


@app.route("/users")
def list_users():
    """List all users."""
    users = User.query.all()
    users = [{"id": str(u.id), "name": u.firstname} for u in users]
    response = jsonify(users)
    response.headers.add("Access-Control-Allow-Origin", "*")
    return response


@app.route("/<user_id>/routes")
def list_routes(user_id):
    """List all routes of a user."""
    user_id = int(user_id)
    user = User.query.filter_by(id=user_id).first()
    user.check_and_refresh()

    api = swagger_client.ActivitiesApi()
    api.api_client.configuration.access_token = user.access_token

    # Pagination: Load new route pages until exhausted
    routes = []
    page = 1
    while True:
        r = api.get_logged_in_athlete_activities(per_page=100, page=page)
        new_routes = list(map(activity_to_dict, r))
        if new_routes:
            routes.extend(new_routes)
            page += 1
        else:
            break

    response = jsonify(routes)
    response.headers.add("Access-Control-Allow-Origin", "*")
    return response


@app.route("/start")
def authenticate():
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
    user = User.from_json(r.json())
    db.session.add(user)
    db.session.commit()
    get_and_store_routes(user)

    return f"Welcome {user}"


if __name__ == "__main__":
    app.run(debug=True)
