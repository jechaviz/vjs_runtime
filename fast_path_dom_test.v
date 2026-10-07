module vjs_runtime

fn test_fast_dom_mutations_cover_common_element_operations() {
	result := evaluate(RuntimeRequest{
		source: 'const el = document.getElementById("status"); el.innerText = "Ready"; el.classList.add("ok"); el.classList.remove("old"); el.setAttribute("aria-live", "polite");'
	}, RuntimeConfig{})
	assert result.ok
	assert result.backend == .fast
	assert result.dom_ops.len == 4
	assert result.dom_ops[0].kind == .set_text
	assert result.dom_ops[0].selector == '#status'
	assert result.dom_ops[1].kind == .add_class
	assert result.dom_ops[2].kind == .remove_class
	assert result.dom_ops[3].kind == .set_attr
	assert result.dom_ops[3].name == 'aria-live'
}

fn test_fast_dom_value_assignment_emits_attribute_update() {
	result := evaluate(RuntimeRequest{
		source: 'const input = document.querySelector("#query"); input.value = "hello";'
	}, RuntimeConfig{})
	assert result.ok
	assert result.dom_ops.len == 1
	assert result.dom_ops[0].kind == .set_attr
	assert result.dom_ops[0].name == 'value'
	assert result.dom_ops[0].value == 'hello'
}
