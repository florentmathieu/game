extends SceneTree
# Auto-joueur headless : pilote l'escouade (heuristique gloutonne) contre l'IA ennemie
# réelle de Battle, mission jouée jusqu'à résolution. Mesure un taux de victoire (équilibrage).
# Lance plusieurs missions en faisant croître missionN (distorsion + densité ennemie progressives).

func _player_turn(B) -> void:
	var acted := true; var safety := 0
	while acted and safety < 60:
		safety += 1; acted = false
		for i in B.units.size():
			var u = B.units[i]
			if u.team != "player" or u.hp <= 0 or u.ap <= 0: continue
			B.sel = i; B._compute_reach()
			# 1) tirer/frapper la meilleure cible à portée (plus bas PV d'abord)
			var bt := -1; var bk := -1
			for j in B.units.size():
				var e = B.units[j]
				if e.team == "enemy" and e.hp > 0 and B._can_attack(u, e):
					var k: int = 1000 - int(e.hp)
					if k > bk: bk = k; bt = j
			if bt >= 0:
				B._do_attack(i, bt); acted = true
				if B.over: return
				continue
			# 2) sinon se diriger vers un objectif : zone d'extraction si « extract », sinon l'ennemi le plus proche
			var goal := -1
			if B.objective == "extract" and not B.exit_set.is_empty():
				var gd := 1 << 30
				for c in B.exit_set.keys():
					if B._unit_at(c) >= 0 and c != u.cell: continue
					var h: int = B.mesh.hops(u.cell, c)
					if h < gd: gd = h; goal = c
			if goal < 0:
				var fd := 1 << 30
				for j in B.units.size():
					var e = B.units[j]
					if e.team == "enemy" and e.hp > 0:
						var h: int = B.mesh.hops(u.cell, e.cell)
						if h < fd: fd = h; goal = e.cell
			if goal < 0: continue
			var best: int = u.cell; var bd: int = B.mesh.hops(u.cell, goal)
			for cell in B.reachable:
				var h: int = B.mesh.hops(cell, goal)
				if h < bd: bd = h; best = cell
			if best != u.cell:
				u.ap -= B.ap_for_move(u, B.reachable[best]); u.freeAvail = false
				u.facing = atan2(B.mesh.cells[best].cy - B.mesh.cells[u.cell].cy, B.mesh.cells[best].cx - B.mesh.cells[u.cell].cx)
				u.cell = best; B._place(u); B.react_to(u); B.detect_enemies()
				if u.hp > 0: acted = true

func _run_mission(B) -> Dictionary:
	var turns := 0
	while not B.over and turns < 30:
		turns += 1
		_player_turn(B)
		if B.over: break
		await B._end_turn()
	var win: bool = B.over and B.hud.text.contains("Victoire")
	return {"win":win, "turns":turns}

# CAMPAGNE CONTINUE : même roster, usure/XP/morts portés de mission en mission (resolve_mission).
func _campaign(Run, seed_value: int, n: int) -> Dictionary:
	Run.new_campaign(); Run.camp.seed = seed_value
	var wins := 0; var lost: Array = []
	for i in n:
		if Run.ready_members().size() < 2: break
		var diff: int = 1 + i / 3
		Run.set_mission(0, {"name":"Sim%d" % i, "diff":diff, "forge":(i == 5), "boss":false})
		var B = load("res://scenes/Battle.tscn").instantiate()
		B.fast = true
		get_root().add_child(B); await process_frame
		var r: Dictionary = await _run_mission(B)
		var report: Dictionary = B.build_report()
		Run.camp.potions = int(B.potions)
		var deaths: Array = Run.resolve_mission(r.win, report)
		Run.auto_promote()
		B.free()
		if r.win: wins += 1
		for d in deaths: lost.append(d)
	return {"wins":wins, "n":n, "lost":lost}

func _initialize() -> void:
	var Run = get_root().get_node_or_null("Run")
	var seeds := [20260628, 1337, 90210, 555]
	var total_w := 0; var total_n := 0; var total_lost := 0
	for s in seeds:
		var c: Dictionary = await _campaign(Run, s, 6)
		total_w += int(c.wins); total_n += int(c.n); total_lost += (c.lost as Array).size()
		print("campagne seed=%-9d : %d/%d victoires, %d mort(s)" % [s, c.wins, c.n, (c.lost as Array).size()])
	print("\n=== AGRÉGAT (IA naïve) : %d/%d victoires (%.0f%%), %d pertes définitives ===" % [
		total_w, total_n, 100.0 * total_w / total_n, total_lost])
	quit()

func _grade(xp: int) -> int:
	var t := [0, 3, 7, 12, 17]; var g := 0
	for i in t.size(): if xp >= t[i]: g = i
	return g
