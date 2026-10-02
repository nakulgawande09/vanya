extends GdUnitTestSuite
## Vertical layering rules (Audio Bible A3): stem table, 4 s hysteresis, one change per bar,
## 2-beat rises and 4-beat falls, telegraph drop.

const BUILD: int = IntensityDirector.Phase.BUILD_UP
const PEAK: int = IntensityDirector.Phase.PEAK
const RELAX: int = IntensityDirector.Phase.RELAX
const DT: float = 1.0 / 60.0


func _run(m: StemMixer, seconds: float, phase: int, frenzy: int = 0) -> void:
	for i: int in int(seconds / DT):
		m.step(DT, phase, 0.2, frenzy)


func test_reset_jumps_to_the_phase_targets() -> void:
	var m: StemMixer = StemMixer.new()
	m.reset(96.0, 4, RELAX, 0.0, 0)
	assert_float(m.levels[StemMixer.Stem.BED]).is_equal(0.0)
	assert_float(m.levels[StemMixer.Stem.PERC]).is_equal(StemMixer.SILENT)
	assert_float(m.levels[StemMixer.Stem.MELODY]).is_equal(-6.0)


func test_short_spikes_do_not_change_the_music() -> void:
	var m: StemMixer = StemMixer.new()
	m.reset(96.0, 4, RELAX, 0.0, 0)
	_run(m, 3.5, PEAK)
	_run(m, 1.0, RELAX)
	_run(m, 3.5, PEAK)
	assert_int(m.phase).is_equal(RELAX)


func test_held_state_commits_after_hysteresis_and_moves_one_stem_per_bar() -> void:
	var m: StemMixer = StemMixer.new()
	m.reset(96.0, 4, RELAX, 0.0, 0)
	_run(m, 4.1, PEAK)
	assert_int(m.phase).is_equal(PEAK)
	# Bar = 2.5 s at 96 BPM. Each bar boundary starts one stem: melody, tension, perc, bed.
	_run(m, 1.2, PEAK)  # crosses the 5.0 s bar boundary → melody (−6 → −3) starts
	var moved: int = 0
	for s: int in StemMixer.STEMS:
		if absf(m.levels[s] - StemMixer.targets(RELAX, 0.2, false)[s]) > 0.01:
			moved += 1
	assert_int(moved).is_equal(1)
	_run(m, 12.0, PEAK)
	var peak: PackedFloat32Array = StemMixer.targets(PEAK, 0.2, false)
	for s: int in StemMixer.STEMS:
		assert_float(m.levels[s]).is_equal_approx(peak[s], 0.01)


func test_rises_take_two_beats_and_falls_four() -> void:
	var m: StemMixer = StemMixer.new()
	m.reset(120.0, 4, RELAX, 0.0, 0)  # beat 0.5 s, bar 2 s
	_run(m, 4.0, BUILD)
	_run(m, 2.05, BUILD)  # bar boundary at 6.0 s starts the first stem
	assert_bool(m.is_fading()).is_true()
	_run(m, 1.0, BUILD)  # two beats later a rise has finished
	assert_float(m.levels[StemMixer.Stem.MELODY]).is_equal_approx(0.0, 0.01)


func test_frenzy_adds_the_frenzy_stem_at_peak() -> void:
	var m: StemMixer = StemMixer.new()
	m.reset(96.0, 4, PEAK, 1.0, 5)
	assert_float(m.levels[StemMixer.Stem.FRENZY]).is_equal(0.0)
	m.reset(96.0, 4, PEAK, 1.0, 0)
	assert_float(m.levels[StemMixer.Stem.FRENZY]).is_equal(StemMixer.SILENT)


func test_telegraph_drops_the_melody_within_a_beat() -> void:
	var m: StemMixer = StemMixer.new()
	m.reset(120.0, 4, BUILD, 0.2, 0)
	m.telegraph = true
	_run(m, 0.55, BUILD)
	assert_float(m.levels[StemMixer.Stem.MELODY]).is_equal_approx(StemMixer.SILENT, 0.01)


func test_low_tier_folds_into_three_stems() -> void:
	var m: StemMixer = StemMixer.new()
	m.reset(96.0, 4, PEAK, 1.0, 0)
	var low: PackedFloat32Array = m.low_levels()
	assert_int(low.size()).is_equal(3)
	assert_float(low[2]).is_equal(0.0)  # drive = max(perc, tension)
