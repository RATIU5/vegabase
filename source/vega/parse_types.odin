package vega

parse_record :: proc(p: ^Parser) -> (range: Range, ok: bool) {
	open := peek(p)
	if open.kind != .Open_Brace {
		return {}, parse_fail(p, open, EXPECTED_OPEN_BRACE)
	}
	p.pos += 1
	base := len(p.entry_stack)
	skip_newlines(p)
	for peek(p).kind != .Close_Brace {
		if peek(p).kind == .End {
			return {}, parse_fail(p, open, UNCLOSED_BRACKET)
		}
		entry := parse_entry(p) or_return
		append(&p.entry_stack, entry)
		if skip_separators(p) == 0 && peek(p).kind != .Close_Brace {
			return {}, parse_fail_in(p, open, EXPECTED_SEPARATOR)
		}
	}
	p.pos += 1
	range = Range{u32(len(p.file.entries)), u32(len(p.entry_stack) - base)}
	append(&p.file.entries, ..p.entry_stack[base:])
	resize(&p.entry_stack, base)
	return range, true
}

parse_entry :: proc(p: ^Parser) -> (entry: Entry, ok: bool) {
	key := peek(p)
	if key.kind != .Name && key.kind != .Of {
		return {}, parse_fail(p, key, EXPECTED_ENTRY_KEY)
	}
	p.pos += 1
	if peek(p).kind != .Equal {
		return {}, parse_fail(p, peek(p), EXPECTED_EQUAL)
	}
	p.pos += 1
	entry.key = key.span
	if key.kind == .Of {
		entry.type = parse_type(p) or_return
	} else {
		entry.value = skip_expr(p) or_return
	}
	entry.span = {key.span.start, p.tokens[p.pos - 1].span.end}
	return entry, true
}

parse_type :: proc(p: ^Parser) -> (id: Type_Id, ok: bool) {
	first := parse_type_atom(p) or_return
	if peek(p).kind != .Pipe {
		append(&p.file.types, first)
		return Type_Id(len(p.file.types) - 1), true
	}
	base := len(p.type_stack)
	append(&p.type_stack, first)
	last := first
	for peek(p).kind == .Pipe {
		p.pos += 1
		last = parse_type_atom(p) or_return
		append(&p.type_stack, last)
	}
	union_type := Type {
		kind    = .Union,
		span    = {first.span.start, last.span.end},
		members = {u32(len(p.file.types)), u32(len(p.type_stack) - base)},
	}
	append(&p.file.types, ..p.type_stack[base:])
	resize(&p.type_stack, base)
	append(&p.file.types, union_type)
	return Type_Id(len(p.file.types) - 1), true
}

parse_type_atom :: proc(p: ^Parser) -> (atom: Type, ok: bool) {
	token := peek(p)
	#partial switch token.kind {
	case .String:
		atom = Type {
			kind = .Literal,
			span = token.span,
			name = token.span,
		}
		p.pos += 1
	case .Type:
		atom = Type {
			kind = .Named,
			span = token.span,
			name = token.span,
		}
		p.pos += 1
	case .Name:
		if peek(p, 1).kind != .Dot {
			return {}, parse_fail(p, token, EXPECTED_TYPE)
		}
		name := peek(p, 2)
		if name.kind != .Type {
			return {}, parse_fail(p, name, EXPECTED_TYPE_NAME)
		}
		atom = Type {
			kind   = .Named,
			span   = {token.span.start, name.span.end},
			prefix = token.span,
			name   = name.span,
		}
		p.pos += 3
	case:
		return {}, parse_fail(p, token, EXPECTED_TYPE)
	}
	if peek(p).kind == .Open_Brace {
		atom.limits = parse_record(p) or_return
		atom.span.end = p.tokens[p.pos - 1].span.end
	}
	return atom, true
}

closer_of :: proc(kind: Token_Kind) -> Token_Kind {
	#partial switch kind {
	case .Open_Brace:
		return .Close_Brace
	case .Open_Bracket:
		return .Close_Bracket
	}
	return .Close_Paren
}

skip_expr :: proc(p: ^Parser) -> (id: Expr_Id, ok: bool) {
	start := p.pos
	clear(&p.open)
	loop: for {
		token := peek(p)
		#partial switch token.kind {
		case .Open_Brace, .Open_Bracket, .Open_Paren:
			append(&p.open, u32(p.pos))
		case .Close_Brace, .Close_Bracket, .Close_Paren:
			if len(p.open) == 0 {
				break loop
			}
			if closer_of(p.tokens[pop(&p.open)].kind) != token.kind {
				return 0, parse_fail(p, token, MISMATCHED_BRACKET)
			}
		case .Comma, .Newline, .At:
			if len(p.open) == 0 {
				break loop
			}
		case .End:
			if len(p.open) > 0 {
				return 0, parse_fail(p, p.tokens[p.open[0]], UNCLOSED_BRACKET)
			}
			break loop
		}
		p.pos += 1
	}
	if p.pos == start {
		return 0, parse_fail(p, peek(p), EXPECTED_EXPRESSION)
	}
	span := Span{p.tokens[start].span.start, p.tokens[p.pos - 1].span.end}
	append(&p.file.exprs, Expr{span = span})
	return Expr_Id(len(p.file.exprs) - 1), true
}
