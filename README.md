# PixeLAW Examples
This is a list of app examples that demonstrate PixeLAW's capability.
Each app can stand alone and can be deployed individually. Here are the list of apps currently available:

| Name       | Description                                                                                                 |
|------------|-------------------------------------------------------------------------------------------------------------|
| hunter     | A game of chance where any player can pick a random pixel that could either be a winning or losing pixel    |
| minsweeper | A classic minesweeper with a limited amount of pixels in a board                                            |
| rps        | Stands for rock-paper-scissors, where two players can play on the same pixel                                |
| tictactoe  | A classic game of tictactoe against a machine learning opponent                                             |
| pix2048    | A fully on-chain 2048 based on PixeLAW(a pixel-based Autonomous World built on @Starknet using @ohayo_dojo) |


## Prerequisites
1. [Make](https://www.gnu.org/software/make/#download)
2. [Docker](https://docs.docker.com/engine/install/)
3. [Docker Compose plugin](https://docs.docker.com/compose/install/)

## Getting Started
There are two recommended ways to get PixeLAW started. The simplest method is getting everything started with
all the apps in this repo and the other method is individually deploying them.

### Deploying all Apps
Run this command to start up PixeLAW core and deploy all apps in the directory.
````shell
make start
````

To stop it, simply run this command:
````shell
make stop
````

### Deploying an app individually
To start up PixeLAW, you can either:
````shell
docker compose up -d
````
or 
````shell
make start_core
````

Afterwards, to deploy an app to your local PixeLAW, you can either:
````shell
./local_deploy.sh <replace_this_with_any_app_name>
````
or
````shell
make deploy_app APP=<replace_this_with_any_app_name>
````

## Contributing an app
If you'd like to contribute your app to PixeLAW, feel free to do a pull request for this repo
and add your app in the table above.

## Credits

| Contribution                                               | Developer                                |
|------------------------------------------------------------|------------------------------------------|
| App - [pix2048](https://github.com/themetacat/PixeLAW2048) | [MetaCat](https://github.com/themetacat) |


