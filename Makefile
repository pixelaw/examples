start_core:
	docker compose up --force-recreate -d

stop_core:
	docker compose down

build_apps:
	sozo build --manifest-path ./hunter/Scarb.toml;
	sozo build --manifest-path ./minesweeper/Scarb.toml;
	sozo build --manifest-path ./rps/Scarb.toml;
	sozo build --manifest-path ./tictactoe/Scarb.toml;

migrate_apps:
	# cd hunter; scarb run ready_for_deployment;
	sozo migrate --name pixelaw --manifest-path ./hunter/Scarb.toml;
	sozo migrate --name pixelaw --manifest-path ./minesweeper/Scarb.toml;
	sozo migrate --name pixelaw --manifest-path ./rps/Scarb.toml;
	sozo migrate --name pixelaw --manifest-path ./tictactoe/Scarb.toml;

initialize_apps:
	cd hunter; scarb run initialize;
	cd minesweeper; scarb run initialize;
	cd rps; scarb run initialize;
	cd tictactoe; scarb run initialize;

upload_manifests:
	cd hunter; scarb run upload_manifest;
	cd minesweeper; scarb run upload_manifest;
	cd rps; scarb run upload_manifest;
	cd tictactoe; scarb run upload_manifest;

start:
	make start_core;
	make build_apps;
	make migrate_apps;
	make initialize_apps;
	make upload_manifests;

stop: stop_core
