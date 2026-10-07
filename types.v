module vjs_runtime

import vjs_core

pub enum RuntimeMode {
	auto
	light_only
	full_only
}

pub enum RuntimeBackend {
	none
	vjs
	quickjs_planning
	quickjs_native
}

pub struct RuntimeConfig {
pub:
	mode                  RuntimeMode                   = .auto
	policy                vjs_core.RuntimePolicy = vjs_core.strict_policy()
	quickjs_heap_limit_mb int = 8
	allow_network         bool
	allow_fs              bool
	allow_storage         bool = true
}

pub fn default_config() RuntimeConfig {
	return RuntimeConfig{}
}

pub struct RuntimeRequest {
pub:
	source string
	url    string = 'about:blank'
	origin string
	module bool
	dom    vjs_core.DomSnapshot
}

pub struct RuntimeResult {
pub:
	ok              bool
	mode            RuntimeMode
	backend         RuntimeBackend
	decision        vjs_core.EvalDecision
	value           string
	error           string
	fallback_reason string
	dom_ops         []vjs_core.DomOp
	diagnostics     []string
}

pub fn (result RuntimeResult) report() string {
	mut lines := [
		'vjs_complete.ok=${result.ok}',
		'vjs_complete.mode=${result.mode}',
		'vjs_complete.backend=${result.backend}',
		'vjs_complete.decision=${result.decision}',
		'vjs_complete.value=${result.value}',
		'vjs_complete.error=${result.error}',
		'vjs_complete.fallback_reason=${result.fallback_reason}',
		'vjs_complete.dom_ops=${result.dom_ops.len}',
	]
	lines << result.diagnostics
	return lines.join('\n')
}
