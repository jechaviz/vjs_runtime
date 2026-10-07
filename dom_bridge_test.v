module vjs_runtime

fn test_decode_bridge_payload_returns_value_and_dom_ops() {
	value, ops := decode_bridge_payload('{"value":"ok","ops":[{"kind":"set_title","selector":"","name":"title","value":"Demo","delay_ms":0}]}') or {
		panic(err.msg())
	}
	assert value == 'ok'
	assert ops.len == 1
	assert ops[0].kind.str() == 'set_title'
	assert ops[0].value == 'Demo'
}

fn test_wrap_full_source_contains_dom_capture_hooks() {
	source := wrap_full_source_for_dom_ops('document.title = "Demo";', true, true)
	assert source.contains('__vjs_ops')
	assert source.contains('JSON.stringify')
	assert source.contains('document.title')
}

fn test_wrap_full_source_can_enforce_timer_and_event_policy() {
	source := wrap_full_source_for_dom_ops('setTimeout(function () {}, 1);', false, false)
	assert source.contains('timers denied by vjs policy')
	assert source.contains('events denied by vjs policy')
}
