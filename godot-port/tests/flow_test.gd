extends SceneTree
# Vérifie le câblage réel des scènes : Game → Geoscape → (région) → Battle → (issue) → Geoscape.
func _initialize() -> void:
	var Run = get_root().get_node_or_null("Run")
	Run.new_campaign(); Run.camp.seed = 777
	var game = load("res://scenes/Game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var ok := true
	if game.geoscape == null: print("!! geoscape non affiché"); ok = false
	else:
		var acc = game.geoscape.geo.accessible(game.geoscape.states)
		var cell: int = acc.keys()[0]
		print("région choisie=%d (%s)" % [cell, game.geoscape.geo.info[cell].name])
		game._on_region(cell)          # ouvre l'écran de sélection d'escouade
		await process_frame
		game._confirm_region()         # valide l'escouade auto-sélectionnée → lance le combat
		await process_frame
		await process_frame
		if game.battle == null: print("!! battle non instancié"); ok = false
		else:
			var ne := 0
			for u in game.battle.units: if u.team == "enemy": ne += 1
			print("battle: objectif=%s ennemis=%d (attendu %d)" % [game.battle.objective, ne, Run.mission.enemies])
			if game.battle.objective != Run.mission.objective: ok = false
			if ne != Run.mission.enemies: ok = false
			# simule l'issue (victoire) sans attendre le timer de 2.4 s
			game._on_mission_end(true)
			await process_frame
			await process_frame
			if game.battle != null: print("!! battle non libéré"); ok = false
			if game.geoscape == null: print("!! retour geoscape échoué"); ok = false
			var st := String(Run.camp.geoStates.get(cell, ""))   # cleared, ou re-attaquée par un raid (14 %)
			if st != "cleared" and st != "attacked": print("!! région non résolue (%s)" % st); ok = false
			print("retour territoire OK, missionN=%d" % Run.camp.missionN)
	print("\n%s" % ("OK — câblage des scènes fonctionnel" if ok else "!! échec câblage"))
	quit()
