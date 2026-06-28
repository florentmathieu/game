extends Node
# État de campagne partagé (singleton autoload) + paramètres de la prochaine mission.
var camp := {}        # geoStates, missionN, winCount, act, seed, want, forgeDone
var mission := {}     # seed, diff, act, objective, cell, name, forge, boss, enemies

const ACT_MISSIONS := {1:10, 2:20, 3:20}   # régions visées par acte (= want)

func new_campaign() -> void:
	camp = {"geoStates":{}, "missionN":0, "winCount":0, "act":1,
		"seed":(randi() & 0x7fffffff) | 1, "want":ACT_MISSIONS[1],
		"forgeCount":0, "forgeBonus":{"hp":0, "dmg":0}, "lastAttack":-99, "done":false}
	mission = {}

# nombre d'ennemis selon la difficulté (+1 par forge libérée → missions plus denses)
func enemy_count(diff: int, boss: bool) -> int:
	var n := clampi(2 + diff, 3, 7)
	if boss: n += 1
	n += int(camp.get("forgeCount", 0))
	return clampi(n, 3, 9)

# objectif imposé par la nature de la région (le boss se tue ; sinon varié)
func objective_for(boss: bool) -> String:
	if boss: return "assassinate"
	var kinds := ["eliminate", "assassinate", "rescue", "defend", "survive", "extract"]
	return kinds[randi() % kinds.size()]

# construit mission depuis une région du geoscape (info = Geo.info[cell])
func set_mission(cell: int, ginfo: Dictionary) -> void:
	var diff: int = ginfo.diff
	var boss: bool = ginfo.boss
	mission = {
		"seed": (int(camp.seed) ^ (cell * 2654435761) ^ (int(camp.missionN) * 40503)) & 0x7fffffff | 1,
		"diff": diff, "act": int(camp.act), "objective": objective_for(boss),
		"cell": cell, "name": ginfo.name, "forge": ginfo.forge, "boss": boss,
		"enemies": enemy_count(diff, boss) }

# résout l'issue d'une mission : met à jour états, compteurs, forge permanente
func resolve_mission(win: bool) -> void:
	var cell: int = mission.cell
	camp.geoStates[cell] = "cleared" if win else "lost"
	camp.missionN = int(camp.missionN) + 1
	if win:
		camp.winCount = int(camp.winCount) + 1
		if mission.get("forge", false):
			camp.forgeCount = int(camp.forgeCount) + 1
			var n: int = camp.forgeCount
			camp.forgeBonus = {"hp": 3 * n, "dmg": n}   # amélioration permanente d'escouade
