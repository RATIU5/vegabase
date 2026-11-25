package vega

import "core:strings"

BLOCK_NEVER_CLOSED :: "{{ is never closed"

Block :: struct {
	span: Span,
	code: Span,
}

next_block :: proc(
	src: string,
	from: int,
	errors: ^[dynamic]Error,
) -> (
	block: Block,
	found: bool,
	ok: bool,
) {
	assert(len(src) <= int(max(u32)))

	start := -1
	for k := from; k < len(src); {
		brace := strings.index_byte(src[k:], '{')
		if brace < 0 {
			break
		}
		k += brace
		if k + 1 < len(src) && src[k + 1] == '{' {
			start = k
			break
		}
		k += 1
	}
	if start < 0 {
		return {}, false, true
	}
	j := start + 2
	depth := 0
	for {
		if j >= len(src) {
			return {}, false, fail(errors, start, start + 2, BLOCK_NEVER_CLOSED)
		}
		switch src[j] {
		case '"':
			end := j + 1
			for end < len(src) && src[end] != '"' && src[end] != '\n' {
				end += 2 if src[end] == '\\' else 1
			}
			if end >= len(src) || src[end] != '"' {
				return {}, false, fail(errors, j, j + 1, STRING_NEVER_CLOSED)
			}
			j = end + 1
		case '#':
			newline := strings.index_byte(src[j:], '\n')
			line_end := len(src) if newline < 0 else j + newline
			close := strings.index(src[j:line_end], "}}")
			if newline < 0 && close < 0 {
				return {}, false, fail(errors, start, start + 2, BLOCK_NEVER_CLOSED)
			}
			if close >= 0 {
				j += close
			} else {
				j += newline
			}
		case '{':
			depth += 1
			j += 1
		case '}':
			if depth > 0 {
				depth -= 1
				j += 1
			} else if strings.has_prefix(src[j:], "}}") {
				return Block{span = {u32(start), u32(j + 2)}, code = {u32(start + 2), u32(j)}},
					true,
					true
			} else {
				return {}, false, fail(errors, j, j + 1, "} with no {")
			}
		case:
			j += 1
		}
	}
}

scan :: proc(src: string, blocks: ^[dynamic]Block, errors: ^[dynamic]Error) -> (ok: bool) {
	i := 0
	for {
		block, found := next_block(src, i, errors) or_return
		if !found {
			return true
		}
		append(blocks, block)
		i = int(block.span.end)
	}
}
