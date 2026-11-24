package vega

import "base:runtime"
import "core:strings"

EXPECTED_STATEMENT :: "expected use, template or a declaration"
EXPECTED_NEWLINE :: "expected a new line after the statement"
EXPECTED_NAME :: "expected a name"
EXPECTED_TYPE_NAME :: "expected a type name"
EXPECTED_COLON_COLON :: "expected ::"
EXPECTED_DECLARATION :: "expected component, content or a type after ::"
EXPECTED_LOCALE :: "expected locale after ::"
EXPECTED_OPEN_BRACE :: "expected {"
EXPECTED_BODY_PART :: "expected @, fields or props"
EXPECTED_PART_END :: "expected a new line or }"
EXPECTED_COLON :: "expected :"
EXPECTED_SEPARATOR :: "expected , or a new line or }"
EXPECTED_EQUAL :: "expected ="
EXPECTED_ENTRY_KEY :: "expected a name or of"
EXPECTED_TYPE :: "expected a type"
EXPECTED_EXPRESSION :: "expected an expression"
DUPLICATE_ADMIN :: "a declaration can have only one @ block"
DUPLICATE_FIELDS :: "a declaration can have only one fields group"
DUPLICATE_PROPS :: "a declaration can have only one props group"
BAD_LOCALE_NAME :: "locale name must be a language code such as en or pt_BR"
UNCLOSED_BRACKET :: "bracket is never closed"
NESTED_TOO_DEEPLY :: "nesting is too deep"

MAX_NESTING :: 64

Parser :: struct {
	file:        ^File,
	tokens:      []Token,
	pos:         int,
	entry_stack: [dynamic]Entry,
	type_stack:  [dynamic]Type,
	expr_stack:  [dynamic]Expr_Id,
	depth:       int,
}

parse :: proc(path, src: string, allocator: runtime.Allocator) -> (file: File, ok: bool) {
	file = File {
		path       = path,
		src        = src,
		uses       = make([dynamic]Span, allocator),
		decls      = make([dynamic]Decl, allocator),
		fields     = make([dynamic]Field, allocator),
		types      = make([dynamic]Type, allocator),
		entries    = make([dynamic]Entry, allocator),
		exprs      = make([dynamic]Expr, allocator),
		expr_items = make([dynamic]Expr_Id, allocator),
		parts      = make([dynamic]Part, allocator),
		errors     = make([dynamic]Error, allocator),
	}
	append(&file.decls, Decl{})
	append(&file.fields, Field{})
	append(&file.types, Type{})
	append(&file.entries, Entry{})
	append(&file.exprs, Expr{})
	append(&file.parts, Part{})

	blocks := make([dynamic]Block, allocator)
	if !scan(src, &blocks, &file.errors) {
		return file, false
	}
	file.template = {0, u32(len(src))}
	if len(blocks) == 0 || strings.trim_space(src[:blocks[0].span.start]) != "" {
		return file, true
	}
	first := blocks[0]
	file.template.start = first.span.end

	tokens := make([dynamic]Token, allocator)
	if !lex(src, first.code, &tokens, &file.errors) {
		return file, false
	}
	p := Parser {
		file        = &file,
		tokens      = tokens[:],
		entry_stack = make([dynamic]Entry, allocator),
		type_stack  = make([dynamic]Type, allocator),
		expr_stack  = make([dynamic]Expr_Id, allocator),
	}
	ok = parse_first_block(&p)
	return file, ok
}

parse_fail :: proc(p: ^Parser, token: Token, message: string) -> bool {
	return fail(&p.file.errors, int(token.span.start), int(token.span.end), message)
}

enter :: proc(p: ^Parser, token: Token) -> bool {
	if p.depth >= MAX_NESTING {
		return parse_fail(p, token, NESTED_TOO_DEEPLY)
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
			return parse_fail(p, peek(p), EXPECTED_NEWLINE)
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
			return parse_fail(p, name, EXPECTED_NAME)
		}
		append(&p.file.uses, name.span)
		p.pos += 2
		return true
	case .Template:
		name := peek(p, 1)
		if name.kind != .Type {
			return parse_fail(p, name, EXPECTED_TYPE_NAME)
		}
		p.file.template_type = name.span
		p.pos += 2
		return true
	case .Type:
		return parse_declaration(p)
	}
	return parse_fail(p, token, EXPECTED_STATEMENT)
}

parse_locale :: proc(p: ^Parser) -> bool {
	name := peek(p)
	if !is_locale_name(p.file.src[name.span.start:name.span.end]) {
		return parse_fail(p, name, BAD_LOCALE_NAME)
	}
	p.pos += 2
	if peek(p).kind != .Locale {
		return parse_fail(p, peek(p), EXPECTED_LOCALE)
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
		return parse_fail(p, peek(p, 1), EXPECTED_COLON_COLON)
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
			return parse_fail(p, body, EXPECTED_DECLARATION)
		}
		decl.type = parse_type(p) or_return
		if peek(p).kind == .At {
			p.pos += 1
			decl.admin = parse_record(p) or_return
		}
	case:
		return parse_fail(p, body, EXPECTED_DECLARATION)
	}
	add_decl(p, decl)
	return true
}

add_decl :: proc(p: ^Parser, decl: Decl) {
	decl := decl
	decl.span = {decl.name.start, p.tokens[p.pos - 1].span.end}
	append(&p.file.decls, decl)
}

parse_fail_in :: proc(p: ^Parser, open: Token, message: string) -> bool {
	if peek(p).kind == .End {
		return parse_fail(p, open, UNCLOSED_BRACKET)
	}
	return parse_fail(p, peek(p), message)
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

duplicate_message :: proc(part: Body_Part) -> string {
	switch part {
	case .Admin:
		return DUPLICATE_ADMIN
	case .Fields:
		return DUPLICATE_FIELDS
	case .Props:
		return DUPLICATE_PROPS
	}
	return ""
}

parse_body :: proc(p: ^Parser, decl: ^Decl) -> bool {
	open := peek(p)
	if open.kind != .Open_Brace {
		return parse_fail(p, open, EXPECTED_OPEN_BRACE)
	}
	p.pos += 1
	seen: bit_set[Body_Part]
	skip_newlines(p)
	for peek(p).kind != .Close_Brace {
		if peek(p).kind == .End {
			return parse_fail(p, open, UNCLOSED_BRACKET)
		}
		parse_body_part(p, decl, &seen) or_return
		if skip_newlines(p) == 0 && peek(p).kind != .Close_Brace {
			return parse_fail_in(p, open, EXPECTED_PART_END)
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
		return parse_fail(p, token, EXPECTED_BODY_PART)
	}
	if part in seen {
		return parse_fail(p, token, duplicate_message(part))
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
		return {}, parse_fail(p, open, EXPECTED_OPEN_BRACE)
	}
	p.pos += 1
	first := len(p.file.fields)
	skip_newlines(p)
	for peek(p).kind != .Close_Brace {
		if peek(p).kind == .End {
			return {}, parse_fail(p, open, UNCLOSED_BRACKET)
		}
		parse_field(p) or_return
		if skip_separators(p) == 0 && peek(p).kind != .Close_Brace {
			return {}, parse_fail_in(p, open, EXPECTED_SEPARATOR)
		}
	}
	p.pos += 1
	return Range{u32(first), u32(len(p.file.fields) - first)}, true
}

parse_field :: proc(p: ^Parser) -> bool {
	name := peek(p)
	if name.kind != .Name {
		return parse_fail(p, name, EXPECTED_NAME)
	}
	p.pos += 1
	if peek(p).kind != .Colon {
		return parse_fail(p, peek(p), EXPECTED_COLON)
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
