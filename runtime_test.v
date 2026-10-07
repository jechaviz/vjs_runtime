module vjs_runtime

import vjs_core

fn test_auto_mode_uses_light_backend_for_supported_dom_script() {
	result := evaluate(RuntimeRequest{
		source: 'document.title = "Demo";'
	}, RuntimeConfig{})
	assert result.ok
	assert result.backend == .vjs
	assert result.dom_ops.len == 1
	assert result.report().contains('vjs_complete.backend=vjs')
}

fn test_auto_mode_denies_blocked_host_capability_without_fallback() {
	result := evaluate(RuntimeRequest{
		source: 'fetch("https://example.test")'
	}, RuntimeConfig{})
	assert !result.ok
	assert result.backend == .none
	assert result.decision == .deny
	assert result.error.contains('capability')
}

fn test_light_only_reports_fallback_need_without_running_full_backend() {
	result := evaluate(RuntimeRequest{
		source: 'const fn = () => 1;'
	}, RuntimeConfig{
		mode: .light_only
	})
	assert !result.ok
	assert result.backend == .vjs
	assert result.decision == .fallback
	assert result.fallback_reason.contains('unsupported')
}

fn test_full_only_uses_planning_backend_without_native_flag() {
	$if !quickjs_native ? {
		result := evaluate(RuntimeRequest{
			source: '1 + 2'
		}, RuntimeConfig{
			mode: .full_only
		})
		assert !result.ok
		assert result.backend == .quickjs_planning
		assert result.error.contains('QuickJS binding not linked yet')
	}
}

fn test_auto_mode_falls_back_when_light_parser_fails_after_run_plan() {
	result := evaluate(RuntimeRequest{
		source: 'if (true) { document.title = "x"; }'
	}, default_config())
	$if quickjs_native ? {
		assert result.backend == .quickjs_native
	} $else {
		assert result.backend == .quickjs_planning
	}
	assert result.fallback_reason.contains('light path failed')
}

fn test_runtime_report_mentions_quickjs_probe() {
	report := runtime_report()
	assert report.contains('vjs_complete.version=1.0.0')
	assert report.contains('quickjs.native.ready=')
}

fn sample_dom() vjs_core.DomSnapshot {
	return vjs_core.DomSnapshot{
		nodes: [
			vjs_core.DomNode{
				id:  'msg'
				tag: 'p'
			},
		]
	}
}
