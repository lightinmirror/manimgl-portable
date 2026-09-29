<!-- 这是 v1.0.0 Release 的说明，附件校验值在文末。 -->

# manimgl-portable v1.0.0

这是一个面向 Windows x64 的 manimgl 便携包。包里带 CPython、Tectonic、dvisvgm、FFmpeg
和一套最小字体树，目标机不需要另外安装 Python、LaTeX 或 FFmpeg。TeX 缓存也随主包提供，
首次渲染可以离线完成。

版本：manimgl 1.7.2、Tectonic 0.17.0、dvisvgm 3.2.2、FFmpeg 6.0、CPython 3.12.10。

## 下载

| 文件 | 大小 | 用途 |
|---|---:|---|
| `manimgl-selfcontained-win64.zip` | 233.5 MB | 默认选择，自带 Python |
| `manimgl-env-portable.zip` | 215.8 MB | 目标机已有 Python 3.12 时使用 |
| `manimgl-portable.exe` | 234.2 MB | 单文件启动器，自解包后运行 demo |
| `tectonic-cache.zip` | 42 MB | 主包已内置，缓存丢失时可单独恢复 |
| `tex-assets.zip` | 38 MB | 从源码构建时使用，包含 dvisvgm 和字体树 |

## 第一次运行

解压 `manimgl-selfcontained-win64.zip`，先运行 `setup.cmd`，再运行 `run-demo.cmd`。成功后，
`videos\Demo.mp4` 会出现。`run-showcase.cmd` 会渲染一个约 25 秒的功能示例，但它不代替
`setup.cmd` 做自检。

把文件夹移动到别处后，要在新位置再次运行 `setup.cmd`。这是因为虚拟环境的 `home` 必须是
绝对路径；不修复时会指向旧目录，并报 `No Python at '<旧路径>\python\python.exe'`。

## 已知问题

只在 Windows x64 上验证过。常用的 `Text`、`Tex`、CJK 和数学公式路径已覆盖，特殊宏包组合
可能缺字体。中文使用 Microsoft YaHei 和包内的 FandolSong-Bold；Fandol 的 Regular 字形
较细，`式` 等字在小尺寸下会发虚。

缓存丢失时，Tectonic 会联网下载约 90 MB。杀毒软件可能隔离 `ffmpeg.exe` 或 `tectonic.exe`，
遇到这种情况先恢复文件并把包目录加入白名单。

## 校验值

```text
manimgl-portable.exe             830FF21AE1FE147DDB3D7F8E36D180B53AE87D0521CAC5D0076DA2D6CC356B07
manimgl-selfcontained-win64.zip  C29D7DECF71049638925589CAFE59DCE9EC6EF2AD7C177BBE74DA11F6BC7917A
manimgl-env-portable.zip         A7E73DA7C9EE201329939BB27C2695A1AB1025228F40699AEA65BD658FD4717E
tectonic-cache.zip               67FA1804C0F1DA864AD6DB5A8815283A8BFAE6AF456C5581230921BF587E28F0
tex-assets.zip                   AC4DD64A60218FAB0FCEDB0AB22D7312D210E716668018F7054DCA0F1C837A26
```

## 许可证

发行包聚合了多个独立组件，各自使用自己的许可证。dvisvgm、FFmpeg 和 Fandol 字体涉及 GPL
许可证；完整清单和许可证文本见 `THIRD-PARTY.md` 与 `LICENSES/`。本仓库的脚本和补丁使用 MIT。

本项目非官方项目，与 3Blue1Brown、Grant Sanderson 及 manim 没有隶属或背书关系。
