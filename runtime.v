module vjs_runtime

import vjs_core

pub fn evaluate(request RuntimeRequest, config RuntimeConfig) RuntimeResult {
	plan := vjs_core.plan(core_request(request), config.policy)
	if plan.decision == .deny {
		return RuntimeResult{
			mode: config.mode
			backend: .none
			decision: .deny
			error: plan.reason
			diagnostics: plan.diagnostics
		}
	}
	if config.mode != .full_only {
		if fast := try_fast(request, config, plan) {
			return fast
		}
	}
	return match config.mode {
		.auto { evaluate_auto(request, config, plan) }
		.light_only { evaluate_light_only(request, config, plan) }
		.full_only { full_planning_result(config.mode, 'full_only mode') }
	}
}

pub fn runtime_report() string {
	return [
		'vjs_runtime.version=0.1.0',
		'vjs_runtime.strategy=fast_then_core_then_explicit_full_planning',
		'vjs_runtime.fast=internal',
		'vjs_runtime.core=vjs_core',
		'vjs_runtime.full_backend=not_linked',
	].join('\n')
}

fn evaluate_auto(request RuntimeRequest, config RuntimeConfig, plan vjs_core.EvalPlan) RuntimeResult {
	if plan.decision == .run {
		light := vjs_core.eval(core_request(request), config.policy)
		if !light.ok && fallbackable_core_error(light.error) {
			return full_planning_result(config.mode, 'core path failed: ' + light.error)
		}
		return result_from_core(light, config.mode, plan)
	}
	return full_planning_result(config.mode, plan.reason)
}

fn evaluate_light_only(request RuntimeRequest, config RuntimeConfig, plan vjs_core.EvalPlan) RuntimeResult {
	if plan.decision != .run {
		return RuntimeResult{
			mode: config.mode
			backend: .core
			decision: plan.decision
			error: plan.reason
			fallback_reason: if plan.decision == .fallback { plan.reason } else { '' }
			diagnostics: plan.diagnostics
		}
	}
	light := vjs_core.eval(core_request(request), config.policy)
	return result_from_core(light, config.mode, plan)
}

fn result_from_core(light vjs_core.RunResult, mode RuntimeMode, plan vjs_core.EvalPlan) RuntimeResult {
	mut diagnostics := plan.diagnostics.clone()
	diagnostics << light.diagnostics
	return RuntimeResult{
		ok: light.ok
		mode: mode
		backend: .core
		decision: plan.decision
		value: light.value.display()
		error: light.error
		dom_ops: light.ops
		diagnostics: diagnostics
	}
}

fn full_planning_result(mode RuntimeMode, reason string) RuntimeResult {
	return RuntimeResult{
		mode: mode
		backend: .full_planning
		decision: .fallback
		error: 'full JavaScript backend is not linked'
		fallback_reason: reason
		diagnostics: ['vjs_runtime.full_backend=required']
	}
}

fn core_request(request RuntimeRequest) vjs_core.EvalRequest {
	return vjs_core.EvalRequest{
		source: request.source
		url: request.url
		origin: request.origin
		module: request.module
		dom: request.dom
	}
}

fn fallbackable_core_error(message string) bool {
	lower := message.to_lower()
	return lower.contains('expected') || lower.contains('unsupported')
		|| lower.contains('undefined name')
}
