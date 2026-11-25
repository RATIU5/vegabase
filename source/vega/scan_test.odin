package vega

import "core:testing"

Scan_Case :: struct {
	name:  string,
	src:   string,
	codes: []string,
	ok:    bool,
	code:  Error_Code,
	at:    Span,
}

SCAN_CASES := [?]Scan_Case {
	{name = "empty string", src = "", ok = true},
	{name = "plain html", src = `<p>hi</p>`, ok = true},
	{name = "one block", src = `a{{x}}b`, codes = {`x`}, ok = true},
	{name = "two blocks", src = `{{a}}{{b}}`, codes = {`a`, `b`}, ok = true},
	{name = "close in string", src = `{{"}}"}}`, codes = {`"}}"`}, ok = true},
	{name = "nested braces", src = `{{x {a}}}`, codes = {`x {a}`}, ok = true},
	{name = "escaped quote", src = `{{"a\"}}"}}`, codes = {`"a\"}}"`}, ok = true},
	{name = "comment with brace", src = `{{# a } b}}`, codes = {`# a } b`}, ok = true},
	{name = "comment to newline", src = "{{# n\nx}}", codes = {"# n\nx"}, ok = true},
	{name = "stray braces outside", src = `a { b }}`, ok = true},
	{name = "brace before block", src = `a{b{{x}}`, codes = {`x`}, ok = true},
	{name = "triple open", src = `{{{a}}}`, codes = {`{a}`}, ok = true},
	{
		name = "many comments",
		src = "{{# a\n# b\n# c\nx}}",
		codes = {"# a\n# b\n# c\nx"},
		ok = true,
	},
	{name = "comment closes block", src = `{{x # c}}`, codes = {`x # c`}, ok = true},
	{name = "unclosed block", src = `{{x`, code = .Block_Never_Closed, at = {0, 2}},
	{name = "unclosed string", src = `{{"abc`, code = .String_Never_Closed, at = {2, 3}},
	{name = "string at newline", src = "{{\"ab\ncd\"}}", code = .String_Never_Closed, at = {2, 3}},
	{name = "stray close", src = `{{x } y}}`, code = .Close_Brace_Without_Open, at = {4, 5}},
	{name = "unclosed comment", src = `{{# note`, code = .Block_Never_Closed, at = {0, 2}},
	{name = "close after open", src = `{{ {a }}`, code = .Close_Brace_Without_Open, at = {7, 8}},
	{
		name = "block kept before error",
		src = `{{a}} {{x } y}} {{b}}`,
		codes = {`a`},
		code = .Close_Brace_Without_Open,
		at = {10, 11},
	},
}

@(test)
scan_table :: proc(t: ^testing.T) {
	for c in SCAN_CASES {
		blocks := make([dynamic]Block)
		defer delete(blocks)
		errors := make([dynamic]Error)
		defer delete(errors)

		ok := scan(c.src, &blocks, &errors)

		testing.expect_value(t, ok, c.ok)
		if !testing.expect_value(t, len(blocks), len(c.codes)) {
			continue
		}
		for code, i in c.codes {
			b := blocks[i]
			testing.expect_value(t, c.src[b.code.start:b.code.end], code)
		}
		if c.ok {
			testing.expect_value(t, len(errors), 0)
			continue
		}
		if !testing.expect_value(t, len(errors), 1) {
			continue
		}
		testing.expect_value(t, errors[0].code, c.code)
		testing.expect_value(t, errors[0].span, c.at)
	}
}

@(test)
scan_block_spans :: proc(t: ^testing.T) {
	blocks := make([dynamic]Block)
	defer delete(blocks)
	errors := make([dynamic]Error)
	defer delete(errors)

	ok := scan(`a{{x}}b`, &blocks, &errors)

	testing.expect_value(t, ok, true)
	if !testing.expect_value(t, len(blocks), 1) {
		return
	}
	testing.expect_value(t, blocks[0].span, Span{1, 6})
	testing.expect_value(t, blocks[0].code, Span{3, 4})
}
