package vega

Span :: struct {
	start, end: u32,
}

Error :: struct {
	span:    Span,
	message: string,
	hint:    string,
}
