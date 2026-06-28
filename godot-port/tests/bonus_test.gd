extends SceneTree
# Vérifie la mission bonus : PV conservés exactement, usure mini, récompense, pas de progression geoscape.
func _initialize() -> void:
	var Run = get_root().get_node_or_null("Run")
	Run.new_campaign(); Run.camp.seed = 999
	var ok := true
	Run.set_mission(0, {"name":"M","diff":2,"forge":false,"boss":false})
	var sel: Array = Run.camp.deploySel
	# PV reportés bas après le 1er combat
	for nm in sel: Run.camp.carry[nm] = 3

	# PV exact (bonus) vs soin partiel (normal)
	var m: Dictionary = Run.member(sel[0])
	var exact: Dictionary = Run.mem_deploy_hp(m, true)
	var partial: Dictionary = Run.mem_deploy_hp(m, false)
	print("carry=3 → bonus(exact)=%d, normal(soin partiel)=%d" % [exact.hp, partial.hp])
	if exact.hp != 3 or partial.hp <= 3: ok = false

	# mission bonus
	var mN0: int = int(Run.camp.missionN)
	Run.set_mission(0, {"name":"M2","diff":2,"forge":false,"boss":false})
	Run.set_bonus_mission()
	print("bonus: drapeau=%s ennemis=%d objectif=%s" % [Run.mission.get("bonus", false), Run.mission.enemies, Run.mission.objective])
	if not bool(Run.mission.get("bonus", false)): ok = false

	# résolution gagnée : +1 soin, usure montée, pas de missionN++
	var pot0: int = int(Run.camp.potions)
	var rep := {}
	for nm in sel: rep[nm] = {"hp":5, "max":10, "dmgTaken":2, "kills":1, "spellsCast":0, "ko":false}
	Run.resolve_bonus(true, rep)
	print("potions %d→%d (attendu +1) ; missionN %d→%d (inchangé)" % [pot0, Run.camp.potions, mN0, Run.camp.missionN])
	if int(Run.camp.potions) != pot0 + 1: ok = false
	if int(Run.camp.missionN) != mN0: ok = false
	var dep0: Dictionary = Run.member(sel[0])
	print("%s fatigue=%d (mini, montée)" % [sel[0], dep0.fatigue])
	if int(dep0.fatigue) < 30: ok = false

	print("\n%s" % ("OK — mission bonus cohérente" if ok else "!! échec mission bonus"))
	quit()
