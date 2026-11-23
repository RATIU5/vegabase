package vega

import "core:unicode/utf8"

UNEXPECTED_CHARACTER :: "unexpected character"

Token_Kind :: enum u8 {
	Invalid,
	End,
	Newline,
	Name,
	Type,
	String,
	Int,
	Host_Value,
	Of,
	Use,
	Template,
	Component,
	Content,
	Fields,
	Props,
	Locale,
	Slot,
	Render,
	If,
	Elif,
	Else,
	For,
	In,
	Not,
	And,
	Or,
	True,
	False,
	Null,
	End_If,
	End_For,
	Open_Brace,
	Close_Brace,
	Open_Bracket,
	Close_Bracket,
	Open_Paren,
	Close_Paren,
	Comma,
	Dot,
	Colon,
	Colon_Colon,
	Equal,
	At,
	Pipe,
	Question,
	Question_Question,
	Equal_Equal,
	Not_Equal,
	Less,
	Less_Equal,
	Greater,
	Greater_Equal,
}

Token :: struct {
	kind: Token_Kind,
	span: Span,
}

is_lower :: proc(c: u8) -> bool {
	return c >= 'a' && c <= 'z'
}

is_upper :: proc(c: u8) -> bool {
	return c >= 'A' && c <= 'Z'
}

is_digit :: proc(c: u8) -> bool {
	return c >= '0' && c <= '9'
}

is_alnum :: proc(c: u8) -> bool {
	return is_lower(c) || is_upper(c) || is_digit(c)
}

is_word :: proc(c: u8) -> bool {
	return is_alnum(c) || c == '_'
}

reserved_kind :: proc(word: string) -> Token_Kind {
	switch word {
	case "of":
		return .Of
	case "use":
		return .Use
	case "template":
		return .Template
	case "component":
		return .Component
	case "content":
		return .Content
	case "fields":
		return .Fields
	case "props":
		return .Props
	case "locale":
		return .Locale
	case "slot":
		return .Slot
	case "render":
		return .Render
	case "if":
		return .If
	case "elif":
		return .Elif
	case "else":
		return .Else
	case "for":
		return .For
	case "in":
		return .In
	case "not":
		return .Not
	case "and":
		return .And
	case "or":
		return .Or
	case "true":
		return .True
	case "false":
		return .False
	case "null":
		return .Null
	}
	return .Name
}

lex_string :: proc(s: string, start: int, errors: ^[dynamic]Error) -> (next: int, ok: bool) {
	i := start + 1
	for i < len(s) {
		c := s[i]
		switch {
		case c == '"':
			return i + 1, true
		case c == '\n':
			return 0, fail(errors, start, start + 1, STRING_NEVER_CLOSED)
		case c == '\\':
			if i + 1 >= len(s) {
				return 0, fail(errors, start, start + 1, STRING_NEVER_CLOSED)
			}
			escaped := s[i + 1]
			if escaped == '"' || escaped == '\\' {
				i += 2
				continue
			}
			width := 1
			if escaped >= 0x80 {
				_, width = utf8.decode_rune_in_string(s[i + 1:])
			}
			return 0, fail(errors, i, i + 1 + width, "unknown escape in string")
		case c >= 0x80:
			r, width := utf8.decode_rune_in_string(s[i:])
			if r == utf8.RUNE_ERROR && width == 1 {
				return 0, fail(errors, i, i + 1, "string is not valid UTF-8")
			}
			i += width
		case:
			i += 1
		}
	}
	return 0, fail(errors, start, start + 1, STRING_NEVER_CLOSED)
}

lex_int :: proc(s: string, start: int, errors: ^[dynamic]Error) -> (next: int, ok: bool) {
	i := start
	if s[i] == '-' {
		i += 1
	}
	for i < len(s) && is_digit(s[i]) {
		i += 1
	}
	if i + 1 < len(s) && s[i] == '.' && is_digit(s[i + 1]) {
		i += 1
		for i < len(s) && is_digit(s[i]) {
			i += 1
		}
		return 0, fail(errors, start, i, "decimal numbers are not supported")
	}
	return i, true
}

lex_host_value :: proc(s: string, start: int) -> int {
	i := start + 1
	for {
		for i < len(s) && is_word(s[i]) {
			i += 1
		}
		if i + 1 < len(s) && s[i] == '.' && is_lower(s[i + 1]) {
			i += 1
			continue
		}
		return i
	}
}

lex_punct :: proc(s: string, i: int) -> (kind: Token_Kind, width: int) {
	next: u8
	if i + 1 < len(s) {
		next = s[i + 1]
	}
	switch s[i] {
	case '{':
		return .Open_Brace, 1
	case '}':
		return .Close_Brace, 1
	case '[':
		return .Open_Bracket, 1
	case ']':
		return .Close_Bracket, 1
	case '(':
		return .Open_Paren, 1
	case ')':
		return .Close_Paren, 1
	case ',':
		return .Comma, 1
	case '.':
		return .Dot, 1
	case '@':
		return .At, 1
	case '|':
		return .Pipe, 1
	case ':':
		if next == ':' {
			return .Colon_Colon, 2
		}
		return .Colon, 1
	case '=':
		if next == '=' {
			return .Equal_Equal, 2
		}
		return .Equal, 1
	case '!':
		if next == '=' {
			return .Not_Equal, 2
		}
		return .Invalid, 1
	case '<':
		if next == '=' {
			return .Less_Equal, 2
		}
		return .Less, 1
	case '>':
		if next == '=' {
			return .Greater_Equal, 2
		}
		return .Greater, 1
	case '?':
		if next == '?' {
			return .Question_Question, 2
		}
		return .Question, 1
	}
	return .Invalid, 1
}

lex :: proc(
	src: string,
	code: Span,
	tokens: ^[dynamic]Token,
	errors: ^[dynamic]Error,
) -> (
	ok: bool,
) {
	s := src[:code.end]
	end := int(code.end)
	i := int(code.start)
	prev := Token_Kind.Invalid

	for i < end {
		start := i
		c := s[i]
		kind: Token_Kind

		switch c {
		case ' ', '\t':
			i += 1
			continue
		case '\n':
			i += 1
			kind = .Newline
		case '\r':
			if i + 1 < end && s[i + 1] == '\n' {
				i += 2
				kind = .Newline
			} else {
				return fail(errors, i, i + 1, UNEXPECTED_CHARACTER)
			}
		case '#':
			for i < end && s[i] != '\n' {
				i += 1
			}
			continue
		case 'a' ..= 'z':
			i += 1
			for i < end && is_word(s[i]) {
				i += 1
			}
			kind = .Name if prev == .Dot else reserved_kind(s[start:i])
		case 'A' ..= 'Z':
			i += 1
			for i < end && is_alnum(s[i]) {
				i += 1
			}
			kind = .Type
		case '0' ..= '9', '-':
			if c == '-' && (i + 1 >= end || !is_digit(s[i + 1])) {
				return fail(errors, i, i + 1, UNEXPECTED_CHARACTER)
			}
			next, int_ok := lex_int(s, i, errors)
			if !int_ok {
				return false
			}
			i = next
			kind = .Int
		case '"':
			next, string_ok := lex_string(s, i, errors)
			if !string_ok {
				return false
			}
			i = next
			kind = .String
		case '$':
			if i + 1 < end && is_lower(s[i + 1]) {
				i = lex_host_value(s, i)
				kind = .Host_Value
			} else {
				return fail(errors, i, i + 1, UNEXPECTED_CHARACTER)
			}
		case '/':
			word_end := i + 1
			for word_end < end && is_word(s[word_end]) {
				word_end += 1
			}
			switch s[i + 1:word_end] {
			case "if":
				kind = .End_If
			case "for":
				kind = .End_For
			case:
				return fail(errors, i, i + 1, UNEXPECTED_CHARACTER)
			}
			i = word_end
		case:
			punct, punct_width := lex_punct(s, i)
			if punct != .Invalid {
				i += punct_width
				kind = punct
			} else {
				width := 1
				if c >= 0x80 {
					_, width = utf8.decode_rune_in_string(s[i:])
				}
				return fail(errors, i, i + width, UNEXPECTED_CHARACTER)
			}
		}

		append(tokens, Token{kind = kind, span = {u32(start), u32(i)}})
		prev = kind
	}

	append(tokens, Token{kind = .End, span = {code.end, code.end}})
	return true
}
