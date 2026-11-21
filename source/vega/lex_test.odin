package vega

import "base:runtime"
import "core:strings"
import "core:testing"

Lex_Fail :: struct {
	file:    string,
	message: string,
}

LEX_FAILS := [?]Lex_Fail {
	{file = "arithmetic.vega", message = "unexpected character"},
	{file = "decimal-number.vega", message = "decimal numbers are not supported"},
	{file = "string-unknown-escape.vega", message = "unknown escape in string"},
	{file = "locale-name-with-hyphen.vega", message = "unexpected character"},
}

@(test)
lex_spec_files :: proc(t: ^testing.T) {
	groups := [?][]runtime.Load_Directory_File{examples_files, good_files, bad_files}
	for group in groups {
		for file in group {
			src := string(file.data)
			blocks := make([dynamic]Block)
			defer delete(blocks)
			tokens := make([dynamic]Token)
			defer delete(tokens)
			errors := make([dynamic]Error)
			defer delete(errors)

			scanned := scan(src, &blocks, &errors)
			if strings.has_suffix(file.name, "unclosed-block.vega") {
				testing.expectf(t, !scanned, "%s", file.name)
				continue
			}
			if !testing.expectf(t, scanned, "%s", file.name) {
				continue
			}

			failed := false
			for block in blocks {
				clear(&tokens)
				clear(&errors)
				if !lex(src, block.code, &tokens, &errors) {
					failed = true
					break
				}
				testing.expectf(
					t,
					len(tokens) > 0 && tokens[len(tokens) - 1].kind == .End,
					"%s: no End token",
					file.name,
				)
			}

			message := ""
			for fail in LEX_FAILS {
				if strings.has_suffix(file.name, fail.file) {
					message = fail.message
				}
			}
			if message == "" {
				if failed {
					testing.expectf(
						t,
						false,
						"%s: %s at %v",
						file.name,
						errors[0].message,
						errors[0].span,
					)
				}
				continue
			}
			testing.expectf(t, failed, "%s: expected a lex error", file.name)
			if failed && testing.expect_value(t, len(errors), 1) {
				testing.expect_value(t, errors[0].message, message)
			}
		}
	}
}
