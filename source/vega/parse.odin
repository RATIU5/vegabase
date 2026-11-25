package vega

import "base:runtime"
import "core:strings"

MAX_NESTING :: 64

Open_Tag :: struct {
	opener, last: Part_Id,
	has_else:     bool,
}

Parser :: struct {
	file:        ^File,
	tokens:      []Token,
	pos:         int,
	entry_stack: [dynamic]Entry,
	type_stack:  [dynamic]Type,
	expr_stack:  [dynamic]Expr_Id,
	open_tags:   [dynamic]Open_Tag,
	depth:       int,
}

parse :: proc(path, src: string, allocator: runtime.Allocator) -> (file: File, ok: bool) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	file = File {
		path       = path,
		src        = src,
		uses       = make([dynamic]Span, allocator),
		templates  = make([dynamic]Span, allocator),
		decls      = make([dynamic]Decl, allocator),
		fields     = make([dynamic]Field, allocator),
		types      = make([dynamic]Type, allocator),
		entries    = make([dynamic]Entry, allocator),
		exprs      = make([dynamic]Expr, allocator),
		expr_items = make([dynamic]Expr_Id, allocator),
		segments   = make([dynamic]Span, allocator),
		parts      = make([dynamic]Part, allocator),
		errors     = make([dynamic]Error, allocator),
	}
	append(&file.decls, Decl{})
	append(&file.fields, Field{})
	append(&file.types, Type{})
	append(&file.entries, Entry{})
	append(&file.exprs, Expr{})
	append(&file.parts, Part{})

	first, found := next_block(src, 0, &file.errors) or_return
	file.template = {0, u32(len(src))}
	tokens := make([dynamic]Token, context.temp_allocator)
	p := Parser {
		file        = &file,
		entry_stack = make([dynamic]Entry, context.temp_allocator),
		type_stack  = make([dynamic]Type, context.temp_allocator),
		expr_stack  = make([dynamic]Expr_Id, context.temp_allocator),
		open_tags   = make([dynamic]Open_Tag, context.temp_allocator),
	}
	if found && strings.trim(src[:first.span.start], " \t\r\n") == "" {
		file.template.start = first.span.end
		if !lex(src, first.code, &tokens, &file.errors) {
			return file, false
		}
		p.tokens = tokens[:]
		if !parse_first_block(&p) {
			return file, false
		}
	}
	ok = parse_template(&p, &tokens)
	return file, ok
}

parse_fail :: proc(p: ^Parser, token: Token, code: Error_Code) -> bool {
	return fail(&p.file.errors, int(token.span.start), int(token.span.end), code)
}

enter :: proc(p: ^Parser, token: Token) -> bool {
	if p.depth >= MAX_NESTING {
		return parse_fail(p, token, .Nested_Too_Deeply)
	}
	p.depth += 1
	return true
}

leave :: proc(p: ^Parser) {
	p.depth -= 1
}

peek :: proc(p: ^Parser, ahead := 0) -> Token {
	return p.tokens[min(p.pos + ahead, len(p.tokens) - 1)]
}

parse_first_block :: proc(p: ^Parser) -> bool {
	for {
		for peek(p).kind == .Newline {
			p.pos += 1
		}
		if peek(p).kind == .End {
			return true
		}
		if !parse_statement(p) {
			return false
		}
		if kind := peek(p).kind; kind != .Newline && kind != .End {
			return parse_fail(p, peek(p), .Expected_Newline)
		}
	}
}

is_locale_word :: proc(kind: Token_Kind) -> bool {
	return kind == .Name || (kind >= .Of && kind <= .Null)
}

is_locale_name :: proc(text: string) -> bool {
	i := 0
	for i < len(text) && is_lower(text[i]) {
		i += 1
	}
	if i < 2 || i > 3 {
		return false
	}
	for i < len(text) {
		if text[i] != '_' {
			return false
		}
		i += 1
		start := i
		for i < len(text) && is_alnum(text[i]) {
			i += 1
		}
		if i - start < 2 || i - start > 8 {
			return false
		}
	}
	return true
}

parse_statement :: proc(p: ^Parser) -> bool {
	token := peek(p)
	if is_locale_word(token.kind) && peek(p, 1).kind == .Colon_Colon {
		return parse_locale(p)
	}
	#partial switch token.kind {
	case .Use:
		name := peek(p, 1)
		if name.kind != .Name {
			return parse_fail(p, name, .Expected_Name)
		}
		append(&p.file.uses, name.span)
		p.pos += 2
		return true
	case .Template:
		name := peek(p, 1)
		if name.kind != .Type {
			return parse_fail(p, name, .Expected_Type_Name)
		}
		append(&p.file.templates, name.span)
		p.pos += 2
		return true
	case .Type:
		return parse_declaration(p)
	}
	return parse_fail(p, token, .Expected_Statement)
}

parse_locale :: proc(p: ^Parser) -> bool {
	name := peek(p)
	if !is_locale_name(p.file.src[name.span.start:name.span.end]) {
		return parse_fail(p, name, .Bad_Locale_Name)
	}
	p.pos += 2
	if peek(p).kind != .Locale {
		return parse_fail(p, peek(p), .Expected_Locale)
	}
	p.pos += 1
	decl := Decl {
		kind = .Locale,
		name = name.span,
	}
	decl.entries = parse_record(p) or_return
	add_decl(p, decl)
	return true
}

parse_declaration :: proc(p: ^Parser) -> bool {
	name := peek(p)
	if peek(p, 1).kind != .Colon_Colon {
		return parse_fail(p, peek(p, 1), .Expected_Colon_Colon)
	}
	p.pos += 2
	decl := Decl {
		kind = .Alias,
		name = name.span,
	}
	body := peek(p)
	#partial switch body.kind {
	case .Component, .Content:
		decl.kind = .Component if body.kind == .Component else .Content
		p.pos += 1
		parse_body(p, &decl) or_return
	case .Type, .String, .Name:
		if body.kind == .Name && (peek(p, 1).kind != .Dot || peek(p, 2).kind != .Type) {
			return parse_fail(p, body, .Expected_Declaration)
		}
		decl.type = parse_type(p) or_return
		if peek(p).kind == .At {
			p.pos += 1
			decl.admin = parse_record(p) or_return
		}
	case:
		return parse_fail(p, body, .Expected_Declaration)
	}
	add_decl(p, decl)
	return true
}

add_decl :: proc(p: ^Parser, decl: Decl) {
	decl := decl
	decl.span = {decl.name.start, p.tokens[p.pos - 1].span.end}
	append(&p.file.decls, decl)
}

parse_fail_in :: proc(p: ^Parser, open: Token, code: Error_Code) -> bool {
	if peek(p).kind == .End {
		return parse_fail(p, open, .Unclosed_Bracket)
	}
	return parse_fail(p, peek(p), code)
}

skip_newlines :: proc(p: ^Parser) -> (count: int) {
	for peek(p).kind == .Newline {
		p.pos += 1
		count += 1
	}
	return count
}

skip_separators :: proc(p: ^Parser) -> (count: int) {
	for peek(p).kind == .Newline || peek(p).kind == .Comma {
		p.pos += 1
		count += 1
	}
	return count
}

Body_Part :: enum u8 {
	Admin,
	Fields,
	Props,
}

duplicate_code :: proc(part: Body_Part) -> Error_Code {
	switch part {
	case .Admin:
		return .Duplicate_Admin
	case .Fields:
		return .Duplicate_Fields
	case .Props:
		return .Duplicate_Props
	}
	unreachable()
}

parse_body :: proc(p: ^Parser, decl: ^Decl) -> bool {
	open := peek(p)
	if open.kind != .Open_Brace {
		return parse_fail(p, open, .Expected_Open_Brace)
	}
	p.pos += 1
	seen: bit_set[Body_Part]
	skip_newlines(p)
	for peek(p).kind != .Close_Brace {
		if peek(p).kind == .End {
			return parse_fail(p, open, .Unclosed_Bracket)
		}
		parse_body_part(p, decl, &seen) or_return
		if skip_newlines(p) == 0 && peek(p).kind != .Close_Brace {
			return parse_fail_in(p, open, .Expected_Part_End)
		}
	}
	p.pos += 1
	return true
}

parse_body_part :: proc(p: ^Parser, decl: ^Decl, seen: ^bit_set[Body_Part]) -> bool {
	token := peek(p)
	part: Body_Part
	#partial switch token.kind {
	case .At:
		part = .Admin
	case .Fields:
		part = .Fields
	case .Props:
		part = .Props
	case:
		return parse_fail(p, token, .Expected_Body_Part)
	}
	if part in seen {
		return parse_fail(p, token, duplicate_code(part))
	}
	seen^ += {part}
	p.pos += 1
	switch part {
	case .Admin:
		decl.admin = parse_record(p) or_return
	case .Fields:
		decl.fields = parse_fields(p) or_return
	case .Props:
		decl.props = parse_fields(p) or_return
	}
	return true
}

parse_fields :: proc(p: ^Parser) -> (range: Range, ok: bool) {
	open := peek(p)
	if open.kind != .Open_Brace {
		return {}, parse_fail(p, open, .Expected_Open_Brace)
	}
	p.pos += 1
	first := len(p.file.fields)
	skip_newlines(p)
	for peek(p).kind != .Close_Brace {
		if peek(p).kind == .End {
			return {}, parse_fail(p, open, .Unclosed_Bracket)
		}
		parse_field(p) or_return
		if skip_separators(p) == 0 && peek(p).kind != .Close_Brace {
			return {}, parse_fail_in(p, open, .Expected_Separator)
		}
	}
	p.pos += 1
	return Range{u32(first), u32(len(p.file.fields) - first)}, true
}

parse_field :: proc(p: ^Parser) -> bool {
	name := peek(p)
	if name.kind != .Name {
		return parse_fail(p, name, .Expected_Name)
	}
	p.pos += 1
	if peek(p).kind != .Colon {
		return parse_fail(p, peek(p), .Expected_Colon)
	}
	p.pos += 1
	field := Field {
		name = name.span,
	}
	if peek(p).kind == .Slot {
		field.is_slot = true
		p.pos += 1
	}
	field.type = parse_type(p) or_return
	if peek(p).kind == .Question {
		field.optional = true
		p.pos += 1
	}
	if peek(p).kind == .Equal {
		p.pos += 1
		field.default = parse_expr(p) or_return
	}
	if peek(p).kind == .At {
		p.pos += 1
		field.admin = parse_record(p) or_return
	}
	field.span = {name.span.start, p.tokens[p.pos - 1].span.end}
	append(&p.file.fields, field)
	return true
}
