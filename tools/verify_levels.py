#!/usr/bin/env python3
"""BFS solvability check for 色塊出清 levels (mirrors BoardModel.gd contact-clear rules)."""
from __future__ import annotations

import json
import os
import sys
from collections import deque
from copy import deepcopy
from typing import Any, Dict, List, Optional, Tuple

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LEVEL_DIR = os.path.join(ROOT, "levels")

SIDES = {
    "top": (0, -1),
    "bottom": (0, 1),
    "left": (-1, 0),
    "right": (1, 0),
}


def norm_hex(h: str) -> str:
    s = h.strip().upper()
    if not s.startswith("#"):
        s = "#" + s
    return s


class Board:
    def __init__(self, data: Dict[str, Any]):
        self.w = int(data.get("width", 7))
        self.h = int(data.get("height", 7))
        self.goal = data.get("goal", {"type": "clear_all"})
        self.walls = set()
        for w in data.get("walls", []):
            self.walls.add((int(w["x"]), int(w["y"])))
        self.cross = set()
        self.has_cross = False
        self.cross_col = self.w // 2
        self.cross_row = self.h // 2
        xc = None
        if "yellow_cross" in data:
            xc = data["yellow_cross"]
        elif "cross" in data:
            xc = data["cross"]
        self._parse_cross(xc)
        self.pieces: Dict[int, Dict[str, Any]] = {}
        for p in data.get("pieces", []):
            pid = int(p["id"])
            cells = [(int(c["x"]), int(c["y"])) for c in p.get("cells", [])]
            hx = norm_hex(str(p.get("color", "#FF6B9D")))
            self.pieces[pid] = {"id": pid, "color_hex": hx, "cells": cells}
        self.arrows = []
        for a in data.get("edge_arrows", data.get("arrows", [])):
            self.arrows.append(
                {
                    "side": str(a.get("side", "top")),
                    "index": int(a.get("index", 0)),
                    "color_hex": norm_hex(str(a.get("color", "#FFFFFF"))),
                    "dir": str(a.get("dir", "out")),
                }
            )
        # Level-start contact clear
        self.try_auto_clear()

    def _parse_cross(self, xc: Any) -> None:
        self.cross.clear()
        self.has_cross = False
        if xc is None:
            return
        if isinstance(xc, bool):
            if not xc:
                return
            self._build_plus(self.cross_col, self.cross_row)
            return
        if isinstance(xc, dict):
            if not xc:
                return
            if xc.get("enabled", True) is False:
                return
            self.cross_col = int(xc.get("cx", xc.get("col", self.cross_col)))
            self.cross_row = int(xc.get("cy", xc.get("row", self.cross_row)))
            mode = str(xc.get("type", ""))
            want_plus = mode == "plus" or any(
                k in xc for k in ("col", "cx", "row", "cy")
            )
            if want_plus:
                self._build_plus(self.cross_col, self.cross_row)
            for c in xc.get("cells", []):
                self.cross.add((int(c["x"]), int(c["y"])))
                self.has_cross = True
            return
        if isinstance(xc, list):
            for c in xc:
                self.cross.add((int(c["x"]), int(c["y"])))
                self.has_cross = True

    def _build_plus(self, col: int, row: int) -> None:
        for x in range(self.w):
            self.cross.add((x, row))
        for y in range(self.h):
            self.cross.add((col, y))
        self.has_cross = True

    def in_bounds(self, x: int, y: int) -> bool:
        return 0 <= x < self.w and 0 <= y < self.h

    def is_wall(self, x: int, y: int) -> bool:
        return (x, y) in self.walls

    def is_cross(self, x: int, y: int) -> bool:
        return (x, y) in self.cross

    def occupancy(self) -> Dict[Tuple[int, int], int]:
        occ = {}
        for pid, p in self.pieces.items():
            for x, y in p["cells"]:
                if self.in_bounds(x, y):
                    occ[(x, y)] = pid
        return occ

    def piece_at(self, x: int, y: int) -> Optional[int]:
        return self.occupancy().get((x, y))

    def gate_cell(self, side: str, index: int) -> Tuple[int, int]:
        if side == "top":
            return (index, 0)
        if side == "bottom":
            return (index, self.h - 1)
        if side == "left":
            return (0, index)
        if side == "right":
            return (self.w - 1, index)
        return (-1, -1)

    def try_auto_clear(self) -> List[int]:
        """Clear pieces that occupy a same-color arrow gate cell."""
        to_erase = []
        seen = set()
        for a in self.arrows:
            gx, gy = self.gate_cell(a["side"], a["index"])
            if not self.in_bounds(gx, gy):
                continue
            pid = self.piece_at(gx, gy)
            if pid is None or pid in seen:
                continue
            if pid not in self.pieces:
                continue
            if self.pieces[pid]["color_hex"] != a["color_hex"]:
                continue
            seen.add(pid)
            to_erase.append(pid)
        for pid in to_erase:
            del self.pieces[pid]
        return to_erase

    def can_step(self, pid: int, d: Tuple[int, int]) -> bool:
        if pid not in self.pieces:
            return False
        occ = self.occupancy()
        for x, y in self.pieces[pid]["cells"]:
            nx, ny = x + d[0], y + d[1]
            if not self.in_bounds(nx, ny):
                return False
            if self.is_wall(nx, ny):
                return False
            other = occ.get((nx, ny))
            if other is not None and other != pid:
                return False
        return True

    def apply_step(self, pid: int, d: Tuple[int, int]) -> None:
        self.pieces[pid]["cells"] = [
            (x + d[0], y + d[1]) for x, y in self.pieces[pid]["cells"]
        ]

    def try_swipe(self, pid: int, d: Tuple[int, int]) -> bool:
        if d == (0, 0) or pid not in self.pieces:
            return False
        if not self.can_step(pid, d):
            return False
        steps = 0
        while pid in self.pieces and self.can_step(pid, d):
            self.apply_step(pid, d)
            steps += 1
            cleared = self.try_auto_clear()
            if pid in cleared or pid not in self.pieces:
                break
            if steps > self.w + self.h + 2:
                break
        return steps > 0

    def quadrant_of(self, cell: Tuple[int, int]) -> str:
        if not self.has_cross:
            return ""
        x, y = cell
        if self.is_cross(x, y):
            return ""
        if x < self.cross_col and y < self.cross_row:
            return "tl"
        if x > self.cross_col and y < self.cross_row:
            return "tr"
        if x < self.cross_col and y > self.cross_row:
            return "bl"
        if x > self.cross_col and y > self.cross_row:
            return "br"
        return ""

    def sort_ok(self, mapping: Dict[str, Any]) -> bool:
        if not self.has_cross:
            return False
        qcols = {"tl": set(), "tr": set(), "bl": set(), "br": set()}
        for p in self.pieces.values():
            hx = p["color_hex"]
            for cell in p["cells"]:
                if self.is_cross(*cell):
                    return False
                q = self.quadrant_of(cell)
                if q == "":
                    return False
                qcols[q].add(hx)
        for q, colors in qcols.items():
            if len(colors) > 1:
                return False
            if q in mapping:
                want = norm_hex(str(mapping[q]))
                if not colors or want not in colors:
                    return False
        return True

    def check_win(self) -> bool:
        t = str(self.goal.get("type", "clear_all"))
        if t == "clear_all":
            return len(self.pieces) == 0
        if t == "clear_color":
            want = norm_hex(str(self.goal.get("color", "")))
            return all(p["color_hex"] != want for p in self.pieces.values())
        if t == "reach_cross":
            want = norm_hex(str(self.goal.get("color", "")))
            for p in self.pieces.values():
                if want not in ("#", "") and p["color_hex"] != want:
                    continue
                for cell in p["cells"]:
                    if self.is_cross(*cell):
                        return True
            return False
        if t == "sort_quadrants":
            return self.sort_ok(self.goal.get("quadrants", {}) or {})
        if t == "combined":
            for col in self.goal.get("clear_colors", []):
                want = norm_hex(str(col))
                if any(p["color_hex"] == want for p in self.pieces.values()):
                    return False
            sq = self.goal.get("sort_quadrants", {})
            if isinstance(sq, dict) and sq:
                return self.sort_ok(sq)
            return True
        return False

    def state_key(self) -> Tuple:
        items = []
        for pid in sorted(self.pieces.keys()):
            cells = tuple(sorted(self.pieces[pid]["cells"]))
            items.append((pid, self.pieces[pid]["color_hex"], cells))
        return tuple(items)

    def clone(self) -> "Board":
        return deepcopy(self)


def all_moves(board: Board) -> List[Tuple[str, Any]]:
    moves = []
    for pid in list(board.pieces.keys()):
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            moves.append(("swipe", (pid, d)))
    return moves


def apply_move(board: Board, move: Tuple[str, Any]) -> bool:
    kind, payload = move
    if kind != "swipe":
        return False
    pid, d = payload
    if pid not in board.pieces:
        return False
    return board.try_swipe(pid, d)


def solve(data: Dict[str, Any], limit: int = 200000) -> Optional[List[str]]:
    start = Board(data)
    if start.check_win():
        return []
    q = deque()
    q.append((start, []))
    seen = {start.state_key()}
    while q:
        if len(seen) > limit:
            return None
        board, path = q.popleft()
        for move in all_moves(board):
            nxt = board.clone()
            if not apply_move(nxt, move):
                continue
            key = nxt.state_key()
            if key in seen:
                continue
            kind, payload = move
            pid, d = payload
            desc = f"swipe({pid},{d})"
            npath = path + [desc]
            if nxt.check_win():
                return npath
            seen.add(key)
            q.append((nxt, npath))
    return None


def main() -> int:
    files = sorted(
        f for f in os.listdir(LEVEL_DIR) if f.startswith("level_") and f.endswith(".json")
    )
    if not files:
        print("No levels found")
        return 1
    ok_all = True
    for f in files:
        path = os.path.join(LEVEL_DIR, f)
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        xc = data.get("yellow_cross", data.get("cross", None))
        has_cross = False
        if isinstance(xc, dict) and xc:
            has_cross = True
        elif isinstance(xc, list) and xc:
            has_cross = True
        elif xc is True:
            has_cross = True
        sol = solve(data)
        cross_tag = "cross=yes" if has_cross else "cross=no"
        if sol is None:
            print(f"FAIL {f} ({cross_tag}): unsolvable (or BFS limit)")
            ok_all = False
        else:
            print(f"OK   {f} ({cross_tag}): {len(sol)} moves -> {sol}")
    return 0 if ok_all else 2


if __name__ == "__main__":
    sys.exit(main())
