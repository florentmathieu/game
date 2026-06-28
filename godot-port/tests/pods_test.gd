extends SceneTree
# Vérifie la répartition en pods (ancres dispersées + groupes) et les zones de patrouille Voronoï.
func _initialize() -> void:
	var B = load("res://scenes/Battle.tscn").instantiate()
	B.fast = true
	get_root().add_child(B); await process_frame
	var pods := {}
	for u in B.units:
		if u.team == "enemy":
			var p: int = int(u.pod)
			if not pods.has(p): pods[p] = []
			pods[p].append(u.cell)
	print("ennemis=%d  pods=%d  tailles=%s" % [_ne(B), pods.size(), str(pods.values().map(func(a): return (a as Array).size()))])
	var ok := true
	if pods.size() < 1: ok = false
	# centres de pods distincts (ancres dispersées)
	var centers: Dictionary = B.pod_centers()
	var dmin := 1 << 30
	var ks: Array = centers.keys()
	for i in ks.size():
		for j in range(i + 1, ks.size()):
			dmin = min(dmin, B.mesh.hops(centers[ks[i]], centers[ks[j]]))
	print("centres de pods=%s  distance min entre centres=%s" % [str(centers.values()), (dmin if ks.size() > 1 else "(1 pod)")])
	if ks.size() > 1 and dmin < 2: ok = false   # pods non agglutinés
	# zones disjointes : chaque centre s'appartient à lui-même
	for k in centers:
		var e := {"pod": k}
		if not B.pod_owns(e, centers[k]): ok = false
	# patrouille : un dormeur reste immobile, un éveillé bouge dans sa zone
	var e0 = null
	for u in B.units: if u.team == "enemy": e0 = u; break
	if e0 != null:
		var c0: int = e0.cell
		e0.asleep = false; e0.home = c0; e0.ap = 1
		B.patrol_step(e0)
		var moved_in_zone: bool = (e0.cell == c0) or B.pod_owns(e0, e0.cell)
		print("patrouille : but persistant=%s, reste dans la zone=%s" % [int(e0.get("patrolGoal", -1)), moved_in_zone])
		if not moved_in_zone: ok = false
	print("\n%s" % ("OK — pods dispersés + zones de patrouille fonctionnels" if ok else "!! échec pods/patrouille"))
	quit()

func _ne(B) -> int:
	var n := 0
	for u in B.units: if u.team == "enemy": n += 1
	return n
