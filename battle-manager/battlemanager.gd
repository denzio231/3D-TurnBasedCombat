extends Node3D

var players: Array = []
var enemies: Array = []
var turn_order: Array = []
var current_turn: int = 0

var current_battler
var default_anim = "Locomotion-Library/idle2"

@export var OriginalMap = "res://maps/regular_map/backtogame.tscn"

@onready var hud: CanvasLayer = $BattleHUD

# Toggles For Battles
@export var Attack_Toggle: bool = true
@export var Skills_Toggle: bool = true
@export var Defend_Toggle: bool = true
@export var Item_Toggle: bool = true
@export var Run_Toggle: bool = true

func _ready():
	if not hud:
		push_error("BattleHUD node not found. Please make sure it's added to the scene.")
		return
	if not hud.is_connected("action_selected", _on_action_selected):
		hud.action_selected.connect(_on_action_selected)
	initialize_battle()
	# Checking Toggles!
	$BattleHUD/ActionButtons/Attack.disabled = not Attack_Toggle
	$BattleHUD/ActionButtons/Skills.disabled = not Skills_Toggle
	$BattleHUD/ActionButtons/Defend.disabled = not Defend_Toggle
	$BattleHUD/ActionButtons/Items.disabled = not Item_Toggle
	$BattleHUD/ActionButtons/Run.disabled = not Run_Toggle

func initialize_battle():
	players = get_tree().get_nodes_in_group("players")
	enemies = get_tree().get_nodes_in_group("enemies")
	
	for player in players:
		hud.on_add_character(player)
		player.battle_idle()
	
	# Ensure players are at the start of the turn order
	turn_order = players + enemies
	
	if enemies.size() > 0:
		hud.on_start_combat(enemies[0])  # Assuming single enemy for now
		enemies[0].battle_idle()

	start_next_turn()

func start_next_turn():
	if is_battle_over():
		end_battle()
		return

	var current_character = turn_order[current_turn]
	current_battler = current_character
	
	if current_character.is_defeated():
		turn_order.erase(current_character)
		current_turn = current_turn % turn_order.size()
		start_next_turn()
		return
	
	if current_character in players:
		player_turn(current_character)
	else:
		enemy_turn(current_character)

	update_hud()

func player_turn(character):
	hud.set_active_character(character)
	hud.show_action_buttons(character)

func _on_action_selected(action: String, target):
	print("Action selected: ", action, " Target: ", target.name if target else "None")
	var current_character = turn_order[current_turn]
	print("Current character: ", current_character.name)
	match action:
		"attack":
			perform_attack(current_character, target)
		"defend":
			perform_defend(current_character)
		"skills":
			perform_skill(current_character, target)
		"item":
			perform_item(current_character)
	
	process_exp_gain(current_character, target) # EDIT: Temp exp access/effect - gain exp on turn end
	
	end_turn()

func process_exp_gain(user, target):
	if not target:
		return
	var exp_gained = target.get_exp_stat().get_exp_on_kill()
	user.get_exp_stat().add_exp(exp_gained)
	user.gain_experience(exp_gained)

func perform_attack(attacker, target):
	var damage = attacker.attack_anim()
	damage_calculation(attacker, target, damage)

func perform_defend(character):
	character.defend()
	print("%s is defending!" % character.character_name)

func perform_skill(attacker, target):
	var damage = attacker.skill_attack()
	damage_calculation(attacker, target, damage)

func perform_item(user):
	var amount = user.skill_heal()
	heal_calculation(user, user, amount)

func damage_calculation(attacker, target, damage):
	damage = Formulas.physical_damage(attacker, target, damage)
	print("%s attacks %s for %d damage!" % [attacker.character_name, target.character_name, damage])
	target.take_damage(damage)
	update_hud()

func heal_calculation(user, target, amount):
	var healing = target.take_healing(amount)
	print("%s heals %s for %d health!" % [user.character_name, target.character_name, healing])
	update_hud()

func enemy_turn(character):
	var target = players[randi() % players.size()]  # Choose a random player to attack
	perform_attack(character, target)
	end_turn()

func end_turn():
	await current_battler.wait_attack()

	current_turn = (current_turn + 1) % turn_order.size()
	start_next_turn()

func update_hud():
	hud.update_character_info()
	if turn_order[current_turn] in players:
		hud.show_action_buttons(turn_order[current_turn])
	else:
		hud.hide_action_buttons()

func is_battle_over():
	return are_all_defeated(players) or are_all_defeated(enemies)

func are_all_defeated(characters: Array):
	for character in characters:
		if not character.is_defeated():
			return false
	return true

func end_battle():
	if are_all_defeated(enemies):
		hud.show_battle_result("Victory! All enemies have been defeated.")
		for player in players:
			player.gain_experience(100)
			# Toggle Enemy's off on the scene you left.
			get_tree().change_scene_to_file(OriginalMap) # This code causes the crash.
	elif are_all_defeated(players):
		hud.show_battle_result("Game Over. All players have been defeated.")
	hud.hide_action_buttons()

func update_button_states():
	$BattleHUD/ActionButtons/Attack.disabled = not Attack_Toggle
	$BattleHUD/ActionButtons/Skills.disabled = not Skills_Toggle
	$BattleHUD/ActionButtons/Defend.disabled = not Defend_Toggle
	$BattleHUD/ActionButtons/Items.disabled = not Item_Toggle
	$BattleHUD/ActionButtons/Run.disabled = not Run_Toggle
