extends SceneTree
# Vérifie le chargement d'une campagne scénarisée depuis un JSON.
func _initialize() -> void:
	var Run = get_root().get_node_or_null("Run")
	var ok: bool = Run.load_campaign_file("res://campaigns/marche.json")
	print("chargé=%s  titre=%s  roster=%d" % [ok, Run.camp.get("title", ""), (Run.camp.get("roster", []) as Array).size()])
	if not ok: print("!! échec chargement"); quit(); return
	var good := true
	if String(Run.camp.title) != "La Marche de Velhaur": good = false
	if (Run.camp.roster as Array).size() != 7: good = false
	if int(Run.want_for_act(1)) != 10 or int(Run.want_for_act(2)) != 20: good = false
	# narratif scénarisé présent
	var narr: Dictionary = Run.camp.get("narr", {})
	var a1 = narr.get("1", {})
	var has_dialogue: bool = typeof(a1) == TYPE_DICTIONARY and String(a1.get("arrive", "")).contains("Aldric:")
	print("want a1=%d a2=%d  | dialogue scénarisé acte 1=%s" % [Run.want_for_act(1), Run.want_for_act(2), has_dialogue])
	if not has_dialogue: good = false
	# Aldric reste le héros spécial, et la graine est celle du fichier
	if not bool(Run.member("Aldric").special): good = false
	print("seed=%d (attendu impair, du fichier 4071)" % int(Run.camp.seed))
	print("\n%s" % ("OK — campagne scénarisée JSON chargée" if good else "!! incohérence campagne JSON"))
	quit()
