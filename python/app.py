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
from flask_sqlalchemy import SQLAlchemy

import secrets
import swagger_client
from strava import activity_to_dict
from strava import user_to_dict
from strava import check_and_refresh

RESPONSE_TYPE = "code"
SCOPE = "read_all,activity:read_all,activity:read,profile:read_all"

app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///elmo.db"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
db = SQLAlchemy(app)


class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    firstname = db.Column(db.String(80))
    lastname = db.Column(db.String(80))
    expires_at = db.Column(db.Integer)
    refresh_token = db.Column(db.String(40))
    access_token = db.Column(db.String(40))

    @classmethod
    def from_json(cls, args):
        """Construct User from JSON response."""

        return cls(
            id=args["athlete"]["id"],
            firstname=args["athlete"]["firstname"],
            lastname=args["athlete"]["lastname"],
            expires_at=args["expires_at"],
            refresh_token=args["refresh_token"],
            access_token=args["access_token"],
        )

    def check_and_refresh(self):
        """Refreshes the user access token if it's expired"""
        if time.time() > self.expires_at:
            r = refresh_user(self.refresh_token)
            self.access_token = r["access_token"]
            self.refresh_token = r["refresh_token"]
            self.expires_at = r["expires_at"]

            db.session.commit()

    def __repr__(self):
        return f"User {self.firstname} {self.lastname}"


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

    return f"Welcome {user}"


if __name__ == "__main__":
    app.run(debug=True)
