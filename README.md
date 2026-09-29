# manimgl-portable

[![Latest release](https://img.shields.io/github/v/release/lightinmirror/manimgl-portable?label=release)](../../releases/latest) [![Platform](https://img.shields.io/badge/platform-Windows%20x64-0078D6)](../../releases/latest)

manimgl 是 3Blue1Brown 用的动画引擎。在 Windows 上直接装它比较费事：要装 Python 和一堆
科学计算库，要装 TeX 发行版才有公式，要装 FFmpeg 还要配 PATH，中文在 GBK 环境下还会碰上
一串编码问题。

这个包把这些东西预先装好、调好，压成 232 MB。目标机什么都不用装，解压后双击两下就能出
视频，并且可以离线跑。

![demo](demo.gif)

## 下载

| 文件 | 适合谁 |
|---|---|
| [`manimgl-portable.exe`](../../releases/latest) | 想双击就用的人。自带 Python，首次运行会自解包。 |
| [`manimgl-selfcontained-win64.zip`](../../releases/latest/download/manimgl-selfcontained-win64.zip) | 想自己决定目录，或需要直接查看包内容的人。自带 Python。 |
| `manimgl-env-portable.zip` | 目标机已经有 Python 3.12 的人。 |

默认下载 exe 或 `manimgl-selfcontained-win64.zip`。缓存和源码构建用的附件在 [Releases](../../releases/latest) 里。

## 开始运行

### 单文件 exe

1. 从 [Releases](../../releases/latest) 下载 `manimgl-portable.exe`（233 MB）
2. 双击

首次运行会解包到 `%LOCALAPPDATA%\manimgl-portable\<版本>\` 并自检，大约一分钟；然后跑一个
演示，成功后会打开 `videos` 文件夹，里面是 `Demo.mp4`。以后再运行只要几秒，不会重复解包。

命令行参数原样转给 manimgl：

```powershell
manimgl-portable.exe my_scene.py MyScene -w -l
```

### zip

1. 下载 `manimgl-selfcontained-win64.zip`（232 MB）
2. 解压（位置随意；路径过长时脚本会自己搬到短位置）
3. 双击 `setup.cmd`，再双击 `run-demo.cmd`

出现 `videos\Demo.mp4`，说明整条链路（LaTeX → SVG → 渲染 → 视频）通了。`run-demo.cmd`
自己会先跑一遍自检，`run-showcase.cmd` 不会，所以要先跑过 `setup.cmd`。

双击 `run-showcase.cmd` 可以看约 25 秒的功能巡礼：文字与标记、公式与中文、图形与变换、
坐标轴作图、相机运动。

![showcase](showcase.gif)

**首次运行前先把解压目录加进杀毒软件白名单。** 包里的 `ffmpeg.exe`（77 MB）和
`tectonic.exe`（49 MB）是误报高发对象，经常被直接隔离删除。出问题就双击 `check.cmd`，
它会逐项报出哪个组件异常，把整屏截图发到 Issues 即可。

目标机如果已经装了 Python 3.12，可以改用 `manimgl-env-portable.zip`（214 MB），省掉自带的
那套解释器。

## 自己写场景

在包目录里新建 `my.py`：

```python
from manimlib import *

class MyScene(Scene):
    def construct(self):
        self.play(FadeIn(Text("你好")))
```

在这个目录下运行：

```powershell
manim-env\Scripts\python.exe -m manimlib my.py MyScene -w -m
```

结果在 `videos\MyScene.mp4`。

## 省掉了什么

| 自己装 manimgl | 本包 |
|---|---|
| Python 加 numpy、scipy、matplotlib、moderngl 等一堆依赖 | CPython 与全部依赖已打包 |
| TeX 发行版才有公式。本机装的 TeX Live 2024 是 8.33 GB、23.9 万个文件；MiKTeX 轻得多，但要能跑起来也在一 GB 上下 | 内置 Tectonic 加最小字体树，55 MB |
| FFmpeg，还要配好 PATH | 内置静态 FFmpeg |
| 中文豆腐块、GBK 编码报错 | 已处理 |

代价是包体 232 MB（压缩后）。

## 包里有什么

```
manim-env\                     虚拟环境，含全部 Python 依赖
  Scripts\tectonic.exe         LaTeX 引擎，自包含
  Scripts\dvisvgm.exe          DVI/XDV → SVG，TeX Live 的静态版本
  Scripts\texmf\               最小 kpathsea 字体树与 texmf.cnf
  Scripts\ffmpeg.exe           静态视频编码器
python\                        自带 CPython 3.12.10（仅 selfcontained 版）
tectonic-cache.zip             TeX 资源缓存，首跑免联网
setup.cmd / run-demo.cmd / run-showcase.cmd / check.cmd
demo.py / showcase.py / demo.gif / showcase.gif
START-HERE.txt / RESTORE.md
THIRD-PARTY.md / LICENSES\
```

## 已知问题

- 只在 Windows x64 上验证过。包内是 `.exe`，Linux 和 macOS 用不了。
- 只覆盖 `Text` / `Tex` 的常用路径：单行、`\n` 多行、CJK、常见数学符号。特殊宏包组合可能
  缺字体，这时会明确报错，不会静默画错。
- 中文依赖目标机有微软雅黑，中文版 Windows 自带。
- `Tex` 里的中文用包内自带的 FandolSong-Bold。Fandol 的 Regular 笔画偏细，`式` 这类字会
  明显发虚，所以钉成了 Bold。要换字体就改 `manimlib/tex_templates.yml` 里
  `basic_ctex_tealc` 的 `\setCJKmainfont`。
- 首次渲染公式需要 TeX 资源。包里带了缓存，所以能离线；缓存丢了 tectonic 会联网下载约
  90 MB。
- **把文件夹搬到别处之后，要在新位置再双击一次 `setup.cmd`。** 包内只有一处绝对路径
  （`pyvenv.cfg` 的 `home`，venv 机制要求绝对路径），移动后它仍指向旧位置，直接启动会报
  `No Python at '"<旧路径>\python\python.exe'`，重跑 `setup.cmd` 会自动改写。路径过长时
  `bootstrap.ps1` 会把整个目录搬到 `%LOCALAPPDATA%\manimgl-portable`。
- `setup.cmd` 的自检、以及跑 demo 时会打印一条 pydub 找不到 ffmpeg 的警告。那是 pydub
  自己在 PATH 上找 ffmpeg 造成的，不影响渲染，manimgl 走的是包内那个 ffmpeg。

## Text / Tex 上色

给文字上色要用 `fill_color=`，`color=` 不起作用：

```python
Text("hello", fill_color=YELLOW)   # 正确
Text("hello", color=YELLOW)        # 无效
```

`StringMobject` 默认 `fill_color=WHITE`，在 `color=` 之后执行 `set_fill()` 把它盖掉；而文字
是 `stroke_width=0` 的填充图形，所以 `color=` 只作用在看不见的描边上。`Circle`、`Square`
这类图元不受影响，`t2c={"部分": 颜色}` 也照常可用。

## 相对上游 manimgl 的改动

没有 fork。上游 master 一直活跃，PyPI 停在 1.7.2，所以这里只做加法：9 个文件，+196 / −30 行，
全部落在 venv 内，可用 `apply-patches.ps1` 复现。

改动集中在三件事：让 tectonic、dvisvgm、ffmpeg 按 `sys.executable` 相对定位，而不是去找系统
里的；把文本读写显式指定 UTF-8，免得 GBK 环境下中文被写坏；给 `mapbox_earcut >= 2.0`、
`setuptools >= 82` 这类依赖变动兜底。

完整清单带 pre/post sha256 校验，在 [`patches/README.md`](patches/README.md)。

## 从源码构建

脚本、补丁、文档都在本仓库，大文件走 Release 附件。

从零构建需要网络和 [uv](https://docs.astral.sh/uv/)：

```powershell
# TeX 素材二选一：本机装过 TeX Live，或用 Release 里的 tex-assets.zip（37 MB）
powershell -ExecutionPolicy Bypass -File make-release.ps1 -TexLiveDir <...\texlive\2024>
powershell -ExecutionPolicy Bypass -File make-release.ps1 -TexAssetsZip <...\tex-assets.zip>
```

它会建 venv 并装 `manimgl==1.7.2`、打本仓库的补丁、取 `tectonic.exe` 与 `ffmpeg.exe`（官方源）、
铺 `dvisvgm.exe` 与最小字体树、生成 TeX 缓存，最后调用 `build.ps1` 打包并审计。

`manimgl 1.7.2` 会 `import pkg_resources`，而 `setuptools >= 82` 已移除它，所以脚本钉了
`setuptools==81.0.0`。

只给已有环境打补丁：

```powershell
powershell -ExecutionPolicy Bypass -File apply-patches.ps1 -VenvDir <你的 venv>
```

只重新打包：

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
#   -VenvDir <已打好补丁的 venv>   -PkgDir <包根>   -OutDir <产物目录>
```

`build.ps1` 的流程是前置检查、打包、审计、写 MANIFEST。审计不过就非零退出，产物不可发布。
审计三项：产物里有没有混进构建机的绝对路径（这是"本机好好的、换机器就崩"的头号原因）、
配置类文件里有没有意外的绝对路径、配置类文件里有没有非 ASCII 字节。

`tectonic-cache.zip` 不入库，从 Release 附件取或由 `make-release.ps1` 生成；缺它时构建只警告，
但目标机首跑会联网下载约 90 MB。

## 许可

本包聚合了多个独立程序，各自适用自己的许可，其中 dvisvgm 与 FFmpeg 是 GPLv3，字体 Fandol
是 GPL。清单、许可文本和上游源码地址见 [THIRD-PARTY.md](THIRD-PARTY.md) 和
[`LICENSES/`](LICENSES/)。本仓库自己的脚本与补丁见 [LICENSE](LICENSE)。

感谢 [3Blue1Brown / manim](https://github.com/3b1b/manim)、
[Tectonic](https://github.com/tectonic-typesetting/tectonic)、
[dvisvgm](https://github.com/mgieseki/dvisvgm)、[FFmpeg](https://ffmpeg.org/)。

## 声明

非官方项目，与 3Blue1Brown、Grant Sanderson 及 manim 项目没有任何关联，也未获其背书。
它只是把上游 manimgl（MIT）和若干第三方组件打包在一起，方便 Windows 用户免安装使用。
