package vega

import "core:fmt"
import "core:reflect"
import "core:strings"

write_quoted :: proc(b: ^strings.Builder, text: string) {
	strings.write_byte(b, '"')
	for i in 0 ..< len(text) {
		c := text[i]
		switch c {
		case '"':
			strings.write_string(b, `\"`)
		case '\\':
			strings.write_string(b, `\\`)
		case '\n':
			strings.write_string(b, `\n`)
		case '\r':
			strings.write_string(b, `\r`)
		case '\t':
			strings.write_string(b, `\t`)
		case 0 ..< 0x20:
			fmt.sbprintf(b, `\u%04x`, c)
		case:
			strings.write_byte(b, c)
		}
	}
	strings.write_byte(b, '"')
}

write_head :: proc(b: ^strings.Builder, starts: []u32, label: string, span: Span) {
	line, col := line_col(starts, span.start)
	fmt.sbprintf(b, "%s@%d..%d %d:%d", label, span.start, span.end, line, col)
}

write_error :: proc(b: ^strings.Builder, starts: []u32, err: Error) {
	write_head(b, starts, "Error", err.span)
	strings.write_byte(b, ' ')
	write_quoted(b, err.message)
	strings.write_byte(b, '\n')
}

dump_tokens :: proc(src: string, allocator := context.allocator) -> string {
	blocks := make([dynamic]Block, allocator)
	defer delete(blocks)
	tokens := make([dynamic]Token, allocator)
	defer delete(tokens)
	errors := make([dynamic]Error, allocator)
	defer delete(errors)

	b := strings.builder_make(allocator)
	starts := line_starts(src, allocator)
	defer delete(starts)

	scanned := scan(src, &blocks, &errors)
	for block in blocks {
		clear(&tokens)
		lexed := lex(src, block.code, &tokens, &errors)
		write_head(&b, starts, "Block", block.span)
		strings.write_byte(&b, '\n')
		for token in tokens {
			strings.write_string(&b, "  ")
			write_head(&b, starts, reflect.enum_string(token.kind), token.span)
			strings.write_byte(&b, ' ')
			write_quoted(&b, src[token.span.start:token.span.end])
			strings.write_byte(&b, '\n')
		}
		if !lexed {
			write_error(&b, starts, errors[len(errors) - 1])
			return strings.to_string(b)
		}
	}
	if !scanned {
		write_error(&b, starts, errors[len(errors) - 1])
	}
	return strings.to_string(b)
}
