package main

import "core:testing"

@(test)
version_is_not_empty :: proc(t: ^testing.T) {
	testing.expect(t, len(version()) > 0)
}
