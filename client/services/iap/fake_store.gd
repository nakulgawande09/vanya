class_name FakeStore
extends IapService
## Every purchase succeeds immediately with a fake token.

var purchased: Array[StringName] = []


func purchase(product_id: StringName) -> void:
	purchased.append(product_id)
	purchase_succeeded.emit(product_id, "fake-token-%d" % purchased.size())
