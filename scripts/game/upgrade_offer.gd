class_name UpgradeOffer
extends RefCounted


## Deterministic, rule-filtered offer. The same seed, wave, and applied
## upgrades always produce the same ordered choice list.
static func roll(
	pool: Array[RunUpgradeDefinition],
	modifiers: RunModifiers,
	run_seed: int,
	wave_index: int,
	count := BalanceConfig.OFFER_CHOICE_COUNT
) -> Array[String]:
	var eligible: Array[RunUpgradeDefinition] = []
	for upgrade in pool:
		if upgrade != null and is_eligible(upgrade, modifiers):
			eligible.append(upgrade)
	eligible.sort_custom(func(a: RunUpgradeDefinition, b: RunUpgradeDefinition) -> bool: return a.id < b.id)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, wave_index])
	var offer: Array[String] = []
	var remaining := eligible.duplicate()
	while offer.size() < count and not remaining.is_empty():
		var pick := rng.randi_range(0, remaining.size() - 1)
		offer.append(remaining[pick].id)
		remaining.remove_at(pick)
	return offer


static func is_eligible(upgrade: RunUpgradeDefinition, modifiers: RunModifiers) -> bool:
	if modifiers.has_upgrade(upgrade.id):
		return false
	for tag in upgrade.excludes_tags:
		if modifiers.has_tag(tag):
			return false
	if upgrade.requires_tags.is_empty():
		return true
	for tag in upgrade.requires_tags:
		if modifiers.has_tag(tag):
			return true
	return false
