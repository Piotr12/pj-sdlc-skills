#!/usr/bin/env python3
"""Fail if a Mermaid erDiagram in a Markdown file has more than MAX_ENTITIES entities."""
import pathlib
import re
import sys

MAX_ENTITIES = 9
BLOCK = re.compile(r"```mermaid\n(.*?)```", re.S)
ENTITY = re.compile(r'^\s*"?([\w-]+)"?\s*(?:\[[^\]]*\])?\s*\{', re.M)
RELATION = re.compile(r'^\s*"?([\w-]+)"?\s+\S*(?:--|\.\.)\S*\s+"?([\w-]+)', re.M)


def entities(block: str) -> set[str]:
    found = set(ENTITY.findall(block))
    for left, right in RELATION.findall(block):
        found |= {left, right}
    return found


def main(paths: list[str]) -> int:
    failed = False
    for path in paths:
        for block in BLOCK.findall(pathlib.Path(path).read_text()):
            if not block.lstrip().startswith("erDiagram"):
                continue
            count = len(entities(block))
            if count > MAX_ENTITIES:
                print(f"{path}: erDiagram has {count} entities, max {MAX_ENTITIES}")
                failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
