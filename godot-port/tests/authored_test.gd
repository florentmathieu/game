extends SceneTree
# Pont 2 : une carte exportée (format éditeur HTML) se recharge dans Battle (maillage+unités+objectif).
# Pont 1 : une campagne format HTML (nodes+roster+missions) se convertit (roster+narratif+cartes).
func _initialize() -> void:
	var Run = get_root().get_node_or_null("Run")
	Run.new_campaign()
	# --- construire une carte procédurale puis l'EXPORTER au format authored ---
	var B1 = load("res://scenes/Battle.tscn").instantiate(); B1.fast = true
	get_root().add_child(B1); await process_frame
	var cells_data := []
	for c in B1.mesh.cells:
		var poly := []
		for v in c.poly: poly.append([v.x, v.y])
		cells_data.append({"poly":poly, "terr":c.terr, "elev":c.elev})
	var walls_data: Array = B1.mesh.walls.keys()
	var units_data := []
	for u in B1.units: units_data.append({"team":u.team, "cls":u.cls, "cell":u.cell})
	var n_enemy1 := 0
	for u in B1.units: if u.team == "enemy": n_enemy1 += 1
	var authored := {"cells":cells_data, "walls":walls_data, "units":units_data, "objective":"eliminate"}
	B1.free()

	# --- RECHARGER cette carte authored dans une nouvelle bataille ---
	Run.mission = {"seed":1, "map":authored, "objective":"eliminate", "diff":1, "boss":false, "name":"Authored"}
	var B2 = load("res://scenes/Battle.tscn").instantiate(); B2.fast = true
	get_root().add_child(B2); await process_frame
	var ok := true
	var same_cells: bool = B2.mesh.cells.size() == cells_data.size()
	var same_walls: bool = B2.mesh.walls.size() == walls_data.size()
	var n_enemy2 := 0; var n_player2 := 0
	for u in B2.units:
		if u.team == "enemy": n_enemy2 += 1
		elif u.team == "player": n_player2 += 1
	print("Pont 2 — cellules %d=%d:%s  murets %d=%d:%s  ennemis=%d (src %d)  joueurs=%d  obj=%s" % [
		B2.mesh.cells.size(), cells_data.size(), same_cells, B2.mesh.walls.size(), walls_data.size(), same_walls, n_enemy2, n_enemy1, n_player2, B2.objective])
	if not (same_cells and same_walls and n_enemy2 == n_enemy1 and n_player2 >= 1 and B2.objective == "eliminate"): ok = false
	B2.free()

	# --- Pont 1 : campagne format éditeur HTML (GRAPHE) → carte inlinée + TES textes par nœud ---
	var html_camp := {"name":"Essai HTML", "start":"n0",
		"roster":[{"name":"Zed","cls":"soldat","special":false}, {"name":"Nyx","cls":"assassin"}],
		"nodes":[
			{"id":"n0", "type":"text", "text":"Narrateur: La campagne commence.", "next":"m0"},
			{"id":"m0", "type":"mission", "mission":"alpha", "_map":authored,
				"intro":"Aldric: Premiere cible en vue.", "outro":"Vesna: Zone securisee.", "win":"", "lose":""}]}
	Run.apply_campaign(html_camp, Run.campaign_sig(html_camp))
	var conv_ok: bool = String(Run.camp.title) == "Essai HTML" and (Run.camp.roster as Array).size() == 2 and Run.has_graph()
	var mnode: Dictionary = Run.node_by_id("m0")
	var map_ok: bool = typeof(mnode.get("_map", null)) == TYPE_DICTIONARY and (mnode["_map"] as Dictionary).has("cells")
	var intro_ok: bool = String(mnode.get("intro", "")).contains("Aldric:")
	var outro_ok: bool = String(mnode.get("outro", "")).contains("Vesna:")
	print("Pont 1 — titre/roster/graphe=%s  carte inlinée=%s  TON intro=%s  TON outro=%s" % [conv_ok, map_ok, intro_ok, outro_ok])
	if not (conv_ok and map_ok and intro_ok and outro_ok): ok = false

	print("\n%s" % ("OK — ponts HTML→Godot (campagne + carte) fonctionnels" if ok else "!! échec ponts"))
	quit()
