"""This module defines the ORM DB models."""


import time

from flask_sqlalchemy import SQLAlchemy
import swagger_client
import polyline


from strava import refresh_user

db = SQLAlchemy()


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


class Route(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"))
    start_date = db.Column(db.DateTime)
    name = db.Column(db.String)
    elapsed_time = db.Column(db.Integer)
    moving_time = db.Column(db.Integer)
    distance = db.Column(db.Float)
    average_speed = db.Column(db.Float)
    route = db.Column(db.String)
    elevation = db.Column(db.Float)

    @classmethod
    def from_summary_activity(cls, activity):
        """Construct route from dict."""
        return cls(
            id=activity.id,
            user_id=activity.athlete.id,
            start_date=activity.start_date,
            name=activity.name,
            elapsed_time=activity.elapsed_time,
            moving_time=activity.moving_time,
            distance=activity.distance / 1000.0,
            average_speed=activity.average_speed * 3.6,
            route=activity.map.summary_polyline,
            elevation=activity.total_elevation_gain,
        )

    def to_json(self):
        return {
            "id": str(self.id),
            "distance": self.distance,
            # In milliseconds
            "start_date": self.start_date.timestamp() * 1000,
            "average_speed": self.average_speed,
            "moving_time": self.moving_time,
            "elevation": self.elevation,
            "route": polyline.codec.PolylineCodec().decode(self.route),
        }

    def __repr__(self):
        return f"Route {self.name}"


def get_and_store_routes(user: User):
    """Retrieves all (summary) activities from the Strava-API and stores them in the DB."""

    # TODO: find better place for this function

    user.check_and_refresh()

    api = swagger_client.ActivitiesApi()
    api.api_client.configuration.access_token = user.access_token

    # Pagination: Load new route pages until exhausted
    page = 1
    while True:
        r = api.get_logged_in_athlete_activities(per_page=100, page=page)
        routes = list(map(Route.from_summary_activity, r))
        if routes:
            db.session.add_all(routes)
            page += 1
        else:
            break

    db.session.commit()
