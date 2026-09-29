# 第三方组件与许可证

这个发行包把多个独立项目放在同一个目录里使用。它们仍然分别受自己的许可证约束；把它们
放在一起不等于把一个项目改成了另一个项目的衍生作品。

## 组件

| 组件 | 版本 | 许可证 | 许可证文件 | 上游 |
|---|---|---|---|---|
| manimgl (`manimlib`) | 1.7.2 | MIT | `LICENSES/manimgl-MIT.md` | https://github.com/3b1b/manim |
| Tectonic | 0.17.0 | MIT | `LICENSES/tectonic-MIT.txt` | https://github.com/tectonic-typesetting/tectonic |
| dvisvgm | 3.2.2 | GPL-3.0 | `LICENSES/GPL-3.0.txt` | https://github.com/mgieseki/dvisvgm |
| FFmpeg | 6.0，gyan.dev essentials | GPL-3.0 | `LICENSES/GPL-3.0.txt` | https://ffmpeg.org/ |
| CPython | 3.12.10 | PSF-2.0 | `LICENSES/Python-PSF.txt` | https://www.python.org/ |
| Fandol 字体 | TeX Live 2024 | GPL-3.0 + 字体例外 | `LICENSES/GPL-3.0.txt`、`LICENSES/Fandol-README.txt` | https://ctan.org/pkg/fandol |
| Latin Modern 字体 | TeX Live 2024 | GUST Font License | `LICENSES/GUST-Font-License.txt` | https://www.gust.org.pl/projects/e-foundry/latin-modern |
| CM / AMS 字体 | TeX Live 2024 | SIL OFL 1.1 | `LICENSES/SIL-OFL-1.1.txt` | https://ctan.org/pkg/amsfonts |
| 其余 Python 依赖 | 见 `dist-info` | 各自许可证 | 各包的 `*.dist-info/licenses/` | 各上游项目 |

FFmpeg 的 GPL 标记来自二进制的构建参数（包括 `--enable-gpl`、`--enable-version3`、
`--enable-libx264` 和 `--enable-libx265`）。dvisvgm 的 GPL 标记来自其仓库中的 `COPYING`。

## 分发时要保留什么

仓库和发行包都带有 `LICENSES/`。公开分发包含 GPL 组件的版本时，应同时保留许可证文本，
并提供对应的上游源码地址；本文件的组件表已经列出这些地址。不要把第三方程序说成是本项目
原创，也不要给它们增加许可证没有的限制。

GPL 只约束相应的 GPL 组件。它不会要求 manimgl（MIT）或用户自己的场景脚本改用 GPL；这里是
聚合发行，不是把这些项目合并成一个衍生作品。

## 本项目自己的内容

以下内容由本项目提供：

* `bootstrap.ps1`、`setup.cmd`、`run-demo.cmd`、`run-showcase.cmd`、`check.cmd`
* `demo.py`、`showcase.py`
* 对 `manimlib` 的补丁，见 `patches/`
* 构建脚本和审计器，见 `build.ps1`、`make-release.ps1`、`audit_zip.py`

这些文件使用仓库根目录 `LICENSE` 里的 MIT 许可证。该许可证只覆盖本仓库自己编写的文件，
不覆盖 `LICENSES/` 下的第三方许可证文本，也不覆盖 `manim-env/` 里各个 Python 包的内容。

## 其他说明

`manim-env/pyvenv.cfg` 里的 `home` 是构建机路径，这是 Python venv 的工作方式。目标机运行
`bootstrap.ps1` 时会把它改写到包内的 `python/`。Python 依赖的许可证文件保留在各自的
`*.dist-info/licenses/` 目录中。
