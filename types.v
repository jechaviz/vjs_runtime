module vjs_runtime

import vjs_core

pub enum RuntimeMode {
	auto
	light_only
	full_only
}

pub enum RuntimeBackend {
	none
	fast
	core
	full_planning
}

pub struct RuntimeConfig {
pub:
	mode          RuntimeMode = .auto
	policy        vjs_core.RuntimePolicy = vjs_core.strict_policy()
	allow_network bool
	allow_fs      bool
	allow_storage bool = true
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
		'vjs_runtime.ok=${result.ok}',
		'vjs_runtime.mode=${result.mode}',
		'vjs_runtime.backend=${result.backend}',
		'vjs_runtime.decision=${result.decision}',
		'vjs_runtime.value=${result.value}',
		'vjs_runtime.error=${result.error}',
		'vjs_runtime.fallback_reason=${result.fallback_reason}',
		'vjs_runtime.dom_ops=${result.dom_ops.len}',
	]
	lines << result.diagnostics
	return lines.join('\n')
}
