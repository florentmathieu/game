extends SceneTree
# Vérifie la grenade (cracker : aire + consommation) et la brèche (ouvre un passage).
func _initialize() -> void:
	var B = load("res://scenes/Battle.tscn").instantiate()
	get_root().add_child(B)
	await process_frame
	var mesh = B.mesh
	var ok := true
	# place un sapeur joueur sur une case passable
	var start := -1
	for c in mesh.cells:
		if mesh.passable(c.id): start = c.id; break
	B._make_unit("player", "sapeur", start)
	var sap = B.units[-1]
	print("sapeur crackers=%d (attendu 1)" % int(sap.crackers))
	if int(sap.crackers) != 1: ok = false

	# --- GRENADE : un ennemi à portée dans le rayon prend des dégâts ---
	var cr = sap.w.cracker
	var tgt := -1
	for n in mesh.cells[start].nb:
		if mesh.passable(n) and mesh.los(start, n): tgt = n; break
	# pose un ennemi sur la case visée
	B._make_unit("enemy", "shieldbearer", tgt)
	var foe = B.units[-1]; foe.hp = foe.max
	sap.ap = B.AP_MAX
	var hp0: int = foe.hp
	var thrown: bool = B.exec_cracker(sap, tgt)
	print("GRENADE: lancée=%s, ennemi touché=%s, crackers restants=%d" % [thrown, foe.hp < hp0, int(sap.crackers)])
	if not (thrown and foe.hp < hp0 and int(sap.crackers) == 0): ok = false

	# --- BRÈCHE : un rocher (wall) visé devient praticable ---
	var wallc := -1
	for n in mesh.cells[start].nb:
		if mesh.los(start, n): mesh.cells[n].terr = "wall"; wallc = n; break
	if wallc < 0:
		for c in mesh.cells:
			if mesh.hops(start, c.id) <= B.BREACH_RANGE and mesh.los(start, c.id): mesh.cells[c.id].terr = "wall"; wallc = c.id; break
	sap.cd = {}; sap.ap = B.AP_MAX
	var before_pass: bool = mesh.passable(wallc)
	var breached: bool = B.exec_breach(sap, wallc)
	print("BRÈCHE: avant praticable=%s, lancée=%s, après praticable=%s" % [before_pass, breached, mesh.passable(wallc)])
	if not (breached and mesh.passable(wallc)): ok = false

	# --- POTION : soigne soi-même, consomme un soin ---
	B.potions = 2; sap.ap = B.AP_MAX; sap.hp = max(1, sap.max - 4)
	var php: int = sap.hp; var pot0: int = B.potions
	var healed: bool = B.exec_potion(sap, sap)
	print("POTION: utilisée=%s, PV %d->%d, stock %d->%d" % [healed, php, sap.hp, pot0, B.potions])
	if not (healed and sap.hp > php and B.potions == pot0 - 1): ok = false

	print("\n%s" % ("OK — sapeur (grenade + brèche) + potion fonctionnels" if ok else "!! échec sapeur"))
	quit()
