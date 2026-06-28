extends SceneTree
# Vérifie l'interpréteur de graphe : chargement, routage texte/mission/choix, recrue, instanciation.
func _initialize() -> void:
	var Run = get_root().get_node_or_null("Run")
	var data := {"name":"G", "start":"n0", "roster":[{"name":"Aldric","cls":"soldat","special":true}],
		"nodes":[
			{"id":"n0", "type":"text", "text":"Intro", "next":"m1"},
			{"id":"m1", "type":"mission", "mission":"alpha", "intro":"avant", "outro":"apres", "win":"c1", "lose":"n0"},
			{"id":"c1", "type":"choice", "title":"Nord ou Sud ?", "options":["tN", "mS"]},
			{"id":"tN", "type":"text", "text":"Nord. Fin.", "next":""},
			{"id":"mS", "type":"mission", "mission":"sud", "win":"", "lose":""}]}
	Run.apply_campaign(data, Run.campaign_sig(data))
	var ok := true
	if not Run.has_graph(): ok = false
	if String(Run.node_by_id("c1").get("type", "")) != "choice": ok = false

	# parcours du chemin principal (1re option des choix)
	var id := String(Run.camp.graphStart); var guard := 0; var missions := 0; var saw_choice := false
	while id != "" and guard < 50:
		guard += 1
		var n: Dictionary = Run.node_by_id(id)
		if n.is_empty(): break
		match String(n.get("type", "")):
			"text": id = String(n.get("next", ""))
			"mission": missions += 1; id = String(n.get("win", ""))
			"choice": saw_choice = true; id = String((n.get("options", []) as Array)[0])
			_: id = String(n.get("next", ""))
	print("parcours : missions=%d  choix=%s  fin atteinte=%s" % [missions, saw_choice, id == ""])
	if not (missions >= 1 and saw_choice and id == ""): ok = false

	# recrue scénarisée (* = héros spécial)
	Run.apply_recruit("Kael:archer*")
	var k: Dictionary = Run.member("Kael")
	print("recrue : Kael special=%s cls=%s" % [k.get("special", "?"), k.get("cls", "?")])
	if k.is_empty() or not bool(k.get("special", false)) or String(k.get("cls", "")) != "archer": ok = false

	# Game s'instancie en mode graphe sans erreur (joue le 1er nœud texte)
	Run.camp.nodeId = String(Run.camp.graphStart)
	var game = load("res://scenes/Game.tscn").instantiate()
	get_root().add_child(game); await process_frame; await process_frame
	print("Game instancié, has_graph=%s nodeId=%s" % [Run.has_graph(), Run.camp.get("nodeId", "")])

	print("\n%s" % ("OK — interpréteur de graphe (choix/branches) fonctionnel" if ok else "!! échec graphe"))
	quit()
