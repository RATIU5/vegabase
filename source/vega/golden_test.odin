package vega

import "core:os"
import "core:strings"
import "core:testing"

VEGA_UPDATE_GOLDEN :: #config(VEGA_UPDATE_GOLDEN, false)

GOLDEN_LEXER_DIR :: "tests/golden/lexer"

first_difference :: proc(want, got: string) -> (line: int, want_line, got_line: string) {
	want_rest := want
	got_rest := got
	for {
		line += 1
		w, w_ok := strings.split_lines_iterator(&want_rest)
		g, g_ok := strings.split_lines_iterator(&got_rest)
		if !w_ok && !g_ok {
			return 0, "", ""
		}
		if w != g || w_ok != g_ok {
			return line, w, g
		}
	}
}

check_golden :: proc(t: ^testing.T, path: string) {
	data, read_err := os.read_entire_file(path, context.allocator)
	if !testing.expectf(t, read_err == nil, "%s: cannot read: %v", path, read_err) {
		return
	}
	defer delete(data)

	got := dump_tokens(string(data))
	defer delete(got)

	tokens_path := strings.concatenate({path[:len(path) - len(".vega")], ".tokens"})
	defer delete(tokens_path)

	when VEGA_UPDATE_GOLDEN {
		write_err := os.write_entire_file(tokens_path, got)
		testing.expectf(t, write_err == nil, "%s: cannot write: %v", tokens_path, write_err)
	} else {
		want, want_err := os.read_entire_file(tokens_path, context.allocator)
		if !testing.expectf(
			t,
			want_err == nil,
			"%s: missing .tokens; run with -define:VEGA_UPDATE_GOLDEN=true",
			path,
		) {
			return
		}
		defer delete(want)

		line, want_line, got_line := first_difference(string(want), got)
		testing.expectf(
			t,
			line == 0,
			"%s: differs at line %d\n  want: %s\n  got:  %s",
			tokens_path,
			line,
			want_line,
			got_line,
		)
	}
}

@(test)
golden_lexer :: proc(t: ^testing.T) {
	walker := os.walker_create(GOLDEN_LEXER_DIR)
	defer os.walker_destroy(&walker)

	count := 0
	for info in os.walker_walk(&walker) {
		if path, err := os.walker_error(&walker); err != nil {
			testing.expectf(t, false, "%s: cannot walk: %v", path, err)
			break
		}
		if info.type != .Regular || !strings.has_suffix(info.fullpath, ".vega") {
			continue
		}
		count += 1
		check_golden(t, info.fullpath)
	}
	if path, err := os.walker_error(&walker); err != nil {
		testing.expectf(t, false, "%s: cannot walk: %v", path, err)
	}
	testing.expectf(t, count > 0, "%s: no .vega files found", GOLDEN_LEXER_DIR)
}
