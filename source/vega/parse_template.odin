package vega

EXPECTED_BLOCK_END :: "expected }} to end the block"

is_tag_keyword :: proc(kind: Token_Kind) -> bool {
	#partial switch kind {
	case .For, .End_For, .Slot, .Render:
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
			kind = .Value,
			span = block.span,
		}
		#partial switch kind {
		case .If:
			part.kind = .If
		case .Elif:
			part.kind = .Elif
		case .Else:
			part.kind = .Else
		case .End_If:
			part.kind = .End_If
		}
		if part.kind != .Value {
			p.pos += 1
		}
		if part.kind == .Value || part.kind == .If || part.kind == .Elif {
			part.expr = parse_expr(p) or_return
		}
		if peek(p).kind != .End {
			return parse_fail(p, peek(p), EXPECTED_BLOCK_END)
		}
		append(&p.file.parts, part)
	}
	add_html(p, at, len(p.file.src))
	return true
}
