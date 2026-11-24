package vega

EXPECTED_BLOCK_END :: "expected }} to end the block"
EXPECTED_IN :: "expected in"

is_tag_keyword :: proc(kind: Token_Kind) -> bool {
	#partial switch kind {
	case .Slot, .Render:
		return true
	}
	return false
}

add_html :: proc(p: ^Parser, start, end: int) {
	if start == end {
		return
	}
	append(&p.file.parts, Part{kind = .Html, span = {u32(start), u32(end)}, position = .Text})
}

parse_name :: proc(p: ^Parser) -> (span: Span, ok: bool) {
	name := peek(p)
	if name.kind != .Name {
		return {}, parse_fail(p, name, EXPECTED_NAME)
	}
	p.pos += 1
	return name.span, true
}

parse_tag :: proc(p: ^Parser, part: ^Part) -> bool {
	token := peek(p)
	#partial switch token.kind {
	case .If, .Elif:
		part.kind = .If if token.kind == .If else .Elif
		p.pos += 1
		part.expr = parse_expr(p) or_return
	case .Else:
		part.kind = .Else
		p.pos += 1
	case .End_If:
		part.kind = .End_If
		p.pos += 1
	case .For:
		part.kind = .For
		p.pos += 1
		part.item = parse_name(p) or_return
		if peek(p).kind == .Comma {
			p.pos += 1
			part.index = parse_name(p) or_return
		}
		if peek(p).kind != .In {
			return parse_fail(p, peek(p), EXPECTED_IN)
		}
		p.pos += 1
		part.expr = parse_expr(p) or_return
	case .End_For:
		part.kind = .End_For
		p.pos += 1
	case:
		part.kind = .Value
		part.expr = parse_expr(p) or_return
	}
	return true
}

parse_template :: proc(p: ^Parser, tokens: ^[dynamic]Token, blocks: []Block) -> bool {
	at := int(p.file.template.start)
	for block in blocks {
		add_html(p, at, int(block.span.start))
		at = int(block.span.end)
		clear(tokens)
		lex(p.file.src, block.code, tokens, &p.file.errors) or_return
		p.tokens = tokens[:]
		p.pos = 0
		kind := peek(p).kind
		if kind == .End || is_tag_keyword(kind) {
			continue
		}
		part := Part {
			span = block.span,
		}
		parse_tag(p, &part) or_return
		if peek(p).kind != .End {
			return parse_fail(p, peek(p), EXPECTED_BLOCK_END)
		}
		append(&p.file.parts, part)
	}
	add_html(p, at, len(p.file.src))
	return true
}
