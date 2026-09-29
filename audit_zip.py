"""Audit packaged zips for anything that would break on another machine.

Checks, per zip:
  [A] any occurrence of the BUILD machine's path prefix (--build-path) in any
      text file  ->  the classic "works here, dies there" bug
  [B] absolute drive-letter paths inside config-ish files
  [C] non-ASCII bytes inside config-ish files  ->  locale(GBK) YAML trap

Exit code 1 if anything in [A] or [C] is found, or if [B] finds a path that is
not explicitly allow-listed (pyvenv.cfg's `home` is expected: bootstrap rewrites
it on the target machine).

Usage:  python audit_zip.py <zip> [<zip> ...] [--build-path <the path to reject>]
"""
from __future__ import annotations

import argparse
import re
import sys
import zipfile

CONFIGY = re.compile(r"\.(ya?ml|cfg|pth|json|toml)$", re.I)
# 二进制/资源扩展名：其余一律当文本扫描。
# （早期版本用“只扫白名单”，结果漏掉了 .cnf —— 树里就有一个 texmf.cnf
#   带着构建机绝对路径。教训：用排除表，别用白名单。）
BINARY_EXT = re.compile(
    r"\.(png|jpe?g|gif|bmp|webp|ico|tiff?|exe|dll|pyd|so|dylib|a|lib|obj|o|bin"
    r"|ttf|otf|ttc|dfont|pfb|pfm|tfm|vf|enc|ofm|pk|fot"
    r"|zip|gz|xz|bz2|7z|rar|tar|whl|jar|class|pyc|pdb|db|sqlite3?|dat|idx|pack"
    r"|pdf|mp4|wav|mp3|flac|ogg|woff2?|mo|dylib)$",
    re.I,
)
# a drive-letter path, but not the "s:/" inside "https:/"
DRIVE = re.compile(r"(?<![A-Za-z])[A-Za-z]:[\\/]")
# files where an absolute path is expected or provably harmless, with the reason
ALLOW_RULES = (
    (re.compile(r"^manim-env/pyvenv\.cfg$"),
     "bootstrap.ps1 rewrites `home` on the target machine"),
    (re.compile(r"dist-info/direct_url\.json$"),
     "wheel provenance metadata written by the wheel builder; never read at runtime"),
)


def allow_reason(name: str) -> str | None:
    for pat, why in ALLOW_RULES:
        if pat.search(name):
            return why
    return None


def audit(zip_path: str, build_path: str) -> tuple[list[str], int]:
    lines: list[str] = []
    problems = 0
    # 路径边界：构建路径不该匹配“以它开头的别的目录名”（前缀撞车）
    build = re.compile(
        re.escape(build_path).replace("\\", r"[\\/]") + r"(?![A-Za-z0-9_.\-])", re.I)

    z = zipfile.ZipFile(zip_path)
    infos = z.infolist()

    # ---- [A] build machine paths, anywhere in text files
    a_hits = []
    for i in infos:
        if i.is_dir() or BINARY_EXT.search(i.filename):
            continue
        try:
            text = z.read(i.filename).decode("utf-8", errors="replace")
        except Exception:
            continue
        for m in build.finditer(text):
            ln = text.count("\n", 0, m.start()) + 1
            row = text.splitlines()[ln - 1].strip()[:96]
            a_hits.append(f"      {i.filename}:{ln}   {row}")
    lines.append(f"  [A] build-machine path {build_path!r}: {len(a_hits)} hit(s)")
    lines.extend(a_hits or ["      (none)"])
    problems += len(a_hits)

    # ---- [B] absolute paths in config-ish files
    b_hits, b_allowed = [], []
    for i in infos:
        if i.is_dir() or not CONFIGY.search(i.filename):
            continue
        text = z.read(i.filename).decode("utf-8", errors="replace")
        for ln, row in enumerate(text.splitlines(), 1):
            if DRIVE.search(row) and not row.lstrip().startswith("#"):
                entry = f"      {i.filename}:{ln}   {row.strip()[:96]}"
                why = allow_reason(i.filename)
                if why:
                    b_allowed.append(f"{entry}\n        [ok] {why}")
                else:
                    b_hits.append(entry)
    lines.append(f"  [B] absolute paths in config files: {len(b_hits)} unexpected, "
                 f"{len(b_allowed)} allow-listed")
    lines.extend(b_hits or ["      (no unexpected paths)"])
    for e in b_allowed:
        lines.append(f"      [expected, bootstrap fixes it] {e.strip()}")
    problems += len(b_hits)

    # ---- [C] non-ASCII in config-ish files
    c_hits = []
    for i in infos:
        if i.is_dir() or not CONFIGY.search(i.filename):
            continue
        n = sum(1 for c in z.read(i.filename) if c > 127)
        if n:
            c_hits.append(f"      {i.filename}: {n} non-ASCII bytes")
    lines.append(f"  [C] non-ASCII in config files: {len(c_hits)} file(s)")
    lines.extend(c_hits or ["      (none)"])
    problems += len(c_hits)

    lines.append(f"  entries: {len(infos)}")
    return lines, problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("zips", nargs="+")
    ap.add_argument("--build-path", required=True,
                    help="构建机路径前缀（例如 <盘>:\\<你的构建目录>），禁止出现在产物里")
    args = ap.parse_args()

    total = 0
    for zp in args.zips:
        print("=" * 74)
        print(zp)
        print("=" * 74)
        try:
            lines, problems = audit(zp, args.build_path)
        except FileNotFoundError:
            print("  !! not found")
            total += 1
            continue
        print("\n".join(lines))
        print(f"  => {'PASS' if problems == 0 else 'FAIL (%d problem(s))' % problems}")
        print()
        total += problems

    print("=" * 74)
    print("AUDIT " + ("PASSED" if total == 0 else f"FAILED ({total} problem(s))"))
    print("=" * 74)
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
