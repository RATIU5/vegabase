package vega

import "base:runtime"
import "core:testing"

examples_files := #load_directory("../../docs/specs/examples")
good_files := #load_directory("../../docs/specs/grammar/good")
bad_files := #load_directory("../../docs/specs/grammar/bad")

scan_and_lex :: proc(
	t: ^testing.T,
	file: runtime.Load_Directory_File,
	blocks: ^[dynamic]Block,
	tokens: ^[dynamic]Token,
	errors: ^[dynamic]Error,
) -> bool {
	clear(blocks)
	clear(errors)
	src := string(file.data)
	if !scan(src, blocks, errors) {
		return false
	}
	for block in blocks {
		clear(tokens)
		clear(errors)
		if !lex(src, block.code, tokens, errors) {
			return false
		}
		testing.expectf(
			t,
			len(tokens) > 0 && tokens[len(tokens) - 1].kind == .End,
			"%s: no End token",
			file.name,
		)
	}
	return true
}

@(test)
spec_files :: proc(t: ^testing.T) {
	blocks := make([dynamic]Block)
	defer delete(blocks)
	tokens := make([dynamic]Token)
	defer delete(tokens)
	errors := make([dynamic]Error)
	defer delete(errors)

	accepted := [?][]runtime.Load_Directory_File{examples_files, good_files}
	for group in accepted {
		for file in group {
			if !scan_and_lex(t, file, &blocks, &tokens, &errors) {
				testing.expectf(
					t,
					false,
					"%s: %s at %v",
					file.name,
					errors[0].message,
					errors[0].span,
				)
			}
		}
	}

	for file in bad_files {
		scan_and_lex(t, file, &blocks, &tokens, &errors)
		testing.expectf(t, len(errors) <= 1, "%s: %d errors", file.name, len(errors))
	}
}
