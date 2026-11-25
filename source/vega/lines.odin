package vega

import "core:slice"
import "core:strings"

line_starts :: proc(src: string, allocator := context.allocator) -> []u32 {
	starts := make([]u32, strings.count(src, "\n") + 1, allocator)
	n := 1
	for i in 0 ..< len(src) {
		if src[i] == '\n' {
			starts[n] = u32(i + 1)
			n += 1
		}
	}
	return starts
}

line_col :: proc(starts: []u32, offset: u32) -> (line, col: int) {
	line, _ = slice.binary_search_by(starts, offset, start_cmp)
	return line, int(offset - starts[line - 1]) + 1
}

@(private = "file")
start_cmp :: proc(start, offset: u32) -> slice.Ordering {
	return .Less if start <= offset else .Greater
}
