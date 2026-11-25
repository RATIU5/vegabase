package vega

add_expr :: proc(p: ^Parser, expr: Expr) -> Expr_Id {
	append(&p.file.exprs, expr)
	return Expr_Id(len(p.file.exprs) - 1)
}

span_from :: proc(p: ^Parser, start: int) -> Span {
	return {p.tokens[start].span.start, p.tokens[p.pos - 1].span.end}
}

flush_exprs :: proc(p: ^Parser, base: int) -> Range {
	range := Range{u32(len(p.file.expr_items)), u32(len(p.expr_stack) - base)}
	append(&p.file.expr_items, ..p.expr_stack[base:])
	resize(&p.expr_stack, base)
	return range
}

is_compare :: proc(kind: Token_Kind) -> bool {
	return kind >= .Equal_Equal && kind <= .Greater_Equal
}

is_operator :: proc(kind: Token_Kind) -> bool {
	return(
		(kind >= .Equal_Equal && kind <= .Percent) ||
		kind == .Pipe ||
		kind == .Question_Question ||
		kind == .And ||
		kind == .Or \
	)
}

literal_kind :: proc(kind: Token_Kind) -> (Expr_Kind, bool) {
	#partial switch kind {
	case .String:
		return .String, true
	case .Int:
		return .Int, true
	case .Decimal:
		return .Decimal, true
	case .True, .False:
		return .Bool, true
	case .Null:
		return .Null, true
	case .Host_Value:
		return .Host_Value, true
	}
	return {}, false
}

parse_expr :: proc(p: ^Parser) -> (id: Expr_Id, ok: bool) {
	start := p.pos
	left, bare := parse_simple(p) or_return
	#partial switch peek(p).kind {
	case .Pipe:
		if !bare {
			return 0, parse_fail(p, peek(p), .Pipe_Needs_Operand)
		}
		id = parse_pipe(p, start, left) or_return
	case .And:
		id = parse_chain(p, start, left, .And) or_return
	case .Or:
		id = parse_chain(p, start, left, .Or) or_return
	case:
		id = left
	}
	token := peek(p)
	if is_operator(token.kind) {
		if is_compare(token.kind) && p.file.exprs[id].kind == .Compare {
			return 0, parse_fail(p, token, .Compare_Chained)
		}
		return 0, parse_fail(p, token, .Operator_Needs_Parens)
	}
	if token.kind == .Dot {
		return 0, parse_fail(p, token, .Unexpected_Dot)
	}
	return id, true
}

parse_chain :: proc(
	p: ^Parser,
	start: int,
	first: Expr_Id,
	op: Token_Kind,
) -> (
	id: Expr_Id,
	ok: bool,
) {
	kind := Expr_Kind.And if op == .And else Expr_Kind.Or
	forbidden := Token_Kind.Or if op == .And else Token_Kind.And
	id = first
	for peek(p).kind == op {
		p.pos += 1
		right, _ := parse_simple(p) or_return
		id = add_expr(
			p,
			Expr{kind = kind, op = op, left = id, right = right, span = span_from(p, start)},
		)
	}
	if peek(p).kind == forbidden {
		return 0, parse_fail(p, peek(p), .And_Or_Mixed)
	}
	return id, true
}

parse_pipe :: proc(p: ^Parser, start: int, input: Expr_Id) -> (id: Expr_Id, ok: bool) {
	id = input
	for peek(p).kind == .Pipe {
		p.pos += 1
		target := parse_pipe_target(p) or_return
		id = add_expr(p, Expr{kind = .Pipe, left = id, right = target, span = span_from(p, start)})
	}
	return id, true
}

parse_pipe_target :: proc(p: ^Parser) -> (id: Expr_Id, ok: bool) {
	start := p.pos
	call := Expr {
		kind = .Call,
	}
	call.name = parse_fn_name(p) or_return
	if peek(p).kind == .Open_Paren {
		call.items = parse_args(p) or_return
	}
	call.span = span_from(p, start)
	return add_expr(p, call), true
}

parse_simple :: proc(p: ^Parser) -> (id: Expr_Id, bare: bool, ok: bool) {
	start := p.pos
	if peek(p).kind == .Not {
		p.pos += 1
		operand := parse_operand(p) or_return
		id = add_expr(p, Expr{kind = .Not, left = operand, span = span_from(p, start)})
		return id, false, true
	}
	id, bare = parse_sum(p) or_return
	kind := peek(p).kind
	switch {
	case is_compare(kind):
		p.pos += 1
		right, _ := parse_sum(p) or_return
		id = add_expr(
			p,
			Expr{kind = .Compare, op = kind, left = id, right = right, span = span_from(p, start)},
		)
		return id, false, true
	case kind == .Question_Question:
		if !bare {
			return 0, false, parse_fail(p, peek(p), .Coalesce_Needs_Operand)
		}
		for peek(p).kind == .Question_Question {
			p.pos += 1
			right := parse_operand(p) or_return
			id = add_expr(
				p,
				Expr {
					kind = .Coalesce,
					op = .Question_Question,
					left = id,
					right = right,
					span = span_from(p, start),
				},
			)
		}
		return id, false, true
	}
	return id, bare, true
}

parse_sum :: proc(p: ^Parser) -> (id: Expr_Id, bare: bool, ok: bool) {
	start := p.pos
	id, bare = parse_product(p) or_return
	for peek(p).kind == .Plus || peek(p).kind == .Minus {
		op := peek(p).kind
		p.pos += 1
		right, _ := parse_product(p) or_return
		id = add_expr(
			p,
			Expr{kind = .Arith, op = op, left = id, right = right, span = span_from(p, start)},
		)
		bare = false
	}
	return id, bare, true
}

parse_product :: proc(p: ^Parser) -> (id: Expr_Id, bare: bool, ok: bool) {
	start := p.pos
	id, bare = parse_unary(p) or_return
	for kind := peek(p).kind; kind == .Star || kind == .Slash || kind == .Percent; {
		p.pos += 1
		right, _ := parse_unary(p) or_return
		id = add_expr(
			p,
			Expr{kind = .Arith, op = kind, left = id, right = right, span = span_from(p, start)},
		)
		bare = false
		kind = peek(p).kind
	}
	return id, bare, true
}

parse_unary :: proc(p: ^Parser) -> (id: Expr_Id, bare: bool, ok: bool) {
	start := p.pos
	for peek(p).kind == .Minus {
		p.pos += 1
	}
	signs := p.pos - start
	id = parse_operand(p) or_return
	end := p.tokens[p.pos - 1].span.end
	for i := signs - 1; i >= 0; i -= 1 {
		span := Span{p.tokens[start + i].span.start, end}
		id = add_expr(p, Expr{kind = .Negate, left = id, span = span})
	}
	return id, signs == 0, true
}

parse_operand :: proc(p: ^Parser) -> (id: Expr_Id, ok: bool) {
	token := peek(p)
	if kind, is_literal := literal_kind(token.kind); is_literal {
		p.pos += 1
		return add_expr(p, Expr{kind = kind, span = token.span}), true
	}
	#partial switch token.kind {
	case .Name:
		return parse_name_operand(p)
	case .Type:
		return parse_component_value(p)
	case .Open_Brace:
		start := p.pos
		items := parse_record(p) or_return
		return add_expr(p, Expr{kind = .Record, items = items, span = span_from(p, start)}), true
	case .Open_Bracket:
		return parse_list(p)
	case .Open_Paren:
		return parse_paren(p)
	}
	return 0, parse_fail(p, token, .Expected_Expression)
}

parse_name_operand :: proc(p: ^Parser) -> (id: Expr_Id, ok: bool) {
	second := peek(p, 1).kind
	if second == .Dot && peek(p, 2).kind == .Type {
		return parse_component_value(p)
	}
	if second == .Open_Paren ||
	   (second == .Dot && peek(p, 2).kind == .Name && peek(p, 3).kind == .Open_Paren) {
		start := p.pos
		name := parse_fn_name(p) or_return
		items := parse_args(p) or_return
		return add_expr(
				p,
				Expr{kind = .Call, name = name, items = items, span = span_from(p, start)},
			),
			true
	}
	start := p.pos
	p.pos += 1
	for peek(p).kind == .Dot {
		if peek(p, 1).kind != .Name {
			return 0, parse_fail(p, peek(p, 1), .Expected_Name)
		}
		p.pos += 2
	}
	span := span_from(p, start)
	return add_expr(p, Expr{kind = .Path, name = span, span = span}), true
}

parse_fn_name :: proc(p: ^Parser) -> (name: Span, ok: bool) {
	first := peek(p)
	if first.kind != .Name {
		return {}, parse_fail(p, first, .Expected_Name)
	}
	p.pos += 1
	name = first.span
	if peek(p).kind == .Dot {
		member := peek(p, 1)
		if member.kind != .Name {
			return {}, parse_fail(p, member, .Expected_Name)
		}
		p.pos += 2
		name.end = member.span.end
	}
	return name, true
}

parse_component_value :: proc(p: ^Parser) -> (id: Expr_Id, ok: bool) {
	start := p.pos
	if peek(p).kind == .Name {
		p.pos += 2
	}
	name := Span{p.tokens[start].span.start, peek(p).span.end}
	p.pos += 1
	items := parse_record(p) or_return
	expr := Expr {
		kind  = .Component_Value,
		name  = name,
		items = items,
		span  = span_from(p, start),
	}
	return add_expr(p, expr), true
}

parse_args :: proc(p: ^Parser) -> (range: Range, ok: bool) {
	open := peek(p)
	enter(p, open) or_return
	defer leave(p)
	p.pos += 1
	base := len(p.expr_stack)
	if peek(p).kind != .Close_Paren {
		for {
			skip_newlines(p)
			arg := parse_expr(p) or_return
			append(&p.expr_stack, arg)
			skip_newlines(p)
			if peek(p).kind != .Comma {
				break
			}
			p.pos += 1
		}
	}
	if peek(p).kind != .Close_Paren {
		return {}, parse_fail_in(p, open, .Expected_Call_End)
	}
	p.pos += 1
	return flush_exprs(p, base), true
}

parse_list :: proc(p: ^Parser) -> (id: Expr_Id, ok: bool) {
	start := p.pos
	open := peek(p)
	enter(p, open) or_return
	defer leave(p)

	p.pos += 1
	base := len(p.expr_stack)
	skip_newlines(p)
	for peek(p).kind != .Close_Bracket {
		if peek(p).kind == .End {
			return 0, parse_fail(p, open, .Unclosed_Bracket)
		}
		item := parse_expr(p) or_return
		append(&p.expr_stack, item)
		if skip_separators(p) == 0 && peek(p).kind != .Close_Bracket {
			return 0, parse_fail_in(p, open, .Expected_List_End)
		}
	}
	p.pos += 1
	items := flush_exprs(p, base)
	return add_expr(p, Expr{kind = .List, items = items, span = span_from(p, start)}), true
}

parse_paren :: proc(p: ^Parser) -> (id: Expr_Id, ok: bool) {
	open := peek(p)
	enter(p, open) or_return
	defer leave(p)
	p.pos += 1
	skip_newlines(p)
	id = parse_expr(p) or_return
	skip_newlines(p)
	if peek(p).kind != .Close_Paren {
		return 0, parse_fail_in(p, open, .Expected_Close_Paren)
	}
	p.pos += 1
	return id, true
}
