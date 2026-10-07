module vjs_runtime

import vjs_core

$if !quickjs_native ? {
	fn test_native_quickjs_tests_are_gated_without_flag() {
		assert true
	}
}

$if quickjs_native ? {
	fn test_auto_mode_falls_back_to_native_quickjs_for_arrow_function() {
		result := evaluate(RuntimeRequest{
			source: 'const fn = () => 40 + 2; fn();'
		}, RuntimeConfig{})
		assert result.ok
		assert result.backend == .quickjs_native
		assert result.value == '42'
		assert result.fallback_reason.contains('unsupported')
	}

	fn test_full_only_native_quickjs_executes_browser_prelude() {
		result := evaluate(RuntimeRequest{
			source: 'document.title = "Full"; document.title + " Engine";'
		}, RuntimeConfig{
			mode: .full_only
		})
		assert result.ok
		assert result.backend == .quickjs_native
		assert result.value == 'Full Engine'
		assert result.dom_ops.len == 1
		assert result.dom_ops[0].kind.str() == 'set_title'
	}

	fn test_full_fallback_native_enforces_timer_policy() {
		result := evaluate(RuntimeRequest{
			source: 'const f = () => setTimeout(function () {}, 1); f();'
		}, RuntimeConfig{
			policy: vjs_core.RuntimePolicy{
				max_source_bytes: 8192
				max_steps:        4096
				max_dom_nodes:    512
				allow_timers:     false
				allow_events:     true
			}
		})
		assert !result.ok
		assert result.error.contains('QuickJS evaluation failed')
	}
}
