package main

import "core:fmt"
import "core:strings"

VERSION :: #load("../VERSION", string)

version :: proc() -> string {
	return strings.trim_space(VERSION)
}

main :: proc() {
	fmt.println("vegabase", version())
}
