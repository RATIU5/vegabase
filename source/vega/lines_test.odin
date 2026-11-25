package vega

import "core:testing"

Line_Col_Case :: struct {
	name:   string,
	src:    string,
	count:  int,
	offset: u32,
	line:   int,
	col:    int,
}

LINE_COL_CASES := [?]Line_Col_Case {
	{name = "empty", src = "", count = 1, offset = 0, line = 1, col = 1},
	{name = "end of file", src = "ab", count = 1, offset = 2, line = 1, col = 3},
	{name = "second line", src = "a\nb", count = 2, offset = 2, line = 2, col = 1},
	{name = "cr after a", src = "a\r\nb", count = 2, offset = 3, line = 2, col = 1},
	{name = "cr belongs to line one", src = "a\r\nb", count = 2, offset = 1, line = 1, col = 2},
	{name = "trailing newline", src = "a\n", count = 2, offset = 2, line = 2, col = 1},
	{name = "blank lines first", src = "\n\n", count = 3, offset = 0, line = 1, col = 1},
	{name = "blank lines second", src = "\n\n", count = 3, offset = 1, line = 2, col = 1},
	{name = "blank lines end", src = "\n\n", count = 3, offset = 2, line = 3, col = 1},
}

@(test)
test_line_col :: proc(t: ^testing.T) {
	for c in LINE_COL_CASES {
		starts := line_starts(c.src)
		defer delete(starts)
		testing.expectf(t, len(starts) == c.count, "%s: %d starts", c.name, len(starts))
		line, col := line_col(starts, c.offset)
		testing.expectf(t, line == c.line && col == c.col, "%s: got %d:%d", c.name, line, col)
	}
}
