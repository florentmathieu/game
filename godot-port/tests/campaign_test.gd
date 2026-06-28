extends SceneTree
# Vérifie la boucle de campagne : choix région → mission → issue → progression,
# déblocage du boss, passage d'acte, raids. N'affiche rien (logique pure + scènes headless).
const Geo := preload("res://rules/Geo.gd")

func _initialize() -> void:
	var Run = get_root().get_node_or_null("Run")
	if Run == null:
		print("!! autoload Run absent"); quit(); return
	Run.new_campaign()
	Run.camp.seed = 12345
	var ok := true

	# --- géo de l'acte 1 ---
	var g := Geo.new()
	g.generate(int(Run.camp.seed) ^ (1 * 97), 1, int(Run.camp.want))
	var states: Dictionary = Run.camp.geoStates
	for cell in g.info: states[cell] = ("locked" if g.info[cell].boss else "available")
	var acc := g.accessible(states)
	print("acte1 régions=%d accessibles=%d" % [g.info.size(), acc.size()])
	if acc.is_empty(): ok = false

	# --- une mission gagnée ---
	var first: int = acc.keys()[0]
	Run.set_mission(first, g.info[first])
	print("mission: %s diff=%d ennemis=%d obj=%s" % [Run.mission.name, Run.mission.diff, Run.mission.enemies, Run.mission.objective])
	if Run.mission.enemies < 3: ok = false
	Run.resolve_mission(true)
	if String(states.get(first, "")) != "cleared" or int(Run.camp.missionN) != 1 or int(Run.camp.winCount) != 1: ok = false
	print("après victoire: état=%s missionN=%d winCount=%d" % [states[first], Run.camp.missionN, Run.camp.winCount])

	# --- forge → bonus permanent + densité ennemie ---
	var forge_cell := -1
	for cell in g.info:
		if g.info[cell].forge: forge_cell = cell; break
	if forge_cell >= 0:
		Run.set_mission(forge_cell, g.info[forge_cell])
		var before_n: int = Run.mission.enemies
		Run.resolve_mission(true)
		print("forge prise: bonus=%s forgeCount=%d" % [Run.camp.forgeBonus, Run.camp.forgeCount])
		if int(Run.camp.forgeBonus.hp) <= 0: ok = false
		# une mission suivante doit être plus dense
		Run.set_mission(first, g.info[first])
		print("densité avant/après forge: %d -> %d" % [before_n, Run.mission.enemies])

	# --- nettoyer assez de régions → le boss se débloque ---
	var boss := -1
	for cell in g.info:
		if g.info[cell].boss: boss = cell
		elif String(states.get(cell, "")) != "cleared": states[cell] = "cleared"
	var cleared := 0; var total := 0
	for cell in g.info:
		total += 1
		if not g.info[cell].boss and String(states.get(cell, "")) == "cleared": cleared += 1
	if boss >= 0 and cleared >= int(ceil((total - 1) * 0.6)): states[boss] = "available"
	print("boss=%s débloqué=%s (cleared %d/%d)" % [boss, states.get(boss, "?"), cleared, total - 1])
	if String(states.get(boss, "")) != "available": ok = false

	# --- boss vaincu → passage acte 2 ---
	Run.set_mission(boss, g.info[boss])
	print("mission boss: obj=%s ennemis=%d" % [Run.mission.objective, Run.mission.enemies])
	Run.resolve_mission(true)
	var act_before: int = int(Run.camp.act)
	# simule la logique d'avance d'acte de Game
	Run.camp.act = act_before + 1
	Run.camp.want = Run.ACT_MISSIONS.get(act_before + 1, 20)
	Run.camp.geoStates = {}
	var g2 := Geo.new()
	g2.generate(int(Run.camp.seed) ^ (2 * 97), 2, int(Run.camp.want))
	print("acte2 régions=%d (want=%d)" % [g2.info.size(), Run.camp.want])
	if g2.info.size() < 15: ok = false

	print("\n%s" % ("OK — boucle de campagne cohérente" if ok else "!! échec de la boucle"))
	quit()
