package vega

Span :: struct {
	start, end: u32,
}

Qualified_Name :: struct {
	prefix, name: Span,
}

Range :: struct {
	first, count: u32,
}

Decl_Id :: distinct u32
Field_Id :: distinct u32
Type_Id :: distinct u32
Expr_Id :: distinct u32
Part_Id :: distinct u32

Decl_Kind :: enum u8 {
	Component,
	Content,
	Alias,
	Locale,
}

Decl :: struct {
	kind:    Decl_Kind,
	name:    Span,
	span:    Span,
	admin:   Range,
	fields:  Range,
	props:   Range,
	type:    Type_Id,
	entries: Range,
}

Field :: struct {
	name:     Span,
	span:     Span,
	type:     Type_Id,
	is_slot:  bool,
	optional: bool,
	default:  Expr_Id,
	admin:    Range,
}

Type_Kind :: enum u8 {
	Named,
	Literal,
	Union,
}

Type :: struct {
	kind:    Type_Kind,
	span:    Span,
	name:    Qualified_Name,
	limits:  Range,
	members: Range,
}

Entry :: struct {
	key:   Span,
	span:  Span,
	value: Expr_Id,
	type:  Type_Id,
}

Expr_Kind :: enum u8 {
	Path,
	Call,
	Pipe,
	Not,
	Compare,
	Coalesce,
	And,
	Or,
	Arith,
	Negate,
	String,
	Int,
	Decimal,
	Bool,
	Null,
	Host_Value,
	List,
	Record,
	Component_Value,
}

Expr :: struct {
	kind:        Expr_Kind,
	span:        Span,
	name:        Qualified_Name,
	op:          Token_Kind,
	left, right: Expr_Id,
	items:       Range,
}

Part_Kind :: enum u8 {
	Html,
	Value,
	If,
	Elif,
	Else,
	End_If,
	For,
	End_For,
	Slot,
	Render,
}

Html_Position :: enum u8 {
	Text,
	Start_Tag,
	Attribute_Value,
}

Part :: struct {
	kind:        Part_Kind,
	span:        Span,
	position:    Html_Position,
	expr:        Expr_Id,
	item, index: Span,
	name:        Qualified_Name,
	entries:     Range,
	closes:      Part_Id,
}

File :: struct {
	path, src:  string,
	uses:       [dynamic]Span,
	templates:  [dynamic]Span,
	template:   Span,
	decls:      [dynamic]Decl,
	fields:     [dynamic]Field,
	types:      [dynamic]Type,
	entries:    [dynamic]Entry,
	exprs:      [dynamic]Expr,
	expr_items: [dynamic]Expr_Id,
	segments:   [dynamic]Span,
	parts:      [dynamic]Part,
	errors:     [dynamic]Error,
}
