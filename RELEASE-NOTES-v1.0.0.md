# manimgl-portable v1.0.0

**在 Windows 上，免安装开始制作数学动画。**

manimgl-portable 将 ManimGL 动画引擎及运行依赖打包成便携环境。无需安装 Python、LaTeX
或 FFmpeg，下载后即可运行示例；用 Python 编写场景，将公式、几何图形和函数变化导出为
MP4 视频。主包包含 TeX 资源缓存，常见场景可以离线渲染。

支持 **Windows x64**，基于 **ManimGL 1.7.2**，为非官方发行包。场景需要用 Python 编写，
ManimCE 的场景不能直接假定兼容。[查看功能演示与完整使用说明](https://github.com/lightinmirror/manimgl-portable#readme)。

## 下载：主程序包选一个即可

| 你想做什么 | 文件 | 大小 |
|---|---|---:|
| 先运行演示，看看效果 | [manimgl-portable.exe](https://github.com/lightinmirror/manimgl-portable/releases/latest/download/manimgl-portable.exe) | 234.2 MB |
| 自己决定目录，查看包内容并编写场景 | [manimgl-selfcontained-win64.zip](https://github.com/lightinmirror/manimgl-portable/releases/latest/download/manimgl-selfcontained-win64.zip) | 233.5 MB |

两者都带 Python、LaTeX 相关工具、FFmpeg 和 TeX 缓存，**正常使用无需再下载下面的缓存包
或构建素材**。

其他附件：

| 文件 | 大小 | 用途 |
|---|---:|---|
| `manimgl-env-portable.zip` | 215.8 MB | 目标机已有 Python 3.12 时使用，省去自带解释器 |
| `tectonic-cache.zip` | 42.2 MB | 主包已内置；缓存丢失时可单独恢复 |
| `tex-assets.zip` | 37.6 MB | 从源码构建时使用，包含 dvisvgm 和字体树 |

## 第一次运行

- **exe**：下载后双击，等待首次解包和自检。演示渲染成功后会打开 `videos` 文件夹，其中
  是 `Demo.mp4`。解包目录为 `%LOCALAPPDATA%\manimgl-portable\<版本>\`。
- **完整 zip**：完整解压，双击 `setup.cmd`，再双击 `run-demo.cmd`，结果为
  `videos\Demo.mp4`。包根完整路径应不超过 94 个字符，过长时脚本会尝试迁移。

这个演示检查中文、公式与视频渲染是否正常。想看文字、公式、图形变换、函数图像和相机
运动的完整示例，完成 `setup.cmd` 后双击 `run-showcase.cmd`，视频约 25 秒。

想开始自己的场景，见 [README 的第一个场景示例](https://github.com/lightinmirror/manimgl-portable#写自己的第一个场景)。

## 使用限制与排错

- 只在 Windows x64 上验证过。常用的 `Text`、`Tex`、CJK 和数学公式路径已覆盖，特殊宏包
  组合可能缺资源或字体。
- 普通中文文字依赖目标机的 Microsoft YaHei，中文版 Windows 自带；中文公式使用包内
  FandolSong-Bold。
- 主包内置缓存支持常见场景离线首跑。缓存丢失时，Tectonic 会尝试联网下载约 90 MB；
  离线电脑应先用 `tectonic-cache.zip` 恢复缓存。
- 移动 zip 的解压目录后，要在新位置再次运行 `setup.cmd`，修复虚拟环境的解释器路径。
- 杀毒软件可能隔离 `ffmpeg.exe` 或 `tectonic.exe`。先恢复文件，必要时将包目录加入
  白名单，再运行 `check.cmd` 查看具体异常。

发行包已做过异机运行、离线首次公式编译和包体审计，验证方式见
[RELEASE-CHECKLIST.md](https://github.com/lightinmirror/manimgl-portable/blob/main/RELEASE-CHECKLIST.md)。

组件版本：ManimGL 1.7.2、Tectonic 0.17.0、dvisvgm 3.2.2、FFmpeg 6.0、CPython 3.12.10。

## 校验值

```text
manimgl-portable.exe             6888F9AE41793A01BAD97282996952B068ADF93520B5E3C41C437A6EB8B58A70
manimgl-selfcontained-win64.zip  7DEAA95953774CF47F79232D3FF6DAF2E0515F811A71D33DA1BFAA7B98200B68
manimgl-env-portable.zip         34989D0C021C9655113C5A5395ED332B2AB4762F4A7055A36B9CB1C5AA61AD07
tectonic-cache.zip               67FA1804C0F1DA864AD6DB5A8815283A8BFAE6AF456C5581230921BF587E28F0
tex-assets.zip                   AC4DD64A60218FAB0FCEDB0AB22D7312D210E716668018F7054DCA0F1C837A26
```

## 许可证

发行包聚合了多个独立组件，各自使用自己的许可证。dvisvgm、FFmpeg 和 Fandol 字体涉及 GPL
许可证；完整清单和许可证文本见 `THIRD-PARTY.md` 与 `LICENSES/`。本仓库的脚本和补丁使用 MIT。

本项目非官方项目，与 3Blue1Brown、Grant Sanderson 及 manim 没有隶属或背书关系。
