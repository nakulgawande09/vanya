class_name VarUtil
## Typed conversions for untyped data (JSON, OS info dictionaries) under strict typing rules.


static func to_int(value: Variant, fallback: int = 0) -> int:
	match typeof(value):
		TYPE_INT:
			var i: int = value
			return i
		TYPE_FLOAT:
			var f: float = value
			return int(f)
		TYPE_BOOL:
			var b: bool = value
			return int(b)
		TYPE_STRING, TYPE_STRING_NAME:
			var s: String = str(value)
			return s.to_int() if s.is_valid_int() else fallback
	return fallback
