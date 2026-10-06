# manimgl-portable 的结构与恢复方法

这份文件给需要手动安装、移动或排查环境的人看。普通使用只需要解压、运行
`setup.cmd` 和 `run-demo.cmd`。

## 手动安装

下面的命令假定包解压在 `D:\mgl`。路径可以换，但不要一开始就放在很深的目录里。

```powershell
tar -xf <压缩包所在>\manimgl-selfcontained-win64.zip -C D:\mgl
Get-ChildItem D:\mgl -Recurse -File | Unblock-File
powershell -ExecutionPolicy Bypass -File D:\mgl\bootstrap.ps1
cd D:\mgl
manim-env\Scripts\python.exe -m manimlib demo.py Demo -w -m
```

成功标志是 `D:\mgl\videos\Demo.mp4` 出现。TeX 缓存已经折进主包；如果缓存没有安装，
首次公式渲染会联网下载约 90 MB。也可以手动装一次 —— 把 Release 里的 `tectonic-cache.zip`
解压到 `%LOCALAPPDATA%`（压缩包里就是 `TectonicProject\` 这一层，直接解到该目录即可）：

```powershell
tar -xf <压缩包所在>\tectonic-cache.zip -C "$env:LOCALAPPDATA"
```

装好后 `%LOCALAPPDATA%\TectonicProject\Tectonic\cache\bundles` 应该存在。

## 移动目录

包可以整体移动，但移动后必须在新位置再运行一次 `setup.cmd`。

`manim-env\pyvenv.cfg` 的 `home` 必须是绝对路径。它在旧位置运行过以后会指向旧的
`python\` 目录；直接启动会出现类似下面的错误：

```text
No Python at '"<旧路径>\python\python.exe'
```

在新位置运行 `setup.cmd` 会把它改写为新位置的 `python\`。实测退出码 103 的失败，
重跑后解释器检查正常，并能完整渲染 `Demo.mp4`。

单文件 exe 的解包目录由启动器管理，通常是：

```text
%LOCALAPPDATA%\manimgl-portable\<版本>\
```

如果把这个目录移走，不能继续依赖原 exe 的自动解包位置；应在新目录直接运行其中的
`setup.cmd`。否则再次双击 exe 会在原位置重新解出一份。

## 路径和自带工具

包内最长的相对路径约 146 个字符，bootstrap 使用约 94 个字符作为安全上限。超过上限时，
它会把目录复制到 `%LOCALAPPDATA%\manimgl-portable` 后继续运行。

tectonic、dvisvgm 和 ffmpeg 优先按 `sys.executable` 的位置查找，包内工具完整时不依赖系统
PATH；包内的丢了才会回落到 PATH 里的同名程序（见文末「注意事项」）：

| 工具 | 查找代码 |
|---|---|
| tectonic | `tex_file_writing._find_tectonic()` |
| dvisvgm | `tex_file_writing._find_dvisvgm()` |
| ffmpeg | `scene_file_writer._resolve_ffmpeg_bin()` |

`default_config.yml` 在包内，默认设置也在包内。下面只是把用到的三个值列出来示意，
不是可复制的 YAML：

```text
tex.template            = "basic_ctex_tealc"
text.font               = "Microsoft YaHei"
file_writer.ffmpeg_bin  = "ffmpeg"
```

因此从不同目录启动不会改变这些默认值。`custom_config.yml` 只在当前工作目录被加载，
适合做项目级覆盖，不是包的默认配置来源。

## 虚拟环境的 `home`

虚拟环境要求 `pyvenv.cfg` 中的 `home` 是绝对路径，不能改成相对路径。bootstrap 按下面
的顺序找基础解释器，第一项就是包内自带的 Python：

1. `<包根>\python`
2. `pyvenv.cfg` 当前的 `home`
3. uv 管理的 CPython 3.12
4. `uv python find 3.12`
5. Windows `py` 启动器
6. 常见的 Python 3.12 安装目录

所以 selfcontained 版本不需要目标机安装 Python。

## 包内容

| 路径 | 说明 | 约占空间 |
|---|---|---:|
| `manim-env\` | 虚拟环境和 Python 依赖 | 0.45 GB |
| `manim-env\Scripts\tectonic.exe` | 自包含 LaTeX 引擎 | 49.2 MB |
| `manim-env\Scripts\dvisvgm.exe` | DVI/XDV 到 SVG 的静态工具 | 6.3 MB |
| `manim-env\Scripts\texmf\` | 最小字体树和 `texmf.cnf` | 49.2 MB |
| `manim-env\Scripts\ffmpeg.exe` | 静态视频编码器 | 77.1 MB |
| `python\` | CPython 3.12.10 | 49.0 MB |
| `bootstrap.ps1` | 安装和自检 | — |
| `demo.py` | 冒烟测试场景 | — |

## 补丁层

补丁针对 manimgl 1.7.2。`patches/manifest.json` 为每个文件记录打补丁前后的 SHA-256，
`apply-patches.ps1` 只接受这两个状态：已经打过就跳过，正好是上游原版就覆盖，其他情况中止。
这样不会把补丁悄悄打进一个未知版本的 manimgl。

详细文件清单和 diff 在 `patches/README.md` 里；注意 `patches/` 只在源码仓库里，不进发行包。

## 注意事项

* 如果 `Scripts\dvisvgm.exe` 丢失，程序可能回落到 PATH 中的 dvisvgm；这时不再是包内管线。
* dvisvgm 缺字体时可能仍返回 0，但会产生坏 SVG。`_check_dvisvgm_output()` 会检查输出，
  把它变成明确的缺字报错。
* `pydub` 可能提示在 PATH 中找不到 ffmpeg。这条提示不影响当前渲染路径，manimgl 会使用包内
  的 ffmpeg。

## 重建补丁环境

补丁前的哈希、补丁后的哈希和完整的补丁文件都在 `patches/`。不建议手动删除单个改动；
要重新得到这个补丁环境，先装上游 `manimgl==1.7.2`，再按 `apply-patches.ps1` 的流程打一遍。

想回到**未打补丁**的上游文件，重装 `manimgl==1.7.2` 之后就停手，不要再跑
`apply-patches.ps1` —— 那个脚本会直接覆盖成补丁版本。
