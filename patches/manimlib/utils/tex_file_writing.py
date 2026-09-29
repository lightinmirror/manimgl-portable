from __future__ import annotations

import os
import sys
import shutil
import re
import yaml
import subprocess
from functools import lru_cache

from pathlib import Path
import tempfile

from manimlib.utils.cache import cache_on_disk
from manimlib.config import manim_config
from manimlib.config import get_manim_dir
from manimlib.logger import log
from manimlib.utils.simple_functions import hash_string


def _find_tectonic() -> str:
    """Locate the bundled tectonic.exe (venv Scripts) or fall back to PATH."""
    bundled = Path(sys.executable).parent / "tectonic.exe"
    if bundled.exists():
        return str(bundled)
    fallback = shutil.which("tectonic") or "tectonic"
    log.warning(
        f"Bundled tectonic.exe not found next to {sys.executable}; falling back "
        f"to {fallback!r}. This render may not use the vendored toolchain."
    )
    return fallback


def _find_dvisvgm() -> str:
    """Locate the bundled dvisvgm.exe (venv Scripts) or fall back to PATH.

    The bundled build is statically linked against kpathsea and has no MiKTeX
    dependency, unlike the binaries shipped by MiKTeX.
    """
    bundled = Path(sys.executable).parent / "dvisvgm.exe"
    if bundled.exists():
        return str(bundled)
    fallback = shutil.which("dvisvgm") or "dvisvgm"
    log.warning(
        f"Bundled dvisvgm.exe not found next to {sys.executable}; falling back "
        f"to {fallback!r}. That may be a MiKTeX-installed dvisvgm while TEXMF "
        f"still points at the vendored tree, so this render may not match the "
        f"vendored pipeline. Restore Scripts\\dvisvgm.exe to fix."
    )
    return fallback


def _dvisvgm_env() -> dict[str, str]:
    """Environment forcing the bundled dvisvgm to use the vendored texmf tree.

    kpathsea resolves fonts through the search paths defined in its texmf.cnf;
    pointing both TEXMF and TEXMFCNF at the vendored copy keeps the lookup
    inside the venv instead of any system-wide TeX installation.
    """
    env = os.environ.copy()
    texmf = Path(sys.executable).parent / "texmf"
    if texmf.is_dir():
        env["TEXMF"] = str(texmf)
        env["TEXMFCNF"] = str(texmf / "web2c")
    return env


_DEFINED_GLYPH_RE = re.compile(r"<path\s+id='([^']+)'")
_USED_GLYPH_RE = re.compile(r"<use\s[^>]*xlink:href='#([^']+)'")


def _check_dvisvgm_output(svg: str, returncode: int) -> None:
    """Fail loudly instead of silently accepting a half-empty SVG.

    dvisvgm exits 0 even when it cannot resolve font files: it then emits
    <use> references to glyph definitions it never wrote.  Since a missing
    glyph silently degrades a figure, treat dangling references as an error.
    """
    if returncode != 0:
        raise LatexError(f"dvisvgm failed with return code {returncode}")
    if not svg.strip():
        raise LatexError("dvisvgm produced no output")
    defined = set(_DEFINED_GLYPH_RE.findall(svg))
    missing = sorted({g for g in _USED_GLYPH_RE.findall(svg) if g not in defined})
    if missing:
        texmf = Path(sys.executable).parent / "texmf"
        raise LatexError(
            f"dvisvgm could not resolve {len(missing)} glyph(s) "
            f"({', '.join(missing[:3])}{', ...' if len(missing) > 3 else ''}). "
            f"The vendored font tree under {texmf} is missing font files; "
            f"add them or re-check the tex template's font requirements."
        )


def get_tex_template_config(template_name: str) -> dict[str, str]:
    name = template_name.replace(" ", "_").lower()
    template_path = os.path.join(get_manim_dir(), "manimlib", "tex_templates.yml")
    with open(template_path, encoding="utf-8") as tex_templates_file:
        templates_dict = yaml.safe_load(tex_templates_file)
    if name not in templates_dict:
        log.warning(
            "Cannot recognize template '%s', falling back to 'default'.",
            name
        )
        name = "default"
    return templates_dict[name]


@lru_cache
def get_tex_config(template: str = "") -> tuple[str, str]:
    """
    Returns a compiler and preamble to use for rendering LaTeX
    """
    template = template or manim_config.tex.template
    config = get_tex_template_config(template)
    return config["compiler"], config["preamble"]


def get_full_tex(content: str, preamble: str = ""):
    return "\n\n".join((
        "\\documentclass[preview]{standalone}",
        preamble,
        "\\begin{document}",
        content,
        "\\end{document}"
    )) + "\n"


@lru_cache(maxsize=128)
def latex_to_svg(
    latex: str,
    template: str = "",
    additional_preamble: str = "",
    short_tex: str = "",
    show_message_during_execution: bool = True,
) -> str:
    """Convert LaTeX string to SVG string.

    Args:
        latex: LaTeX source code
        template: Path to a template LaTeX file
        additional_preamble: String including any added "\\usepackage{...}" style imports

    Returns:
        str: SVG source code

    Raises:
        LatexError: If LaTeX compilation fails
        NotImplementedError: If compiler is not supported
    """
    if show_message_during_execution:
        message = f"Writing {(short_tex or latex)[:70]}..."
    else:
        message = ""

    compiler, preamble = get_tex_config(template)

    preamble = "\n".join([preamble, additional_preamble])
    full_tex = get_full_tex(latex, preamble)
    return full_tex_to_svg(full_tex, compiler, message)


@cache_on_disk
def full_tex_to_svg(full_tex: str, compiler: str = "latex", message: str = ""):
    if message:
        print(message, end="\r")

    if compiler == "latex":
        dvi_ext = ".dvi"
    elif compiler in ("xelatex", "tectonic"):
        dvi_ext = ".xdv"
    else:
        raise NotImplementedError(f"Compiler '{compiler}' is not implemented")

    # Write intermediate files to a temporary directory
    with tempfile.TemporaryDirectory() as temp_dir:
        tex_path = Path(temp_dir, "working").with_suffix(".tex")
        dvi_path = tex_path.with_suffix(dvi_ext)

        # Write tex file (explicit UTF-8: the locale encoding is cp936/GBK on a
        # Chinese Windows, which would corrupt any non-ASCII TeX source)
        tex_path.write_text(full_tex, encoding="utf-8")

        # Run the compiler
        if compiler == "tectonic":
            process = subprocess.run(
                [
                    _find_tectonic(),
                    str(tex_path),
                    "--outfmt", "xdv",
                    "--keep-logs",
                    "-o", str(temp_dir),
                ],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
        else:
            process = subprocess.run(
                [
                    compiler,
                    "-no-pdf",
                    "-interaction=batchmode",
                    "-halt-on-error",
                    f"-output-directory={temp_dir}",
                    tex_path
                ],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            )

        if process.returncode != 0:
            # Handle error
            error_str = ""
            log_path = tex_path.with_suffix(".log")
            if log_path.exists():
                content = log_path.read_text(encoding="utf-8", errors="replace")
                error_match = re.search(r"(?<=\n! ).*\n.*\n", content)
                if error_match:
                    error_str = error_match.group()
            raise LatexError(error_str or "LaTeX compilation failed")

        # Run dvisvgm and capture output directly
        process = subprocess.run(
            [
                _find_dvisvgm(),
                dvi_path,
                "-n",  # no fonts
                "-v", "0",  # quiet
                "--stdout",  # output to stdout instead of file
            ],
            capture_output=True,
            env=_dvisvgm_env(),
        )

        # Return SVG string
        result = process.stdout.decode('utf-8', errors="replace")
        _check_dvisvgm_output(result, process.returncode)

    if message:
        print(" " * len(message), end="\r")

    return result


class LatexError(Exception):
    pass
