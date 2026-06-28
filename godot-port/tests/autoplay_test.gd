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
func _initialize() -> void:
	var Run = get_root().get_node_or_null("Run")
	Run.new_campaign(); Run.camp.seed = 20260628
	var wins := 0; var n := 10; var lost_soldiers: Array = []
	for i in n:
		if Run.ready_members().size() < 2:
			print("Escouade hors de combat — campagne interrompue."); break
		var diff: int = 1 + i / 3
		Run.set_mission(0, {"name":"Sim%d" % i, "diff":diff, "forge":(i == 5), "boss":false})
		var B = load("res://scenes/Battle.tscn").instantiate()
		get_root().add_child(B); await process_frame
		var ne := 0
		for u in B.units: if u.team == "enemy": ne += 1
		var r: Dictionary = await _run_mission(B)
		var report: Dictionary = B.build_report()
		Run.camp.potions = int(B.potions)
		var deaths: Array = Run.resolve_mission(r.win, report)
		Run.auto_promote()   # tranche les promotions (branche A) pour ne pas bloquer
		B.free()
		if r.win: wins += 1
		for d in deaths: lost_soldiers.append(d)
		var ready: int = Run.ready_members().size()
		print("M%d  diff=%d ennemis=%d %s  tours=%2d | escouade prête=%d/%d%s" % [
			i, diff, ne, ("VICT" if r.win else "DEF "), r.turns, ready, Run.camp.roster.size(),
			("  morts: " + ", ".join(deaths) if not deaths.is_empty() else "")])
	# bilan campagne : grades atteints + usure finale
	print("\n=== Bilan campagne (missionN=%d) ===" % Run.camp.missionN)
	for m in Run.camp.roster:
		var g: String = ["Recrue","Aguerri","Vétéran","Élite","Champion"][_grade(int(m.xp))]
		print("  %-7s %-9s xp=%2d fat=%3d str=%3d %s" % [m.name, g, int(m.xp), int(m.fatigue), int(m.stress), ("MORT" if bool(m.dead) else "")])
	print("\nVictoires : %d/%d  |  pertes définitives : %d (%s)" % [wins, n, lost_soldiers.size(), ", ".join(lost_soldiers) if lost_soldiers.size() else "aucune"])
	quit()

func _grade(xp: int) -> int:
	var t := [0, 3, 7, 12, 17]; var g := 0
	for i in t.size(): if xp >= t[i]: g = i
	return g
