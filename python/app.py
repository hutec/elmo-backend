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
from strava import user_to_dict
from strava import check_and_refresh

RESPONSE_TYPE = "code"
SCOPE = "read_all,activity:read_all,activity:read,profile:read_all"

app = Flask(__name__)

def load_users():
  """Load users from users directory."""
  users = {}
  for file in os.listdir("users"):
      with open(os.path.join("users", file), "r") as user_config_file:
          user_config = json.load(user_config_file)
          user_id = user_config["athlete"]["id"]
          users[user_id] = user_config
  app.config["USERS"] = users


@app.route("/users")
def list_users():
    """List all users."""
    load_users()
    users = list(map(user_to_dict, app.config["USERS"].values()))
    
    # user_names = [u["athlete"]["firstname"] for u in app.config["USERS"].values()]
    response = jsonify(users)
    response.headers.add("Access-Control-Allow-Origin", "*")
    return response


@app.route("/<user_id>/routes")
def list_routes(user_id):
    """List all routes of a user."""
    user_id = int(user_id)
    check_and_refresh(app, user_id)
    api = swagger_client.ActivitiesApi()
    api.api_client.configuration.access_token = app.config["USERS"][user_id][
        "access_token"
    ]
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
    user_config = r.json()
    user_id = user_config["athlete"]["id"]
    with open(os.path.join("users", f"{user_id}.json"), "w") as user_file:
        json.dump(user_config, user_file)
    app.config["USERS"][user_id].update(user_config)
    return f"Welcome {user_config['athlete']['firstname']}"


if __name__ == "__main__":
    app.run(debug=True)

