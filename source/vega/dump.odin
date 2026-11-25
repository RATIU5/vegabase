package vega

import "core:fmt"
import "core:reflect"
import "core:strings"

write_quoted :: proc(b: ^strings.Builder, text: string) {
	strings.write_byte(b, '"')
	for i in 0 ..< len(text) {
		c := text[i]
		switch c {
		case '"':
			strings.write_string(b, `\"`)
		case '\\':
			strings.write_string(b, `\\`)
		case '\n':
			strings.write_string(b, `\n`)
		case '\r':
			strings.write_string(b, `\r`)
		case '\t':
			strings.write_string(b, `\t`)
		case 0 ..< 0x20:
			fmt.sbprintf(b, `\u%04x`, c)
		case:
			strings.write_byte(b, c)
		}
	}
	strings.write_byte(b, '"')
}

write_head :: proc(b: ^strings.Builder, starts: []u32, label: string, span: Span) {
	line, col := line_col(starts, span.start)
	fmt.sbprintf(b, "%s@%d..%d %d:%d", label, span.start, span.end, line, col)
}

write_error :: proc(b: ^strings.Builder, starts: []u32, err: Error) {
	write_head(b, starts, "Error", err.span)
	strings.write_byte(b, ' ')
	write_quoted(b, ERROR_MESSAGES[err.code])
	strings.write_byte(b, '\n')
}

dump_tokens :: proc(src: string, allocator := context.allocator) -> string {
	blocks := make([dynamic]Block, allocator)
	defer delete(blocks)
	tokens := make([dynamic]Token, allocator)
	defer delete(tokens)
	errors := make([dynamic]Error, allocator)
	defer delete(errors)

	b := strings.builder_make(allocator)
	starts := line_starts(src, allocator)
	defer delete(starts, allocator)

	scanned := scan(src, &blocks, &errors)
	for block in blocks {
		clear(&tokens)
		lexed := lex(src, block.code, &tokens, &errors)
		write_head(&b, starts, "Block", block.span)
		strings.write_byte(&b, '\n')
		for token in tokens {
			strings.write_string(&b, "  ")
			write_head(&b, starts, reflect.enum_string(token.kind), token.span)
			strings.write_byte(&b, ' ')
			write_quoted(&b, src[token.span.start:token.span.end])
			strings.write_byte(&b, '\n')
		}
		if !lexed {
			write_error(&b, starts, errors[len(errors) - 1])
			return strings.to_string(b)
		}
	}
	if !scanned {
		write_error(&b, starts, errors[len(errors) - 1])
	}
	return strings.to_string(b)
}

write_node :: proc(
	b: ^strings.Builder,
	file: ^File,
	starts: []u32,
	depth: int,
	label: string,
	span: Span,
	with_text := true,
) {
	for _ in 0 ..< depth {
		strings.write_string(b, "  ")
	}
	write_head(b, starts, label, span)
	if with_text {
		strings.write_byte(b, ' ')
		write_quoted(b, file.src[span.start:span.end])
	}
	strings.write_byte(b, '\n')
}

op_text :: proc(kind: Token_Kind) -> string {
	#partial switch kind {
	case .Equal_Equal:
		return "=="
	case .Not_Equal:
		return "!="
	case .Less:
		return "<"
	case .Less_Equal:
		return "<="
	case .Greater:
		return ">"
	case .Greater_Equal:
		return ">="
	case .Plus:
		return "+"
	case .Minus:
		return "-"
	case .Star:
		return "*"
	case .Slash:
		return "/"
	case .Percent:
		return "%"
	case .Question_Question:
		return "??"
	case .And:
		return "and"
	case .Or:
		return "or"
	}
	return ""
}

write_expr :: proc(b: ^strings.Builder, file: ^File, starts: []u32, depth: int, id: Expr_Id) {
	if id == 0 {
		return
	}
	e := file.exprs[id]
	buf: [32]u8
	label := reflect.enum_string(e.kind)
	if e.op != .Invalid {
		label = fmt.bprintf(buf[:], "%s(%s)", label, op_text(e.op))
	}
	write_node(b, file, starts, depth, label, e.span)
	switch e.kind {
	case .Not, .Negate:
		write_expr(b, file, starts, depth + 1, e.left)
	case .Pipe, .Compare, .Coalesce, .And, .Or, .Arith:
		write_expr(b, file, starts, depth + 1, e.left)
		write_expr(b, file, starts, depth + 1, e.right)
	case .Call:
		write_qualified(b, file, starts, depth + 1, e.name)
		write_items(b, file, starts, depth + 1, e.items)
	case .List:
		write_items(b, file, starts, depth + 1, e.items)
	case .Record:
		write_entries(b, file, starts, depth + 1, "Entries", e.items)
	case .Component_Value:
		write_qualified(b, file, starts, depth + 1, e.name)
		write_entries(b, file, starts, depth + 1, "Entries", e.items)
	case .Path:
		if e.items.count > 1 {
			for span in file.segments[e.items.first:][:e.items.count] {
				write_node(b, file, starts, depth + 1, "Name", span)
			}
		}
	case .String, .Int, .Decimal, .Bool, .Null, .Host_Value:
	}
}

write_items :: proc(b: ^strings.Builder, file: ^File, starts: []u32, depth: int, range: Range) {
	for id in file.expr_items[range.first:][:range.count] {
		write_expr(b, file, starts, depth, id)
	}
}

write_entries :: proc(
	b: ^strings.Builder,
	file: ^File,
	starts: []u32,
	depth: int,
	label: string,
	range: Range,
) {
	if range.count == 0 {
		return
	}
	entries := file.entries[range.first:][:range.count]
	span := Span{entries[0].span.start, entries[len(entries) - 1].span.end}
	write_node(b, file, starts, depth, label, span, false)
	for entry in entries {
		write_node(b, file, starts, depth + 1, "Entry", entry.span, false)
		write_node(b, file, starts, depth + 2, "Key", entry.key)
		if entry.type != 0 {
			write_type(b, file, starts, depth + 2, entry.type)
		}
		write_expr(b, file, starts, depth + 2, entry.value)
	}
}

write_qualified :: proc(
	b: ^strings.Builder,
	file: ^File,
	starts: []u32,
	depth: int,
	name: Qualified_Name,
) {
	if name.prefix != {} {
		write_node(b, file, starts, depth, "Prefix", name.prefix)
	}
	write_node(b, file, starts, depth, "Name", name.name)
}

write_type :: proc(b: ^strings.Builder, file: ^File, starts: []u32, depth: int, id: Type_Id) {
	t := file.types[id]
	write_node(b, file, starts, depth, reflect.enum_string(t.kind), t.span)
	switch t.kind {
	case .Named:
		write_qualified(b, file, starts, depth + 1, t.name)
	case .Literal:
	case .Union:
		for i in 0 ..< t.members.count {
			write_type(b, file, starts, depth + 1, Type_Id(t.members.first + i))
		}
	}
	write_entries(b, file, starts, depth + 1, "Limits", t.limits)
}

field_label :: proc(field: Field) -> string {
	switch {
	case field.is_slot && field.optional:
		return "Field(slot,optional)"
	case field.is_slot:
		return "Field(slot)"
	case field.optional:
		return "Field(optional)"
	}
	return "Field"
}

write_fields :: proc(
	b: ^strings.Builder,
	file: ^File,
	starts: []u32,
	depth: int,
	label: string,
	range: Range,
) {
	if range.count == 0 {
		return
	}
	fields := file.fields[range.first:][:range.count]
	span := Span{fields[0].span.start, fields[len(fields) - 1].span.end}
	write_node(b, file, starts, depth, label, span, false)
	for field in fields {
		write_node(b, file, starts, depth + 1, field_label(field), field.span, false)
		write_node(b, file, starts, depth + 2, "Name", field.name)
		write_type(b, file, starts, depth + 2, field.type)
		write_expr(b, file, starts, depth + 2, field.default)
		write_entries(b, file, starts, depth + 2, "Admin", field.admin)
	}
}

write_decl :: proc(b: ^strings.Builder, file: ^File, starts: []u32, decl: Decl) {
	write_node(b, file, starts, 1, reflect.enum_string(decl.kind), decl.span, false)
	write_node(b, file, starts, 2, "Name", decl.name)
	write_entries(b, file, starts, 2, "Admin", decl.admin)
	write_fields(b, file, starts, 2, "Fields", decl.fields)
	write_fields(b, file, starts, 2, "Props", decl.props)
	if decl.type != 0 {
		write_type(b, file, starts, 2, decl.type)
	}
	write_entries(b, file, starts, 2, "Entries", decl.entries)
}

dump_tree :: proc(file: ^File, allocator := context.allocator) -> string {
	b := strings.builder_make(allocator)
	starts := line_starts(file.src, allocator)
	defer delete(starts, allocator)

	write_node(&b, file, starts, 0, "File", {0, u32(len(file.src))}, false)
	for use in file.uses {
		write_node(&b, file, starts, 1, "Use", use)
	}
	for template in file.templates {
		write_node(&b, file, starts, 1, "Template_Type", template)
	}
	for decl in file.decls[1:] {
		write_decl(&b, file, starts, decl)
	}
	if len(file.errors) > 0 {
		write_error(&b, starts, file.errors[len(file.errors) - 1])
	} else {
		for part in file.parts[1:] {
			write_node(
				&b,
				file,
				starts,
				1,
				reflect.enum_string(part.kind),
				part.span,
				part.kind == .Html,
			)
			if part.kind == .For {
				write_node(&b, file, starts, 2, "Item", part.item)
				if part.index != {} {
					write_node(&b, file, starts, 2, "Index", part.index)
				}
			}
			if part.kind == .Slot || part.kind == .Render {
				write_qualified(&b, file, starts, 2, part.name)
				write_entries(&b, file, starts, 2, "Entries", part.entries)
			}
			write_expr(&b, file, starts, 2, part.expr)
			if part.closes != 0 {
				write_node(&b, file, starts, 2, "Closes", file.parts[part.closes].span, false)
			}
		}
	}
	return strings.to_string(b)
}
