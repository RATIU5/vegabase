package vega

import "base:runtime"
import "core:mem/virtual"
import "core:strings"
import "core:testing"

examples_files := #load_directory("../../docs/specs/examples")
good_files := #load_directory("../../docs/specs/grammar/good")
bad_files := #load_directory("../../docs/specs/grammar/bad")

@(test)
spec_files :: proc(t: ^testing.T) {
	arena: virtual.Arena
	arena_err := virtual.arena_init_growing(&arena)
	assert(arena_err == nil)
	defer virtual.arena_destroy(&arena)
	arena_alloc := virtual.arena_allocator(&arena)

	accepted := [?][]runtime.Load_Directory_File{examples_files, good_files}
	for group in accepted {
		for file in group {
			parsed, ok := parse(file.name, string(file.data), arena_alloc)
			if !ok || len(parsed.errors) != 0 {
				testing.expectf(
					t,
					false,
					"%s: %s at %v",
					file.name,
					ERROR_MESSAGES[parsed.errors[0].code] if len(parsed.errors) > 0 else "no error",
					parsed.errors[0].span if len(parsed.errors) > 0 else Span{},
				)
			}
			virtual.arena_free_all(&arena)
		}
	}

	for file in bad_files {
		parsed, ok := parse(file.name, string(file.data), arena_alloc)
		testing.expectf(
			t,
			!ok && len(parsed.errors) == 1,
			"%s: ok=%v, %d errors",
			file.name,
			ok,
			len(parsed.errors),
		)
		virtual.arena_free_all(&arena)
	}
}

@(test)
spec_file_prefixes :: proc(t: ^testing.T) {
	arena: virtual.Arena
	arena_err := virtual.arena_init_growing(&arena)
	assert(arena_err == nil)
	defer virtual.arena_destroy(&arena)
	arena_alloc := virtual.arena_allocator(&arena)

	groups := [?][]runtime.Load_Directory_File{examples_files, good_files, bad_files}
	for group in groups {
		for file in group {
			for n in 0 ..= len(file.data) {
				parsed, ok := parse(file.name, string(file.data[:n]), arena_alloc)
				error_count := len(parsed.errors)
				virtual.arena_free_all(&arena)
				if error_count != (0 if ok else 1) {
					testing.expectf(
						t,
						false,
						"%s: prefix %d: ok=%v, %d errors",
						file.name,
						n,
						ok,
						error_count,
					)
					break
				}
			}
		}
	}
}

expect_nesting_rejected :: proc(t: ^testing.T, src: string) {
	arena: virtual.Arena
	arena_err := virtual.arena_init_growing(&arena)
	assert(arena_err == nil)
	defer virtual.arena_destroy(&arena)

	file, ok := parse("deep.vega", src, virtual.arena_allocator(&arena))
	testing.expect(t, !ok)
	testing.expect(t, len(file.errors) == 1)
	if len(file.errors) == 1 {
		testing.expect_value(t, file.errors[0].code, Error_Code.Nested_Too_Deeply)
	}
}

@(test)
nesting_too_deep :: proc(t: ^testing.T) {
	LEVELS :: 100000
	b: strings.Builder
	strings.builder_init(&b)
	defer strings.builder_destroy(&b)

	strings.write_string(&b, "{{\n  A :: T ")
	for _ in 1 ..< LEVELS {
		strings.write_string(&b, "{ of = T ")
	}
	strings.write_string(&b, "{ }")
	for _ in 1 ..< LEVELS {
		strings.write_string(&b, " }")
	}
	strings.write_string(&b, "\n}}\n")
	expect_nesting_rejected(t, strings.to_string(b))

	strings.builder_reset(&b)
	strings.write_string(&b, "{{\n  A :: component {\n    fields {\n      a: Int = ")
	for _ in 0 ..< LEVELS {
		strings.write_byte(&b, '(')
	}
	strings.write_byte(&b, '1')
	for _ in 0 ..< LEVELS {
		strings.write_byte(&b, ')')
	}
	strings.write_string(&b, "\n    }\n  }\n}}\n")
	expect_nesting_rejected(t, strings.to_string(b))
}

@(test)
first_block_leading_whitespace :: proc(t: ^testing.T) {
	arena: virtual.Arena
	arena_err := virtual.arena_init_growing(&arena)
	assert(arena_err == nil)
	defer virtual.arena_destroy(&arena)
	arena_alloc := virtual.arena_allocator(&arena)

	parsed, ok := parse("a.vega", " \t\r\n{{\n  use std\n}}\n", arena_alloc)
	testing.expect(t, ok)
	testing.expect_value(t, len(parsed.errors), 0)
	virtual.arena_free_all(&arena)

	parsed, ok = parse("b.vega", "\v{{use std}}\n", arena_alloc)
	testing.expect(t, !ok)
	testing.expect_value(t, len(parsed.errors), 1)
	if len(parsed.errors) == 1 {
		testing.expect_value(t, parsed.errors[0].code, Error_Code.Statement_Outside_First_Block)
	}
}
