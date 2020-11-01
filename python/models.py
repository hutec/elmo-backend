"""This module defines the ORM DB models."""


import time

from flask_sqlalchemy import SQLAlchemy

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
