class_name Crc32
## CRC-32 (IEEE 802.3, the zlib polynomial) for save-file integrity checks.

static var _table: PackedInt64Array = PackedInt64Array()


static func of_bytes(data: PackedByteArray) -> int:
	if _table.is_empty():
		_build_table()
	var crc: int = 0xFFFFFFFF
	for b: int in data:
		crc = _table[(crc ^ b) & 0xFF] ^ (crc >> 8)
	return crc ^ 0xFFFFFFFF


static func of_string(text: String) -> int:
	return of_bytes(text.to_utf8_buffer())


static func _build_table() -> void:
	_table.resize(256)
	for i: int in 256:
		var c: int = i
		for _k: int in 8:
			c = (0xEDB88320 ^ (c >> 1)) if (c & 1) else (c >> 1)
		_table[i] = c
