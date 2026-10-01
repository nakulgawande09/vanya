extends GdUnitTestSuite


func test_known_vector() -> void:
	# Standard CRC-32 check value for "123456789".
	assert_int(Crc32.of_string("123456789")).is_equal(0xCBF43926)


func test_empty() -> void:
	assert_int(Crc32.of_string("")).is_equal(0)
