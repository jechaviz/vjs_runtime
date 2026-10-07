module vjs_runtime

import vjs_core

struct PreparedFast {
	source string
	result RuntimeResult
}

pub fn prepare_fast(request RuntimeRequest, config RuntimeConfig) ?PreparedFast {
	plan := vjs_core.plan(core_request(request), config.policy)
	if plan.decision == .deny {
		return none
	}
	result := try_fast(request, config, plan) or { return none }
	return PreparedFast{
		source: request.source
		result: result
	}
}

pub fn (prepared PreparedFast) evaluate(request RuntimeRequest) RuntimeResult {
	if prepared.source != request.source {
		return RuntimeResult{
			mode: .auto
			backend: .none
			decision: .deny
			error: 'prepared script source mismatch'
		}
	}
	return prepared.result
}

fn try_fast(request RuntimeRequest, config RuntimeConfig, plan vjs_core.EvalPlan) ?RuntimeResult {
	source := request.source.trim_space()
	if source == '' {
		return none
	}
	if result := fast_dom_result(source, config, plan) {
		return result
	}
	if value := eval_arrow_const_call(source) {
		return RuntimeResult{
			ok: true
			mode: config.mode
			backend: .fast
			decision: .run
			value: value
			diagnostics: ['vjs_runtime.fast=arrow_const']
		}
	}
	return none
}

fn fast_dom_result(source string, config RuntimeConfig, plan vjs_core.EvalPlan) ?RuntimeResult {
	if source.contains('=>') || source.contains('function') || source.contains('for')
		|| source.contains('while') {
		return none
	}
	mut vars := map[string]string{}
	mut ops := []vjs_core.DomOp{}
	mut value := ''
	for raw in source.split(';') {
		stmt := raw.trim_space()
		if stmt == '' {
			continue
		}
		if stmt.starts_with('let ') || stmt.starts_with('const ') || stmt.starts_with('var ') {
			if parse_query_var(stmt, mut vars) {
				continue
			}
			return none
		}
		if stmt.starts_with('document.title') && stmt.contains('=') {
			title := rhs_string(stmt) or { return none }
			value = title
			ops << vjs_core.DomOp{
				kind: .set_title
				name: 'title'
				value: title
			}
			continue
		}
		if stmt.contains('.textContent') && stmt.contains('=') {
			name := stmt.all_before('.textContent').trim_space()
			selector := vars[name] or { return none }
			text := rhs_string(stmt) or { return none }
			value = text
			ops << vjs_core.DomOp{
				kind: .set_text
				selector: selector
				name: 'textContent'
				value: text
			}
			continue
		}
		if stmt.contains('.classList.add(') {
			name := stmt.all_before('.classList.add(').trim_space()
			selector := vars[name] or { return none }
			class_name := call_string_arg(stmt) or { return none }
			ops << vjs_core.DomOp{
				kind: .add_class
				selector: selector
				name: 'class'
				value: class_name
			}
			continue
		}
		return none
	}
	if ops.len == 0 {
		return none
	}
	mut diagnostics := plan.diagnostics.clone()
	diagnostics << 'vjs_runtime.fast=dom_ops'
	return RuntimeResult{
		ok: true
		mode: config.mode
		backend: .fast
		decision: .run
		value: value
		dom_ops: ops
		diagnostics: diagnostics
	}
}

fn parse_query_var(stmt string, mut vars map[string]string) bool {
	clean := stmt.replace('let ', '').replace('const ', '').replace('var ', '')
	if !clean.contains('=') || !clean.contains('document.querySelector(') {
		return false
	}
	name := clean.all_before('=').trim_space()
	selector := call_string_arg(clean) or { return false }
	vars[name] = selector
	return true
}

pub fn eval_arrow_const_call(source string) ?string {
	clean := source.trim_space()
	if !clean.starts_with('const ') || !clean.contains('=>') || !clean.ends_with(');') {
		return none
	}
	name := clean.all_after('const ').all_before('=').trim_space()
	body := clean.all_after('=>').all_before(';').trim_space()
	call := clean.all_after(';').trim_space()
	if call != '${name}();' {
		return none
	}
	return eval_numeric_or_string_expr(body)
}

pub fn eval_numeric_or_string_expr(expr string) ?string {
	if value := literal_or_concat(expr) {
		return value
	}
	mut total := 0
	for part in expr.split('+') {
		clean := part.trim_space()
		if !is_digits(clean) {
			return none
		}
		total += clean.int()
	}
	return total.str()
}

fn rhs_string(stmt string) ?string {
	return literal_or_concat(stmt.all_after('=').trim_space())
}

fn call_string_arg(stmt string) ?string {
	start := stmt.index('(') or { return none }
	end := stmt.last_index(')') or { return none }
	if end <= start {
		return none
	}
	return literal_or_concat(stmt[start + 1..end].trim_space())
}

pub fn literal_or_concat(expr string) ?string {
	mut out := ''
	for part in expr.split('+') {
		clean := part.trim_space()
		if clean.len < 2 {
			return none
		}
		if !(clean.starts_with('"') && clean.ends_with('"'))
			&& !(clean.starts_with("'") && clean.ends_with("'")) {
			return none
		}
		out += clean[1..clean.len - 1]
	}
	return out
}

fn is_digits(value string) bool {
	if value == '' {
		return false
	}
	for ch in value {
		if ch < `0` || ch > `9` {
			return false
		}
	}
	return true
}
