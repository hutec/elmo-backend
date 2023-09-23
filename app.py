"""This module contains the Flask App."""
import os

from flask import request
from flask import Flask
from flask import redirect
from flask import jsonify
from flask_executor import Executor
import requests

from elmo.models import db, User, Route, get_and_store_routes

RESPONSE_TYPE = "code"
SCOPE = "read_all,activity:read_all,activity:read,profile:read_all"


def create_app():
    app = Flask(__name__)
    basedir = os.path.abspath(os.path.dirname(__file__))
    database_path = os.path.join(basedir, "elmo.db")
    app.config[
        "SQLALCHEMY_DATABASE_URI"
    ] = f"sqlite:///{database_path}?check_same_thread=False"
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["EXECUTOR_PROPAGATE_EXCEPTIONS"] = True

    db.init_app(app)
    return app


app = create_app()
app.config.from_pyfile("application.cfg")

executor = Executor(app)


@app.route("/users")
def list_users():
    """List all users."""
    users = User.query.all()
    users = [{"id": str(u.id), "name": u.firstname} for u in users]
    response = jsonify(users)
    response.headers.add("Access-Control-Allow-Origin", "*")
    return response


@app.route("/<user_id>/geojson")
def get_geojson(user_id):
    """Get routes as geojson file."""
    user_id = int(user_id)
    user = User.query.filter_by(id=user_id).first()
    if user is None:
        return "User not found", 404

    # Get new routes if available
    get_and_store_routes(
        user, app.config["STRAVA_CLIENT_ID"], app.config["STRAVA_CLIENT_SECRET"]
    )
    filter_kwargs = {"user_id": user_id}
    routes = (
        Route.query.filter_by(**filter_kwargs).order_by(Route.start_date.desc()).all()
    )

    features = []
    for route in routes:
        route = route.to_json()
        features.append(
            {
                "type": "Feature",
                "geometry": {
                    "type": "LineString",
                    "coordinates": list(map(lambda x: [x[1], x[0]], route["route"])),
                },
                "properties": {
                    "id": route["id"],
                },
            }
        )
    out = {"type": "FeatureCollection", "features": features}
    response = jsonify(out)
    response.headers.add("Access-Control-Allow-Origin", "*")
    return response


@app.route("/<user_id>/routes")
def list_routes(user_id):
    """List all routes of a user.

    Additionally, an argument "filter" containing a route id to filter
    can be passed.
    """
    user_id = int(user_id)
    user = User.query.filter_by(id=user_id).first()
    # Get new routes if available
    get_and_store_routes(
        user, app.config["STRAVA_CLIENT_ID"], app.config["STRAVA_CLIENT_SECRET"]
    )

    filter_kwargs = {"user_id": user_id}
    if request.args.get("filter"):
        filter_kwargs["id"] = request.args.get("filter")

    routes = (
        Route.query.filter_by(**filter_kwargs).order_by(Route.start_date.desc()).all()
    )
    routes = list(map(lambda r: r.to_json(), routes))
    response = jsonify(routes)
    response.headers.add("Access-Control-Allow-Origin", "*")
    return response


@app.route("/start")
def authenticate():
    """Starts the authentication process."""
    client_id = app.config["STRAVA_CLIENT_ID"]
    redirect_uri = app.config["REDIRECT_URI"]
    url = f"https://www.strava.com/oauth/authorize?client_id={client_id}&response_type=code&redirect_uri={redirect_uri}&scope={SCOPE}"
    return redirect(url)


@app.route("/user_token_exchange")
def user_token_exchange():
    """Receive the user code and query Strava to get the final access token."""
    user_code = request.args.get("code")

    r = requests.post(
        "https://www.strava.com/api/v3/oauth/token",
        data={
            "client_id": app.config["STRAVA_CLIENT_ID"],
            "client_secret": app.config["STRAVA_CLIENT_SECRET"],
            "code": user_code,
            "grant_type": "authorization_code",
        },
    )
    user = User.from_json(r.json())
    db.session.add(user)
    db.session.commit()

    executor.submit(
        get_and_store_routes,
        user,
        app.config["STRAVA_CLIENT_ID"],
        app.config["STRAVA_CLIENT_SECRET"],
    )

    return "Routes are now syncing in the background. This will take some time."


if __name__ == "__main__":
    app.run(debug=True)
