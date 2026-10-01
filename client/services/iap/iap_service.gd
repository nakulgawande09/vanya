class_name IapService
extends RefCounted
## IAP interface. Entitlements are granted only after server verification (/v1/iap/verify).
## Real adapter: hyochan godot-iap (StoreKit 2 + Play Billing 8+), see docs/standards.md §C7.

@warning_ignore_start("unused_signal")
signal purchase_succeeded(product_id: StringName, token: String)
signal purchase_pending(product_id: StringName)
signal purchase_failed(product_id: StringName, reason: String)
@warning_ignore_restore("unused_signal")


func initialize() -> void:
	pass


func purchase(_product_id: StringName) -> void:
	pass


func restore_purchases() -> void:
	pass
