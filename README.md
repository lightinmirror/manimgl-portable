# manimgl-portable

**在 Windows 上，免安装开始制作数学动画。**

[![Latest release](https://img.shields.io/github/v/release/lightinmirror/manimgl-portable?label=release)](https://github.com/lightinmirror/manimgl-portable/releases/latest) [![Platform](https://img.shields.io/badge/platform-Windows%20x64-0078D6)](https://github.com/lightinmirror/manimgl-portable/releases/latest)

manimgl-portable 将 3Blue1Brown 使用的 ManimGL 动画引擎及运行依赖打包成一个 Windows
便携环境。无需安装 Python、LaTeX 或 FFmpeg，下载后即可运行示例；用 Python 编写自己的
场景，把公式、几何图形和函数变化导出为 MP4 视频。

**Windows x64 · 中文文字与公式 · 内置 TeX 缓存，常见场景可离线渲染**

![ManimGL 功能演示：中文文字、数学公式、图形变换、函数图像与相机运动](showcase.gif)

上面是随包提供的约 25 秒功能演示，源码见 [showcase.py](showcase.py)。完成环境自检后，
双击 `run-showcase.cmd` 即可渲染；也可以从源码中挑一段，作为自己的第一个练习。

[**下载 exe，先体验**](https://github.com/lightinmirror/manimgl-portable/releases/latest/download/manimgl-portable.exe)
· [**下载完整 zip，管理自己的场景目录**](https://github.com/lightinmirror/manimgl-portable/releases/latest/download/manimgl-selfcontained-win64.zip)
· [使用限制](#使用限制与排错)

## 适合用来做什么

- **学习 ManimGL**：从可运行的示例开始，修改文字、公式和图形，逐步学习用代码编排动画。
- **制作数学演示**：将公式推导、几何变换或函数图像做成视频，用于教学和讲解。
- **在离线电脑上创作**：完整包自带解释器、渲染工具与 TeX 缓存，常见场景不需要联网准备资源。

场景使用 Python 编写。本包基于 **ManimGL 1.7.2**，属于非官方发行包；Manim Community
Edition（ManimCE）的教程和场景可能使用不同的 API，不能直接假定兼容。

## 下载：主程序包选一个即可

exe 和完整 zip 都带 Python、LaTeX 相关工具、FFmpeg 与 TeX 缓存，**正常使用无需再下载
缓存包或构建素材**。

| 你想做什么 | 下载 | 大小 |
|---|---|---:|
| 先运行演示，看看效果 | [manimgl-portable.exe](https://github.com/lightinmirror/manimgl-portable/releases/latest/download/manimgl-portable.exe) | 234.2 MB |
| 自己决定目录，查看包内容并编写场景 | [manimgl-selfcontained-win64.zip](https://github.com/lightinmirror/manimgl-portable/releases/latest/download/manimgl-selfcontained-win64.zip) | 233.5 MB |

其他附件见 [Releases](https://github.com/lightinmirror/manimgl-portable/releases/latest)：

- `manimgl-env-portable.zip`（215.8 MB）：省去自带解释器，适合目标机已有 Python 3.12 的用户。
- `tectonic-cache.zip`：主包已内置；缓存丢失时，用它恢复离线资源。
- `tex-assets.zip`：从源码构建时使用，正常运行无需单独下载。

## 第一次运行

### exe：下载后双击

1. 下载 `manimgl-portable.exe`。
2. 双击运行，等待首次解包、环境自检与演示渲染。
3. 成功后会打开 `videos` 文件夹，查看其中的 `Demo.mp4`。

首次解包到 `%LOCALAPPDATA%\manimgl-portable\<版本>\`，需要一些时间；后续运行会复用
已解包的环境。双击 exe 会运行环境验证示例；想看完整功能演示，可在解包目录中双击
`run-showcase.cmd`。

### zip：解压后运行两个脚本

1. 下载并完整解压 `manimgl-selfcontained-win64.zip`。建议使用较短的目录，包根完整路径
   不超过 94 个字符；过长时安装脚本会尝试迁移到短位置。
2. 双击 `setup.cmd`，完成环境自检和缓存安装。
3. 双击 `run-demo.cmd`，查看生成的 `videos\Demo.mp4`。

`run-demo.cmd` 自己也会先做自检；`run-showcase.cmd` 不会，所以观看功能演示前应完成
`setup.cmd`。

### 怎样确认环境正常

`Demo.mp4` 中的中文、分数线、求和与积分应显示完整。这个示例检查 LaTeX → SVG → 渲染
→ 视频的整条链路，源码见 [demo.py](demo.py)。

![环境验证示例：中文标题、分数、求和与积分](demo.gif)

杀毒软件可能隔离包内的 `ffmpeg.exe` 或 `tectonic.exe`。出现组件缺失或运行失败时，先检查
隔离记录并恢复文件，必要时将包目录加入白名单；再运行 `check.cmd`，把检查结果和错误
截图附到 [Issues](https://github.com/lightinmirror/manimgl-portable/issues)。

## 写自己的第一个场景

先完成上面的演示，再用 Python 编写场景。将下面的代码保存为 UTF-8 编码的 `my.py`：

```python
from manimlib import *

class MyScene(Scene):
    def construct(self):
        self.play(FadeIn(Text("你好")))
```

**使用 exe**：把 `my.py` 和 exe 放在同一目录，在该目录打开 PowerShell，运行：

```powershell
.\manimgl-portable.exe my.py MyScene -w -m
```

**使用 zip**：把 `my.py` 放在完成自检的包目录，在该目录打开 PowerShell，运行：

```powershell
.\manim-env\Scripts\python.exe -m manimlib my.py MyScene -w -m
```

两种方式都会将结果写到当前目录的 `videos\MyScene.mp4`。exe 会把命令行参数转发给
ManimGL；PowerShell 调用当前目录的程序时，前面需要带 `.\`。

下一步可以修改 `"你好"`，或使用 `Text("你好", fill_color=YELLOW)` 改颜色；再查看
[showcase.py](showcase.py)，学习公式、图形变换、坐标轴和相机运动的写法。

## 省掉哪些配置工作

在 Windows 上搭建 ManimGL，通常需要准备解释器和科学计算库、公式渲染工具、视频编码器，
还要处理工具路径与中文编码。本包提前完成这些准备：

| 环节 | 包内提供 |
|---|---|
| Python 和科学计算依赖 | CPython 3.12.10，以及 numpy、scipy、matplotlib、moderngl 等依赖 |
| LaTeX 公式与中文公式 | Tectonic、dvisvgm、最小字体树与 TeX 资源缓存 |
| 视频编码 | 静态 FFmpeg，按包内位置查找 |
| 中文 Windows 编码 | 针对 GBK locale 的文本读写修复 |

完整 zip 压缩后为 233.5 MB。目标机无需另装 Python、LaTeX 或 FFmpeg；自定义场景仍由
使用者编写。

发行包已做过异机运行、离线首次公式编译、中文渲染与包体审计检查，具体方式见
[RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md)。附件 SHA-256 见
[Release 说明](https://github.com/lightinmirror/manimgl-portable/releases/latest)，组件来源与
许可证见 [THIRD-PARTY.md](THIRD-PARTY.md)。

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

上面这份是 zip 的内容。`patches/`、`LICENSE`、构建脚本只在源码仓库里，不进发行包。

## 使用限制与排错

- 只在 Windows x64 上验证过。包内是 `.exe`，Linux 和 macOS 用不了。
- 只覆盖 `Text` / `Tex` 的常用路径：单行、`\n` 多行、CJK、常见数学符号。特殊宏包组合可能
  缺字体，这时会明确报错，不会静默画错。
- 中文依赖目标机有微软雅黑，中文版 Windows 自带。
- `Tex` 里的中文用包内自带的 FandolSong-Bold。Fandol 的 Regular 笔画偏细，`式` 这类字会
  明显发虚，所以钉成了 Bold。要换字体就改
  `manim-env\Lib\site-packages\manimlib\tex_templates.yml` 里 `basic_ctex_tealc` 的
  `\setCJKmainfont`。
- 首次渲染公式需要 TeX 资源。包里带了缓存，所以能离线；缓存丢了 tectonic 会联网下载约
  90 MB。
- **把文件夹搬到别处之后，要在新位置再双击一次 `setup.cmd`。** 移动后需要修复的只有解释器
  路径 —— `pyvenv.cfg` 的 `home`（venv 机制要求绝对路径）。它仍指向旧位置，直接启动会报
  `No Python at '"<旧路径>\python\python.exe'`，重跑 `setup.cmd` 会自动改写。包内另有几处
  构建期元数据（如 pip 的 `direct_url.json`）带绝对来源地址，但运行时不会被读取。
  路径过长时 `bootstrap.ps1` 会把整个目录搬到 `%LOCALAPPDATA%\manimgl-portable`。
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

完整清单带 pre/post sha256 校验，在源码仓库的 [`patches/README.md`](patches/README.md) 里
（`patches/` 不进发行包）。

## 从源码构建

脚本、补丁、文档都在本仓库，大文件走 Release 附件。

从零构建需要网络和 [uv](https://docs.astral.sh/uv/)：

```powershell
# TeX 素材二选一：本机装过 TeX Live，或用 Release 里的 tex-assets.zip（37.6 MB）
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

只重新打包。`-VenvDir` 是必需的，不传会在前置检查直接失败；其余参数留空会按默认推断：

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1 -VenvDir <已打好补丁的 venv>
#   可选：-PkgDir <包根>   -OutDir <产物目录>   -BuildPath <构建机路径前缀>
```

`build.ps1` 的流程是前置检查、打包、审计、写 MANIFEST。审计不过就非零退出，产物不可发布。
审计三项：产物里有没有混进构建机的绝对路径（这是"本机好好的、换机器就崩"的头号原因）、
配置类文件里有没有意外的绝对路径、配置类文件里有没有非 ASCII 字节。

`tectonic-cache.zip` 不入库，从 Release 附件取或由 `make-release.ps1` 生成；缺它时构建只警告，
但目标机首跑会联网下载约 90 MB。

## 许可

本包聚合了多个独立程序，各自适用自己的许可，其中 dvisvgm 与 FFmpeg 是 GPLv3，字体 Fandol
是 GPL。清单、许可文本和上游源码地址见 [THIRD-PARTY.md](THIRD-PARTY.md) 和
[`LICENSES/`](LICENSES/) —— 这两份都在发行包里。本仓库自己的脚本与补丁见
[LICENSE](LICENSE)，它只在源码仓库里。

感谢 [3Blue1Brown / manim](https://github.com/3b1b/manim)、
[Tectonic](https://github.com/tectonic-typesetting/tectonic)、
[dvisvgm](https://github.com/mgieseki/dvisvgm)、[FFmpeg](https://ffmpeg.org/)。

## 声明

非官方项目，与 3Blue1Brown、Grant Sanderson 及 manim 项目没有任何关联，也未获其背书。
它只是把上游 manimgl（MIT）和若干第三方组件打包在一起，方便 Windows 用户免安装使用。
