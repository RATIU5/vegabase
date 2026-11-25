package vega

parse_record :: proc(p: ^Parser) -> (range: Range, ok: bool) {
	open := peek(p)
	if open.kind != .Open_Brace {
		return {}, parse_fail(p, open, .Expected_Open_Brace)
	}
	enter(p, open) or_return
	defer leave(p)
	p.pos += 1
	base := len(p.entry_stack)
	skip_newlines(p)
	for peek(p).kind != .Close_Brace {
		if peek(p).kind == .End {
			return {}, parse_fail(p, open, .Unclosed_Bracket)
		}
		entry := parse_entry(p) or_return
		append(&p.entry_stack, entry)
		if skip_separators(p) == 0 && peek(p).kind != .Close_Brace {
			return {}, parse_fail_in(p, open, .Expected_Separator)
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
		return {}, parse_fail(p, key, .Expected_Entry_Key)
	}
	p.pos += 1
	if peek(p).kind != .Equal {
		return {}, parse_fail(p, peek(p), .Expected_Equal)
	}
	p.pos += 1
	entry.key = key.span
	if key.kind == .Of {
		entry.type = parse_type(p) or_return
	} else {
		entry.value = parse_expr(p) or_return
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
	case .Type, .Name:
		prefix, name := parse_type_name(p) or_return
		atom = Type {
			kind   = .Named,
			span   = {token.span.start, name.end},
			prefix = prefix,
			name   = name,
		}
	case:
		return {}, parse_fail(p, token, .Expected_Type)
	}
	if peek(p).kind == .Open_Brace {
		atom.limits = parse_record(p) or_return
		atom.span.end = p.tokens[p.pos - 1].span.end
	}
	return atom, true
}

parse_type_name :: proc(p: ^Parser) -> (prefix, name: Span, ok: bool) {
	token := peek(p)
	if token.kind == .Type {
		p.pos += 1
		return {}, token.span, true
	}
	if token.kind != .Name || peek(p, 1).kind != .Dot {
		return {}, {}, parse_fail(p, token, .Expected_Type)
	}
	type := peek(p, 2)
	if type.kind != .Type {
		return {}, {}, parse_fail(p, type, .Expected_Type_Name)
	}
	p.pos += 3
	return token.span, type.span, true
}
