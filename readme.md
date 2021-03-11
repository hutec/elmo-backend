# Elmo

This is a playground for learning [elm](https://elm-lang.org/), web developement, and data visualization.
Data is consumed from the [Strava](https://www.strava.com/) API and displayed with [Leaflet](https://leafletjs.com/reference-1.7.1.html)

# Installation

## Install the Strava API via Swagger

- Download the Swagger Jar: `wget https://repo1.maven.org/maven2/io/swagger/swagger-codegen-cli/2.4.12/swagger-codegen-cli-2.4.12.jar`
- `java -jar swagger-codegen-cli-2.4.12.jar generate -i https://developers.strava.com/swagger/swagger.json -l python -o generated`
- `cd generated && python setup.py install --user`

## Set Strava Secrets

- Create a Strava App
- Enter `STRAVA_CLIENT_ID` AND `STRAVA_CLIENT_SECRET`

# Helpful Links

[StackOverflow Discussion](https://stackoverflow.com/questions/55657275/swagger-client-in-python-trying-to-use-strava-api)

https://yizeng.me/2017/01/11/get-a-strava-api-access-token-with-write-permission/
https://www.ryanbaumann.com/blog/2015/4/6/strava-api-cycling-data-for-visualization
https://www.patricksteinert.de/wordpress/2017/11/29/analyzing-strava-training

https://elmprogramming.com/building-a-simple-page-in-elm.html
