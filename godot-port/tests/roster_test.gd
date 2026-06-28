extends SceneTree
# Vérifie le roster, l'usure (stress/fatigue), l'XP, le repos, la mort définitive.
func _initialize() -> void:
	var Run = get_root().get_node_or_null("Run")
	Run.new_campaign()
	var ok := true
	print("roster=%d  deploySel=%s  prêts=%d" % [Run.camp.roster.size(), Run.camp.deploySel, Run.ready_members().size()])
	if Run.camp.roster.size() != 6 or Run.camp.deploySel.size() != 4: ok = false

	# PV max d'un soldat (10 de base, pas de perk au grade 0)
	var aldric: Dictionary = Run.member("Aldric")
	var dh: Dictionary = Run.mem_deploy_hp(aldric)
	print("Aldric PV déploiement=%d/%d full=%s" % [dh.hp, dh.max, dh.full])
	if dh.max != 10 or not dh.full: ok = false

	# --- mission perdue : un déployé tombe K.O. ---
	Run.set_mission(0, {"name":"Test","diff":1,"forge":false,"boss":false})
	var sel: Array = Run.camp.deploySel
	var fallen: String = sel[1]   # un non-spécial déployé
	var report := {}
	for nm in sel:
		var ko: bool = (nm == fallen)
		report[nm] = {"hp": (0 if ko else 6), "max": 10, "dmgTaken": (8 if ko else 2), "kills": 1, "spellsCast": (2 if nm == "Lys" else 0), "ko": ko}
	# force la mort (DEATH_PCT) en répétant si besoin : on teste surtout fatigue/stress/xp
	var deaths: Array = Run.resolve_mission(false, report)
	var vesna: Dictionary = Run.member(fallen)
	print("%s après défaite K.O. : fatigue=%d stress=%d dead=%s" % [fallen, vesna.fatigue, vesna.stress, vesna.dead])
	if int(vesna.fatigue) < 30 or int(vesna.stress) <= 0: ok = false
	# le mage a dépensé des sorts → fatigue plus élevée
	var lys: Dictionary = Run.member("Lys")
	print("Lys (2 sorts) fatigue=%d (attendu >= 30+12)" % lys.fatigue)
	if int(lys.fatigue) < 42: ok = false
	# un non-déployé se repose (usure nulle au départ → reste 0, carry effacé)
	var doran: Dictionary = Run.member("Doran")
	print("Doran (au repos) fatigue=%d carry=%s" % [doran.fatigue, Run.camp.carry.has("Doran")])

	# --- mission gagnée : XP attribué aux déployés ---
	var xp_before: int = int(Run.member("Aldric").xp)
	Run.set_mission(0, {"name":"T2","diff":1,"forge":false,"boss":false})
	var rep2 := {}
	for nm in Run.camp.deploySel: rep2[nm] = {"hp":8,"max":10,"dmgTaken":1,"kills":2,"spellsCast":0,"ko":false}
	Run.resolve_mission(true, rep2)
	var xp_after: int = int(Run.member("Aldric").xp)
	print("Aldric XP %d -> %d (gagné, 2 kills → +5)" % [xp_before, xp_after])
	if xp_after - xp_before != 5: ok = false

	# --- promotion : montée au grade 1 → choix A/B (B « Tenace » = +4 PV pour le soldat) ---
	var promos: Array = Run.camp.pendingPromos
	var has_aldric := false
	for pr in promos: if pr.name == "Aldric": has_aldric = true
	print("promotions en attente=%d, Aldric promu=%s" % [promos.size(), has_aldric])
	if not has_aldric: ok = false
	var hp_before: int = Run.mem_max_hp(Run.member("Aldric"))
	Run.choose_promo("Aldric", "B")
	var hp_after2: int = Run.mem_max_hp(Run.member("Aldric"))
	print("Aldric PV max %d -> %d après perk B" % [hp_before, hp_after2])
	if hp_after2 - hp_before != 4: ok = false

	# --- mort répétée : avec DEATH_PCT, finit par tuer un K.O. en défaite ---
	var died := false
	for it in 40:
		var v: Dictionary = Run.member("Cael")
		if v.is_empty() or bool(v.dead): died = true; break
		Run.set_mission(0, {"name":"T","diff":1,"forge":false,"boss":false})
		if not Run.camp.deploySel.has("Cael"): Run.camp.deploySel = ["Cael"]
		Run.resolve_mission(false, {"Cael":{"hp":0,"max":6,"dmgTaken":6,"kills":0,"spellsCast":0,"ko":true}})
	print("mort définitive de Cael survenue=%s" % died)
	if not died: ok = false

	# --- sauvegarde / chargement ---
	Run.save_game()
	var snapshot: int = int(Run.member("Aldric").xp)
	Run.camp = {}
	var loaded: bool = Run.load_game()
	print("rechargé=%s  XP Aldric conservé=%s" % [loaded, int(Run.member("Aldric").xp) == snapshot])
	if not loaded or int(Run.member("Aldric").xp) != snapshot: ok = false

	print("\n%s" % ("OK — roster/usure/mort/sauvegarde cohérents" if ok else "!! échec roster"))
	quit()
