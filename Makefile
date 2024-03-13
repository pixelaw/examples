# sets the individual app to deploy with deploy_app
APP ?= paint

# To get all the subdirectories in this directory
SUBDIRS := $(wildcard */)

### Deploys all the apps in this repository (this script assumes that every subdirectory is an app)
deploy_all:
	@for dir in $(SUBDIRS); do \
    	app_name=$$(basename $$dir); \
        echo "Deploying $$app_name"; \
        ./local_deploy.sh $$app_name; \
    done

### Deploys an individual app
# to use make deploy_app APP=<put_app_name_here>
deploy_app:
	./local_deploy.sh $(APP)

### Starts up the core
start_core:
	docker compose up -d

### Shuts down the core
stop_core:
	docker compose down

### Shuts down the core, removes the volumes attached, then starts it up again
reset:
	docker compose down -v
	docker compose up -d

### Starts up the core then deploys all the apps
start:
	$(MAKE) start_core
	$(MAKE) deploy_all

### Shuts down the core
stop: stop_core

### Allows you to go inside the core and execute bash scripts
shell:
	docker compose exec pixelaw-core bash;

### Outputs katana logs
log_katana:
	docker compose exec pixelaw-core tail -n 200 -f /keiko/log/katana.log.json

### Outputs torii logs
log_torii:
	docker compose exec pixelaw-core tail -f /keiko/log/torii.log

### Outputs bot logs
log_bots:
	docker compose exec pixelaw-core tail -f /keiko/log/bots.log