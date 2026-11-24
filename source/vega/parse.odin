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
BAD_LOCALE_NAME :: "locale name must be a language code such as en or pt_BR"
UNCLOSED_BRACKET :: "bracket is never closed"
MISMATCHED_BRACKET :: "closing bracket does not match"

Parser :: struct {
	file:   ^File,
	tokens: []Token,
	pos:    int,
	open:   [dynamic]u32,
}

parse :: proc(path, src: string, allocator: runtime.Allocator) -> (file: File, ok: bool) {
	file = File {
		path    = path,
		src     = src,
		uses    = make([dynamic]Span, allocator),
		decls   = make([dynamic]Decl, allocator),
		fields  = make([dynamic]Field, allocator),
		types   = make([dynamic]Type, allocator),
		entries = make([dynamic]Entry, allocator),
		exprs   = make([dynamic]Expr, allocator),
		parts   = make([dynamic]Part, allocator),
		errors  = make([dynamic]Error, allocator),
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
		file   = &file,
		tokens = tokens[:],
		open   = make([dynamic]u32, allocator),
	}
	ok = parse_first_block(&p)
	return file, ok
}

parse_fail :: proc(p: ^Parser, token: Token, message: string) -> bool {
	return fail(&p.file.errors, int(token.span.start), int(token.span.end), message)
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
	if !skip_tokens(p, EXPECTED_OPEN_BRACE, false) {
		return false
	}
	add_decl(p, .Locale, name)
	return true
}

parse_declaration :: proc(p: ^Parser) -> bool {
	name := peek(p)
	if peek(p, 1).kind != .Colon_Colon {
		return parse_fail(p, peek(p, 1), EXPECTED_COLON_COLON)
	}
	p.pos += 2
	kind := Decl_Kind.Alias
	body := peek(p)
	#partial switch body.kind {
	case .Component:
		kind = .Component
	case .Content:
		kind = .Content
	case .Type, .String:
	case .Name:
		if peek(p, 1).kind != .Dot || peek(p, 2).kind != .Type {
			return parse_fail(p, body, EXPECTED_DECLARATION)
		}
	case:
		return parse_fail(p, body, EXPECTED_DECLARATION)
	}
	if kind == .Alias {
		if !skip_tokens(p, "", true) {
			return false
		}
	} else {
		p.pos += 1
		if !skip_tokens(p, EXPECTED_OPEN_BRACE, false) {
			return false
		}
	}
	add_decl(p, kind, name)
	return true
}

add_decl :: proc(p: ^Parser, kind: Decl_Kind, name: Token) {
	last := p.tokens[p.pos - 1]
	append(
		&p.file.decls,
		Decl{kind = kind, name = name.span, span = {name.span.start, last.span.end}},
	)
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

skip_tokens :: proc(p: ^Parser, not_open_message: string, to_newline: bool) -> bool {
	if !to_newline && peek(p).kind != .Open_Brace {
		return parse_fail(p, peek(p), not_open_message)
	}
	clear(&p.open)
	for {
		token := peek(p)
		#partial switch token.kind {
		case .Open_Brace, .Open_Bracket, .Open_Paren:
			append(&p.open, u32(p.pos))
		case .Close_Brace, .Close_Bracket, .Close_Paren:
			if len(p.open) == 0 || closer_of(p.tokens[pop(&p.open)].kind) != token.kind {
				return parse_fail(p, token, MISMATCHED_BRACKET)
			}
		case .Newline:
			if to_newline && len(p.open) == 0 {
				return true
			}
		case .End:
			if len(p.open) > 0 {
				return parse_fail(p, p.tokens[p.open[0]], UNCLOSED_BRACKET)
			}
			return true
		}
		p.pos += 1
		if !to_newline && len(p.open) == 0 {
			return true
		}
	}
}
