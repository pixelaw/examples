# sets the individual app to deploy with deploy_app
APP ?= paint

# To get all the subdirectories in this directory
SUBDIRS := $(wildcard */)

# Get all app directories (those with Scarb.toml files)
APPS := $(shell find . -maxdepth 2 -name 'Scarb.toml' -not -path './.devcontainer/*' | xargs dirname | sort)

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

### Build all apps
build_all:
	@for app in $(APPS); do \
		echo "Building $$app..."; \
		(cd $$app && sozo build) || exit 1; \
	done

### Test all apps
test_all:
	@for app in $(APPS); do \
		echo "Testing $$app..."; \
		(cd $$app && sozo test) || exit 1; \
	done

### Format all apps
fmt_all:
	@for app in $(APPS); do \
		echo "Formatting $$app..."; \
		(cd $$app && scarb fmt) || exit 1; \
	done

### Check the format of all apps
fmt_check:
	@for app in $(APPS); do \
		echo "Checking format of $$app..."; \
		(cd $$app && scarb fmt --check) || exit 1; \
	done