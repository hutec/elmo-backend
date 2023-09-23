# Elmo

# Installation

[Install `poetry`](https://python-poetry.org/docs/#installation). Install the project requirements via

```bash
poetry install
```

## Create empty database

```bash
poetry run python scripts/init_db.py
```

## Set Strava Secrets

- Copy `application.cfg.example` to `application.cfg`
- Replace with the values from the [Strava API page](https://www.strava.com/settings/api)
