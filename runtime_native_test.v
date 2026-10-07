module vjs_runtime

fn test_prepared_fast_script_reuses_result() {
	request := RuntimeRequest{
		source: 'const fn = () => 40 + 2; fn();'
	}
	prepared := prepare_fast(request, RuntimeConfig{}) or { panic('fast path not prepared') }
	result := prepared.evaluate(request)
	assert result.ok
	assert result.backend == .fast
	assert result.value == '42'
}

fn test_prepared_fast_script_fails_closed_on_source_change() {
	prepared := prepare_fast(RuntimeRequest{
		source: 'const fn = () => 40 + 2; fn();'
	}, RuntimeConfig{}) or { panic('fast path not prepared') }
	result := prepared.evaluate(RuntimeRequest{
		source: 'const fn = () => 1 + 2; fn();'
	})
	assert !result.ok
	assert result.decision == .deny
}
