module vjs_runtime

import vbrowser_js_quickjs
import vbrowser_web_platform
import vjs_core

pub fn evaluate(request RuntimeRequest, config RuntimeConfig) RuntimeResult {
	return match config.mode {
		.auto { evaluate_auto(request, config) }
		.light_only { evaluate_light_only(request, config) }
		.full_only { evaluate_full(request, config, 'full_only mode') }
	}
}

pub fn runtime_report() string {
	probe := vbrowser_js_quickjs.probe_native_runtime_cache()
	return [
		'vjs_complete.version=1.0.0',
		'vjs_complete.strategy=light_first_full_fallback',
		'vjs_complete.light=vjs_core',
		'vjs_complete.full=vbrowser_js_quickjs',
		'vjs_complete.quickjs_native_ready=${probe.ready}',
		probe.report(),
	].join('\n')
}

fn evaluate_auto(request RuntimeRequest, config RuntimeConfig) RuntimeResult {
	plan := vjs_core.plan(core_request(request), config.policy)
	if plan.decision == .run {
		light := vjs_core.eval(core_request(request), config.policy)
		if !light.ok && fallbackable_light_error(light.error) {
			return evaluate_full(request, config, 'light path failed: ${light.error}')
		}
		return result_from_light(light, config.mode, plan)
	}
	if plan.decision == .deny {
		return RuntimeResult{
			mode:        config.mode
			backend:     .none
			decision:    plan.decision
			error:       plan.reason
			diagnostics: plan.diagnostics
		}
	}
	return evaluate_full(request, config, plan.reason)
}

fn evaluate_light_only(request RuntimeRequest, config RuntimeConfig) RuntimeResult {
	plan := vjs_core.plan(core_request(request), config.policy)
	if plan.decision != .run {
		return RuntimeResult{
			mode:            config.mode
			backend:         .vjs
			decision:        plan.decision
			error:           plan.reason
			fallback_reason: if plan.decision == .fallback { plan.reason } else { '' }
			diagnostics:     plan.diagnostics
		}
	}
	light := vjs_core.eval(core_request(request), config.policy)
	return result_from_light(light, config.mode, plan)
}

fn evaluate_full(request RuntimeRequest, config RuntimeConfig, fallback_reason string) RuntimeResult {
	source := full_source(request, config)
	$if quickjs_native ? {
		mut runtime := vbrowser_js_quickjs.new_native_runtime_with_config(quickjs_config(config)) or {
			return full_error(config.mode, .quickjs_native, fallback_reason, err.msg(), [])
		}
		defer {
			runtime.close()
		}
		js := runtime.eval(vbrowser_js_quickjs.EvalRequest{
			source: source
			url:    request.url
			module: request.module
		}) or { return full_error(config.mode, .quickjs_native, fallback_reason, err.msg(), []) }
		return result_from_quickjs(config.mode, .quickjs_native, fallback_reason, js)
	} $else {
		runtime := vbrowser_js_quickjs.new_planning_runtime(quickjs_config(config))
		js := runtime.eval(vbrowser_js_quickjs.EvalRequest{
			source: source
			url:    request.url
			module: request.module
		}) or { return full_error(config.mode, .quickjs_planning, fallback_reason, err.msg(), []) }
		return result_from_quickjs(config.mode, .quickjs_planning, fallback_reason, js)
	}
}

fn result_from_light(light vjs_core.RunResult, mode RuntimeMode, plan vjs_core.EvalPlan) RuntimeResult {
	mut diagnostics := plan.diagnostics.clone()
	diagnostics << light.diagnostics
	return RuntimeResult{
		ok:              light.ok
		mode:            mode
		backend:         .vjs
		decision:        plan.decision
		value:           light.value.display()
		error:           light.error
		fallback_reason: ''
		dom_ops:         light.ops
		diagnostics:     diagnostics
	}
}

fn result_from_quickjs(mode RuntimeMode, backend RuntimeBackend, fallback_reason string, js vbrowser_js_quickjs.EvalResult) RuntimeResult {
	value, ops := if js.ok {
		decode_bridge_payload(js.value) or { js.value, []vjs_core.DomOp{} }
	} else {
		js.value, []vjs_core.DomOp{}
	}
	return RuntimeResult{
		ok:              js.ok
		mode:            mode
		backend:         backend
		decision:        .fallback
		value:           value
		error:           if js.ok { '' } else { js.reason }
		fallback_reason: fallback_reason
		dom_ops:         ops
		diagnostics:     js.diagnostics
	}
}

fn full_error(mode RuntimeMode, backend RuntimeBackend, fallback_reason string, message string, diagnostics []string) RuntimeResult {
	return RuntimeResult{
		mode:            mode
		backend:         backend
		decision:        .fallback
		error:           message
		fallback_reason: fallback_reason
		diagnostics:     diagnostics
	}
}

fn core_request(request RuntimeRequest) vjs_core.EvalRequest {
	return vjs_core.EvalRequest{
		source: request.source
		url:    request.url
		origin: request.origin
		module: request.module
		dom:    request.dom
	}
}

fn quickjs_config(config RuntimeConfig) vbrowser_js_quickjs.RuntimeConfig {
	return vbrowser_js_quickjs.RuntimeConfig{
		allow_network: config.allow_network
		allow_fs:      config.allow_fs
		heap_limit_mb: config.quickjs_heap_limit_mb
	}
}

fn full_source(request RuntimeRequest, config RuntimeConfig) string {
	prelude := vbrowser_web_platform.js_prelude(vbrowser_web_platform.WebApiPolicy{
		allow_network:    config.allow_network
		allow_storage:    config.allow_storage
		allow_filesystem: config.allow_fs
	})
	return '${prelude.source}\n${wrap_full_source_for_dom_ops(request.source,
		config.policy.allow_timers, config.policy.allow_events)}'
}

fn fallbackable_light_error(message string) bool {
	lower := message.to_lower()
	return lower.contains('expected') || lower.contains('unsupported')
		|| lower.contains('undefined name')
}
