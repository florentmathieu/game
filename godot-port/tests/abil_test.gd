extends SceneTree
func _initialize() -> void:
	var B = load("res://scenes/Battle.tscn").instantiate()
	get_root().add_child(B)   # _ready construit maillage + unités
	await process_frame
	var mesh = B.mesh
	var mage = null; var sb = null; var players := []
	for u in B.units:
		if u.team == "enemy" and u.abil.has("blast"): mage = u
		if u.team == "enemy" and u.abil.has("shove"): sb = u
		if u.team == "player": players.append(u)
	var ok := true
	# --- BLAST : place 2 joueurs autour d'un centre adjacent au mage ---
	var center := -1
	for n in mesh.cells[mage.cell].nb:
		if mesh.passable(n) and mesh.los(mage.cell, n): center = n; break
	var p1 = players[0]; var p2 = players[1]
	p1.cell = center; p1.hp = p1.max
	var nb2 := -1
	for n in mesh.cells[center].nb:
		if mesh.passable(n): nb2 = n; break
	p2.cell = nb2; p2.hp = p2.max
	mage.cd = {}; mage.ap = B.AP_MAX
	var blasted: bool = B.exec_blast(mage, center)
	var dmg_ok: bool = blasted and p1.hp < p1.max and p2.hp < p2.max
	var cd_ok: bool = B.on_cd(mage, "blast")
	print("BLAST: lancé=%s, p1 touché=%s, p2 touché=%s, cooldown=%s" % [blasted, p1.hp < p1.max, p2.hp < p2.max, cd_ok])
	if not (dmg_ok and cd_ok): ok = false
	# --- FROST ---
	var pf = players[2]; pf.cell = center; pf.slowed = false
	mage.cd = {}; mage.ap = B.AP_MAX
	var froze: bool = B.exec_frost(mage, pf)
	print("FROST: lancé=%s, ralenti=%s" % [froze, pf.slowed])
	if not (froze and pf.slowed): ok = false
	# --- SHOVE (shieldbearer adjacent à un joueur) ---
	if sb != null:
		var pv = players[0]
		var adj := -1
		for n in mesh.cells[sb.cell].nb:
			if mesh.passable(n): adj = n; break
		pv.cell = adj; pv.stunned = false; var before := adj
		sb.cd = {}; sb.ap = B.AP_MAX
		var shoved: bool = B.exec_shove(sb, pv)
		print("SHOVE: lancé=%s, déplacé=%s ou étourdi=%s" % [shoved, pv.cell != before, pv.stunned])
		if not shoved: ok = false
	print("\n%s" % ("OK — capacités fonctionnelles" if ok else "!! échec"))
	quit()
