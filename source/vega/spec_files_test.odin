package vega

import "base:runtime"
import "core:testing"

examples_files := #load_directory("../../docs/specs/examples")
good_files := #load_directory("../../docs/specs/grammar/good")
bad_files := #load_directory("../../docs/specs/grammar/bad")

scan_and_lex :: proc(
	t: ^testing.T,
	name: string,
	src: string,
	blocks: ^[dynamic]Block,
	tokens: ^[dynamic]Token,
	errors: ^[dynamic]Error,
) -> bool {
	clear(blocks)
	clear(errors)
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
			name,
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
			if !scan_and_lex(t, file.name, string(file.data), &blocks, &tokens, &errors) {
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
		scan_and_lex(t, file.name, string(file.data), &blocks, &tokens, &errors)
		testing.expectf(t, len(errors) <= 1, "%s: %d errors", file.name, len(errors))
	}
}

@(test)
spec_file_prefixes :: proc(t: ^testing.T) {
	blocks := make([dynamic]Block)
	defer delete(blocks)
	tokens := make([dynamic]Token)
	defer delete(tokens)
	errors := make([dynamic]Error)
	defer delete(errors)

	groups := [?][]runtime.Load_Directory_File{examples_files, good_files, bad_files}
	for group in groups {
		for file in group {
			for n in 0 ..= len(file.data) {
				scan_and_lex(t, file.name, string(file.data[:n]), &blocks, &tokens, &errors)
				if len(errors) > 1 {
					testing.expectf(
						t,
						false,
						"%s: prefix %d: %d errors",
						file.name,
						n,
						len(errors),
					)
					break
				}
			}
		}
	}
}
