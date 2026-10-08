module vjs_runtime

import json2
import vjs_core

struct BridgePayload {
	value string
	ops   []BridgeOp
}

struct BridgeOp {
	kind     string
	selector string
	name     string
	value    string
	delay_ms int
}

pub fn wrap_full_source_for_dom_ops(source string, allow_timers bool, allow_events bool) string {
	encoded_source := json2.encode(source)
	timer_line := if allow_timers {
		'  globalThis.setTimeout = function (fn, delay) { op("timer", "", "setTimeout", "callback", Number(delay) || 0); return 0; };'
	} else {
		'  globalThis.setTimeout = function () { throw new Error("timers denied by vjs policy"); };'
	}
	event_line := if allow_events {
		'    addEventListener: function (name) { op("add_event", selector, name, "callback", 0); }'
	} else {
		'    addEventListener: function () { throw new Error("events denied by vjs policy"); }'
	}
	return [
		'(function () {',
		'  globalThis.__vjs_ops = [];',
		'  function op(kind, selector, name, value, delay) { __vjs_ops.push({ kind: kind, selector: selector || "", name: name || "", value: String(value === undefined ? "" : value), delay_ms: delay || 0 }); }',
		'  function node(selector) { return {',
		'    get textContent() { return ""; },',
		'    set textContent(value) { op("set_text", selector, "textContent", value, 0); },',
		'    classList: {',
		'      add: function (name) { op("add_class", selector, "class", name, 0); },',
		'      remove: function (name) { op("remove_class", selector, "class", name, 0); },',
		'      toggle: function (name) { op("add_class", selector, "class", name, 0); }',
		'    },',
		event_line,
		'  }; }',
		'  globalThis.document = {',
		'    _title: "",',
		'    get title() { return this._title; },',
		'    set title(value) { this._title = String(value); op("set_title", "", "title", value, 0); },',
		'    querySelector: function (selector) { return node(String(selector)); }',
		'  };',
		timer_line,
		'  var __vjs_value = (0, eval)(${encoded_source});',
		'  return JSON.stringify({ value: String(__vjs_value === undefined ? "" : __vjs_value), ops: __vjs_ops });',
		'})()',
	].join('\n')
}

pub fn decode_bridge_payload(text string) !(string, []vjs_core.DomOp) {
	payload := json2.decode[BridgePayload](text)!
	mut ops := []vjs_core.DomOp{cap: payload.ops.len}
	for item in payload.ops {
		ops << vjs_core.DomOp{
			kind:     dom_kind(item.kind)!
			selector: item.selector
			name:     item.name
			value:    item.value
			delay_ms: item.delay_ms
		}
	}
	return payload.value, ops
}

fn dom_kind(value string) !vjs_core.DomOpKind {
	return match value {
		'set_title' { vjs_core.DomOpKind.set_title }
		'set_text' { vjs_core.DomOpKind.set_text }
		'add_class' { vjs_core.DomOpKind.add_class }
		'remove_class' { vjs_core.DomOpKind.remove_class }
		'set_attr' { vjs_core.DomOpKind.set_attr }
		'add_event' { vjs_core.DomOpKind.add_event }
		'timer' { vjs_core.DomOpKind.timer }
		else { error('unsupported bridge op kind ${value}') }
	}
}
