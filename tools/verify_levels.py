#!/usr/bin/env python3
"""BFS solvability check for 色塊出清 levels (mirrors BoardModel.gd rules)."""
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


def cell_key(x: int, y: int) -> str:
    return f"{x},{y}"


class Board:
    def __init__(self, data: Dict[str, Any]):
        self.w = int(data.get("width", 7))
        self.h = int(data.get("height", 7))
        self.goal = data.get("goal", {"type": "clear_all"})
        self.walls = set()
        for w in data.get("walls", []):
            self.walls.add((int(w["x"]), int(w["y"])))
        self.cross = set()
        self.cross_col = self.w // 2
        self.cross_row = self.h // 2
        self._parse_cross(data.get("yellow_cross", data.get("cross", {})))
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

    def _parse_cross(self, xc: Any) -> None:
        if isinstance(xc, dict):
            self.cross_col = int(xc.get("cx", xc.get("col", self.cross_col)))
            self.cross_row = int(xc.get("cy", xc.get("row", self.cross_row)))
            for x in range(self.w):
                self.cross.add((x, self.cross_row))
            for y in range(self.h):
                self.cross.add((self.cross_col, y))
            for c in xc.get("cells", []):
                self.cross.add((int(c["x"]), int(c["y"])))
        elif isinstance(xc, list):
            for c in xc:
                self.cross.add((int(c["x"]), int(c["y"])))
        else:
            for x in range(self.w):
                self.cross.add((x, self.cross_row))
            for y in range(self.h):
                self.cross.add((self.cross_col, y))

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

    def has_gate(self, side: str, index: int, color_hex: str) -> bool:
        want = norm_hex(color_hex)
        for a in self.arrows:
            if a["side"] == side and a["index"] == index and a["color_hex"] == want:
                return True
        return False

    def side_dir(self, side: str) -> Tuple[int, int]:
        return SIDES[side]

    def exit_side(self, dx: int, dy: int) -> str:
        if dy < 0:
            return "top"
        if dy > 0:
            return "bottom"
        if dx < 0:
            return "left"
        return "right"

    def cell_exit_valid(self, cell: Tuple[int, int], d: Tuple[int, int], color_hex: str) -> bool:
        nx, ny = cell[0] + d[0], cell[1] + d[1]
        if self.in_bounds(nx, ny):
            return True
        side = self.exit_side(d[0], d[1])
        idx = cell[0] if side in ("top", "bottom") else cell[1]
        return self.has_gate(side, idx, color_hex)

    def can_step(self, pid: int, d: Tuple[int, int]) -> bool:
        if pid not in self.pieces:
            return False
        p = self.pieces[pid]
        occ = self.occupancy()
        hx = p["color_hex"]
        for x, y in p["cells"]:
            nx, ny = x + d[0], y + d[1]
            if self.in_bounds(nx, ny):
                if self.is_wall(nx, ny):
                    return False
                other = occ.get((nx, ny))
                if other is not None and other != pid:
                    return False
            else:
                if not self.cell_exit_valid((x, y), d, hx):
                    return False
        return True

    def would_eject(self, pid: int, d: Tuple[int, int]) -> bool:
        for x, y in self.pieces[pid]["cells"]:
            if not self.in_bounds(x + d[0], y + d[1]):
                return True
        return False

    def apply_step(self, pid: int, d: Tuple[int, int]) -> None:
        self.pieces[pid]["cells"] = [
            (x + d[0], y + d[1]) for x, y in self.pieces[pid]["cells"]
        ]

    def slide(self, pid: int, d: Tuple[int, int]) -> bool:
        if not self.can_step(pid, d):
            return False
        steps = 0
        while self.can_step(pid, d):
            if self.would_eject(pid, d):
                del self.pieces[pid]
                return True
            self.apply_step(pid, d)
            steps += 1
            if steps > self.w + self.h + 2:
                break
        return steps > 0

    def on_track(self, cell: Tuple[int, int], arrow: Dict[str, Any]) -> bool:
        side = arrow["side"]
        idx = arrow["index"]
        if side in ("top", "bottom"):
            return cell[0] == idx
        return cell[1] == idx

    def dist_to_gate(self, cell: Tuple[int, int], arrow: Dict[str, Any]) -> int:
        side = arrow["side"]
        if side == "top":
            return cell[1]
        if side == "bottom":
            return self.h - 1 - cell[1]
        if side == "left":
            return cell[0]
        return self.w - 1 - cell[0]

    def nearest_matching(self, arrow: Dict[str, Any]) -> Optional[int]:
        want = arrow["color_hex"]
        best = None
        best_d = 10**9
        for pid, p in self.pieces.items():
            if p["color_hex"] != want:
                continue
            for cell in p["cells"]:
                if not self.on_track(cell, arrow):
                    continue
                d = self.dist_to_gate(cell, arrow)
                if d < best_d:
                    best_d = d
                    best = pid
        return best

    def try_arrow(self, idx: int) -> bool:
        arrow = self.arrows[idx]
        pid = self.nearest_matching(arrow)
        if pid is None:
            return False
        d = self.side_dir(arrow["side"])
        return self.slide(pid, d)

    def try_swipe(self, pid: int, d: Tuple[int, int]) -> bool:
        return self.slide(pid, d)

    def quadrant_of(self, cell: Tuple[int, int]) -> str:
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
    for i in range(len(board.arrows)):
        moves.append(("arrow", i))
    for pid in list(board.pieces.keys()):
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            moves.append(("swipe", (pid, d)))
    return moves


def apply_move(board: Board, move: Tuple[str, Any]) -> bool:
    kind, payload = move
    if kind == "arrow":
        return board.try_arrow(payload)
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
            if kind == "arrow":
                desc = f"arrow[{payload}]"
            else:
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
        sol = solve(data)
        if sol is None:
            print(f"FAIL {f}: unsolvable (or BFS limit)")
            ok_all = False
        else:
            print(f"OK   {f}: {len(sol)} moves -> {sol}")
    return 0 if ok_all else 2


if __name__ == "__main__":
    sys.exit(main())
