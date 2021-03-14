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

- Copy `secrets.py.example` to `secrets.py`
- Replace with the values from the [Strava API page](https://www.strava.com/settings/api)
