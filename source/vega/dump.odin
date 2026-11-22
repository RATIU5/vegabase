package vega

import "core:fmt"
import "core:reflect"
import "core:strings"

Position :: struct {
	offset:     int,
	line:       int,
	line_start: int,
}

locate :: proc(p: ^Position, src: string, offset: int) -> (line, col: int) {
	for p.offset < offset {
		if src[p.offset] == '\n' {
			p.line += 1
			p.line_start = p.offset + 1
		}
		p.offset += 1
	}
	return p.line, offset - p.line_start + 1
}

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

write_head :: proc(b: ^strings.Builder, p: ^Position, src, label: string, span: Span) {
	line, col := locate(p, src, int(span.start))
	fmt.sbprintf(b, "%s@%d..%d %d:%d", label, span.start, span.end, line, col)
}

write_error :: proc(b: ^strings.Builder, p: ^Position, src: string, err: Error) {
	write_head(b, p, src, "Error", err.span)
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
	p := Position {
		line = 1,
	}

	scanned := scan(src, &blocks, &errors)
	for block in blocks {
		clear(&tokens)
		lexed := lex(src, block.code, &tokens, &errors)
		write_head(&b, &p, src, "Block", block.span)
		strings.write_byte(&b, '\n')
		for token in tokens {
			strings.write_string(&b, "  ")
			write_head(&b, &p, src, reflect.enum_string(token.kind), token.span)
			strings.write_byte(&b, ' ')
			write_quoted(&b, src[token.span.start:token.span.end])
			strings.write_byte(&b, '\n')
		}
		if !lexed {
			write_error(&b, &p, src, errors[len(errors) - 1])
			return strings.to_string(b)
		}
	}
	if !scanned {
		write_error(&b, &p, src, errors[len(errors) - 1])
	}
	return strings.to_string(b)
}
