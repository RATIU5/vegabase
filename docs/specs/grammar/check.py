import sys
from pathlib import Path

from lark import Lark
from lark.exceptions import LarkError

HERE = Path(__file__).parent
GRAMMAR = (HERE / "vega.lark").read_text()
FIRST = Lark(GRAMMAR, start="first_block")
INLINE = Lark(GRAMMAR, start="inline")
OPENERS = {"if_tag": "if", "for_tag": "for"}
CLOSERS = {"end_if": "if", "end_for": "for"}


class VegaError(Exception):
    pass


def line_of(src, pos):
    return src.count("\n", 0, pos) + 1


def blocks(src):
    i = 0
    while True:
        start = src.find("{{", i)
        if start < 0:
            return
        j = start + 2
        depth = 0
        while True:
            if j >= len(src):
                raise VegaError("line %d: {{ is never closed" % line_of(src, start))
            c = src[j]
            if c == '"':
                end = j + 1
                while end < len(src) and src[end] not in '"\n':
                    end += 2 if src[end] == "\\" else 1
                if end >= len(src) or src[end] != '"':
                    raise VegaError("line %d: string is never closed" % line_of(src, j))
                j = end + 1
            elif c == "#":
                nl = src.find("\n", j)
                close = src.find("}}", j)
                stops = [x for x in (nl, close) if x >= 0]
                if not stops:
                    raise VegaError("line %d: {{ is never closed" % line_of(src, start))
                j = min(stops)
            elif c == "{":
                depth += 1
                j += 1
            elif c == "}":
                if depth == 0:
                    if src.startswith("}}", j):
                        break
                    raise VegaError("line %d: } with no {" % line_of(src, j))
                depth -= 1
                j += 1
            else:
                j += 1
        yield start, src[start + 2:j]
        i = j + 2


def check(src):
    stack = []
    for n, (start, code) in enumerate(blocks(src)):
        line = line_of(src, start)
        is_first = n == 0 and src[:start].strip() == ""
        try:
            tree = (FIRST if is_first else INLINE).parse(code)
        except LarkError as e:
            where = line + getattr(e, "line", 1) - 1
            raise VegaError("line %d: %s" % (where, str(e).splitlines()[0]))
        if is_first:
            continue
        kind = tree.children[0].data if tree.children else None
        if kind in OPENERS:
            stack.append((OPENERS[kind], line, False))
        elif kind in CLOSERS:
            if not stack or stack[-1][0] != CLOSERS[kind]:
                raise VegaError("line %d: {{/%s}} closes nothing" % (line, CLOSERS[kind]))
            stack.pop()
        elif kind in ("elif_tag", "else_tag"):
            if not stack or stack[-1][0] != "if" or stack[-1][2]:
                raise VegaError("line %d: {{%s}} is not inside an open {{if}}" % (line, kind[:-4]))
            if kind == "else_tag":
                stack[-1] = (stack[-1][0], stack[-1][1], True)
    if stack:
        raise VegaError("line %d: {{%s}} is never closed" % (stack[-1][1], stack[-1][0]))


def run(folder, expect_ok):
    failed = 0
    for f in sorted(folder.glob("*.vega")):
        try:
            check(f.read_text())
            ok, note = True, ""
        except VegaError as e:
            ok, note = False, str(e)
        good = ok == expect_ok
        failed += not good
        print("%s  %-28s %s" % ("ok  " if good else "FAIL", f.name, note if not ok else ("" if expect_ok else "parsed, but must fail")))
    return failed


if __name__ == "__main__":
    print("examples that must parse")
    bad = run(HERE.parent / "examples", True)
    print("edge cases that must parse")
    bad += run(HERE / "good", True)
    print("files that must fail")
    bad += run(HERE / "bad", False)
    sys.exit(1 if bad else 0)
