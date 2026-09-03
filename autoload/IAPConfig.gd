extends Node

enum SkuType { CONSUMABLE, NON_CONSUMABLE }

const SKUS := {
	"instant_coins_1": "com.batikboutique.instant_coins_1",
	"instant_coins_2": "com.batikboutique.instant_coins_2",
	"instant_coins_3": "com.batikboutique.instant_coins_3",
}

const SKU_TYPES := {
	"com.batikboutique.instant_coins_1": SkuType.CONSUMABLE,
	"com.batikboutique.instant_coins_2": SkuType.CONSUMABLE,
	"com.batikboutique.instant_coins_3": SkuType.CONSUMABLE,
}

const COIN_REWARDS := {
	"instant_coins_1": 50000,
	"instant_coins_2": 125000,
	"instant_coins_3": 225000,
}

static func get_sku(key: String) -> String:
	return SKUS.get(key, "")

static func get_coin_reward(sku: String) -> int:
	for key in SKUS:
		if SKUS[key] == sku:
			return COIN_REWARDS.get(key, 0)
	return 0

static func get_type(sku: String) -> SkuType:
	return SKU_TYPES.get(sku, SkuType.CONSUMABLE)
