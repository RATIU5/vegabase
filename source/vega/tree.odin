package vega

Span :: struct {
	start, end: u32,
}

Error :: struct {
	span:    Span,
	message: string,
	hint:    string,
}

STRING_NEVER_CLOSED :: "string is never closed"

fail :: proc(errors: ^[dynamic]Error, start, end: int, message: string) -> bool {
	append(errors, Error{span = {u32(start), u32(end)}, message = message})
	return false
}
