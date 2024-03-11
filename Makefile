PROFILE ?= dev
APP ?= paint

start_core:
	docker compose up -d

stop_core:
	docker compose down

build_apps:
	cd hunter && sozo  build;
	cd minesweeper && sozo  build;
	cd rps && sozo  build;
	cd tictactoe && sozo  build;

migrate_apps:
	cd hunter && sozo --profile $(PROFILE) migrate;
	cd minesweeper && sozo --profile $(PROFILE) migrate;
	cd rps && sozo --profile $(PROFILE) migrate;
	cd tictactoe && sozo --profile $(PROFILE) migrate;

initialize_apps:
	cd hunter; scarb --profile $(PROFILE) run initialize;
	cd minesweeper; scarb --profile $(PROFILE) run initialize;
	cd rps; scarb --profile $(PROFILE) run initialize;
	cd tictactoe; scarb --profile $(PROFILE) run initialize;

upload_manifests:
	cd hunter; scarb --profile $(PROFILE) run upload_manifest;
	cd minesweeper; scarb --profile $(PROFILE) run upload_manifest;
	cd rps; scarb --profile $(PROFILE) run upload_manifest;
	cd tictactoe; scarb --profile $(PROFILE) run upload_manifest;

deploy_demo:
	$(MAKE)  migrate_apps PROFILE=demo;
	$(MAKE)  initialize_apps PROFILE=demo;
	$(MAKE)  upload_manifests PROFILE=demo;

start:
	$(MAKE)  start_core;
	$(MAKE)  build_apps;
	$(MAKE)  migrate_apps;
	$(MAKE)  initialize_apps;
	$(MAKE)  upload_manifests;

# starts only one app
start_app:
	cd $(APP) && sozo build;
	cd $(APP) && sozo --profile $(PROFILE) migrate;
	cd $(APP); scarb --profile $(PROFILE) run initialize;
	cd $(APP); scarb --profile $(PROFILE) run upload_manifest;

reset:
	docker compose down -v
	docker compose up -d

stop: stop_core


shell:
	docker compose exec pixelaw-core bash;

log_katana:
	docker compose exec pixelaw-core tail -f /keiko/log/katana.log.json

log_torii:
	docker compose exec pixelaw-core tail -f /keiko/log/torii.log

log_bots:
	docker compose exec pixelaw-core tail -f /keiko/log/bots.log