package vega

EXPECTED_BLOCK_END :: "expected }} to end the block"
EXPECTED_IN :: "expected in"
ELIF_OUTSIDE_IF :: "{{elif}} is not inside an open {{if}}"
ELSE_OUTSIDE_IF :: "{{else}} is not inside an open {{if}}"
END_IF_CLOSES_NOTHING :: "{{/if}} closes nothing"
END_FOR_CLOSES_NOTHING :: "{{/for}} closes nothing"
IF_NEVER_CLOSED :: "{{if}} is never closed"
FOR_NEVER_CLOSED :: "{{for}} is never closed"
STATEMENT_OUTSIDE_FIRST_BLOCK :: "use, template and declarations belong in the first block"

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
	case .Slot:
		part.kind = .Slot
		p.pos += 1
		part.name = parse_name(p) or_return
		if peek(p).kind == .Open_Brace {
			part.entries = parse_record(p) or_return
		}
	case .Render:
		part.kind = .Render
		p.pos += 1
		start := peek(p).span.start
		_, name := parse_type_name(p) or_return
		part.name = {start, name.end}
		part.entries = parse_record(p) or_return
	case:
		part.kind = .Value
		part.expr = parse_expr(p) or_return
	}
	return true
}

nest_part :: proc(p: ^Parser, part: ^Part) -> bool {
	parts := p.file.parts[:]
	id := Part_Id(len(parts))
	top := len(p.open_tags) - 1
	switch part.kind {
	case .If, .For:
		append(&p.open_tags, Open_Tag{opener = id, last = id})
	case .Elif, .Else:
		if top < 0 || parts[p.open_tags[top].opener].kind != .If || p.open_tags[top].has_else {
			message := ELIF_OUTSIDE_IF if part.kind == .Elif else ELSE_OUTSIDE_IF
			return fail(&p.file.errors, int(part.span.start), int(part.span.end), message)
		}
		tag := &p.open_tags[top]
		parts[tag.last].closes = id
		tag.last = id
		tag.has_else = part.kind == .Else
	case .End_If, .End_For:
		want := Part_Kind.If if part.kind == .End_If else Part_Kind.For
		if top < 0 || parts[p.open_tags[top].opener].kind != want {
			message := END_IF_CLOSES_NOTHING if part.kind == .End_If else END_FOR_CLOSES_NOTHING
			return fail(&p.file.errors, int(part.span.start), int(part.span.end), message)
		}
		tag := p.open_tags[top]
		parts[tag.last].closes = id
		part.closes = tag.opener
		pop(&p.open_tags)
	case .Html, .Value, .Slot, .Render:
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
		if peek(p).kind == .End {
			continue
		}
		part := Part {
			span = block.span,
		}
		skip_newlines(p)
		if kind := peek(p).kind;
		   kind == .Use || kind == .Template || peek(p, 1).kind == .Colon_Colon {
			return parse_fail(p, peek(p), STATEMENT_OUTSIDE_FIRST_BLOCK)
		}
		p.pos = 0
		parse_tag(p, &part) or_return
		if peek(p).kind != .End {
			return parse_fail(p, peek(p), EXPECTED_BLOCK_END)
		}
		nest_part(p, &part) or_return
		append(&p.file.parts, part)
	}
	add_html(p, at, len(p.file.src))
	if len(p.open_tags) > 0 {
		open := p.file.parts[p.open_tags[len(p.open_tags) - 1].opener]
		message := IF_NEVER_CLOSED if open.kind == .If else FOR_NEVER_CLOSED
		return fail(&p.file.errors, int(open.span.start), int(open.span.end), message)
	}
	return true
}
