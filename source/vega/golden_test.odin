package vega

import "base:runtime"
import "core:mem/virtual"
import "core:os"
import "core:strings"
import "core:testing"

VEGA_UPDATE_GOLDEN :: #config(VEGA_UPDATE_GOLDEN, false)

GOLDEN_LEXER_DIR :: #directory + "/../../tests/golden/lexer"
GOLDEN_PARSER_DIR :: #directory + "/../../tests/golden/parser"

Golden_Dump :: proc(path, src: string, allocator: runtime.Allocator) -> string

first_difference :: proc(want, got: string) -> (line: int, want_line, got_line: string) {
	want := want
	got := got
	for {
		line += 1
		w, w_ok := strings.split_lines_iterator(&want)
		g, g_ok := strings.split_lines_iterator(&got)
		if !w_ok && !g_ok {
			return 0, "", ""
		}
		if w != g || w_ok != g_ok {
			return line, w, g
		}
	}
}

check_golden :: proc(
	t: ^testing.T,
	path, ext: string,
	dump: Golden_Dump,
	allocator: runtime.Allocator,
) {
	data, read_err := os.read_entire_file(path, context.allocator)
	if !testing.expectf(t, read_err == nil, "%s: cannot read: %v", path, read_err) {
		return
	}
	defer delete(data)

	got := dump(path, string(data), allocator)
	defer delete(got)

	golden_path := strings.concatenate({path[:len(path) - len(".vega")], ext})
	defer delete(golden_path)

	when VEGA_UPDATE_GOLDEN {
		write_err := os.write_entire_file(golden_path, got)
		testing.expectf(t, write_err == nil, "%s: cannot write: %v", golden_path, write_err)
	} else {
		want, want_err := os.read_entire_file(golden_path, context.allocator)
		if !testing.expectf(
			t,
			want_err == nil,
			"%s: missing %s; run with -define:VEGA_UPDATE_GOLDEN=true",
			path,
			ext,
		) {
			return
		}
		defer delete(want)

		if string(want) != got {
			line, want_line, got_line := first_difference(string(want), got)
			if line == 0 {
				testing.expectf(t, false, "%s: files differ only in trailing lines", golden_path)
			} else {
				testing.expectf(
					t,
					false,
					"%s: differs at line %d\n  want: %s\n  got:  %s",
					golden_path,
					line,
					want_line,
					got_line,
				)
			}
		}
	}
}

check_golden_dir :: proc(t: ^testing.T, dir, ext: string, dump: Golden_Dump) {
	arena: virtual.Arena
	arena_err := virtual.arena_init_growing(&arena)
	assert(arena_err == nil)
	defer virtual.arena_destroy(&arena)
	arena_alloc := virtual.arena_allocator(&arena)

	walker := os.walker_create(dir)
	defer os.walker_destroy(&walker)

	count := 0
	for info in os.walker_walk(&walker) {
		if info.type != .Regular || !strings.has_suffix(info.fullpath, ".vega") {
			continue
		}
		count += 1
		check_golden(t, info.fullpath, ext, dump, arena_alloc)
		virtual.arena_free_all(&arena)
	}
	if path, err := os.walker_error(&walker); err != nil {
		testing.expectf(t, false, "%s: cannot walk: %v", path, err)
	}
	testing.expectf(t, count > 0, "%s: no .vega files found", dir)
}

dump_lexer_golden :: proc(_, src: string, _: runtime.Allocator) -> string {
	return dump_tokens(src)
}

dump_parser_golden :: proc(path, src: string, allocator: runtime.Allocator) -> string {
	file, _ := parse(path, src, allocator)
	return dump_tree(&file)
}

@(test)
golden_lexer :: proc(t: ^testing.T) {
	check_golden_dir(t, GOLDEN_LEXER_DIR, ".tokens", dump_lexer_golden)
}

@(test)
golden_parser :: proc(t: ^testing.T) {
	check_golden_dir(t, GOLDEN_PARSER_DIR, ".tree", dump_parser_golden)
}
