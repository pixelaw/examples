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
        ./deploy_apps.sh $$app_name; \
    done

### Deploys an individual app
# to use make deploy_app APP=<put_app_name_here>
deploy_app:
	./deploy_apps.sh $(APP)

### Deploys an individual app to vanilla core
# to use make deploy_app_vanilla APP=<put_app_name_here>
deploy_app_vanilla:
	./deploy_apps.sh $(APP) vanilla

### Deploys all apps to vanilla core
deploy_all_vanilla:
	@for dir in $(SUBDIRS); do \
    	app_name=$$(basename $$dir); \
        echo "Deploying $$app_name to vanilla core"; \
        ./deploy_apps.sh $$app_name vanilla; \
    done

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

### Clean all Scarb.lock files
clean_locks:
	@echo "Cleaning all Scarb.lock files..."
	@find . -name "Scarb.lock" -not -path "./.devcontainer/*" -delete

### Build all apps
build_all: clean_locks
	@for app in $(APPS); do \
		echo "Building $$app..."; \
		(cd $$app && sozo build) || exit 1; \
	done

### Test all apps
test_all: clean_locks
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