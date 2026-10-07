module vjs_runtime

fn test_auto_uses_fast_backend_for_simple_dom_script() {
	result := evaluate(RuntimeRequest{
		source: 'document.title = "Demo";'
	}, RuntimeConfig{})
	assert result.ok
	assert result.backend == .fast
	assert result.dom_ops.len == 1
}

fn test_auto_denies_blocked_host_capability() {
	result := evaluate(RuntimeRequest{
		source: 'fetch("https://example.test")'
	}, RuntimeConfig{})
	assert !result.ok
	assert result.backend == .none
	assert result.decision == .deny
}

fn test_light_only_reports_fallback_need() {
	result := evaluate(RuntimeRequest{
		source: 'if (true) { document.title = "x"; }'
	}, RuntimeConfig{
		mode: .light_only
	})
	assert !result.ok
	assert result.backend == .core
	assert result.decision == .fallback
}

fn test_full_only_is_explicit_when_backend_not_linked() {
	result := evaluate(RuntimeRequest{
		source: '1 + 2'
	}, RuntimeConfig{
		mode: .full_only
	})
	assert !result.ok
	assert result.backend == .full_planning
	assert result.error.contains('not linked')
}

fn test_runtime_report_is_product_neutral() {
	report := runtime_report()
	assert report.contains('vjs_runtime.version=')
	assert !report.contains('veloscript')
}
