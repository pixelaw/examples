# PixeLAW Examples
This is a list of app examples developed using PixeLAW's [app_template](https://github.com/pixelaw/app_template).
Each app can stand alone and can be deployed individually. Again, read the app_template to
understand how to do so. Inversely, all apps can be deployed to the PixeLAW core via a
make instruction.

## Prerequisites
1. [Make](https://www.gnu.org/software/make/#download)
2. [Docker](https://docs.docker.com/engine/install/)
3. [Docker Compose plugin](https://docs.docker.com/compose/install/)

## Getting Started
Run this command to start up PixeLAW core and deploy all apps in the directory.
````console
make start
````

To stop it, simply run this command:
````console
make stop
````