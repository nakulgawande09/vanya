class_name Emissive
## Lifts a visual's "Emissive" node (eye, flame, heart and spirit glows) onto the emissive layer,
## above the darkness veil, and keeps it glued to the visual with a RemoteTransform2D.


static func lift(visual: Node, layer: Node) -> Node2D:
	var glow: Node2D = visual.find_child("Emissive", true, false) as Node2D
	if glow == null or layer == null:
		return null
	var parent: Node = glow.get_parent()
	var follow: RemoteTransform2D = RemoteTransform2D.new()
	follow.name = "EmissiveFollow"
	parent.add_child(follow)
	follow.position = glow.position
	parent.remove_child(glow)
	layer.add_child(glow)
	follow.remote_path = follow.get_path_to(glow)
	return glow


## Frees a lifted glow when its owner is freed or parked.
static func drop(glow: Node2D) -> void:
	if glow != null and is_instance_valid(glow):
		glow.queue_free()
