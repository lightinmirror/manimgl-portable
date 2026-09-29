# manimgl 1.7.2 补丁

这里保存的是针对 manimgl 1.7.2 的补丁层。它有三个用途：把补丁重新打到干净的上游版本、
检查当前文件是否仍是预期版本、以及让每一处改动都能被审阅。

## 基准

```text
manimgl 1.7.2 (PyPI wheel)
sha256 = e2644c93cffd93ea56ddded9c9752b9371f7d2d19e99da5693dd03b2e0d658e4
```

## 改动规模

共 9 个文件，增加 196 行、删除 30 行。其他上游文件没有改动。

| 文件 | 改动 | 目的 |
|---|---:|---|
| `utils/tex_file_writing.py` | +117 / -21 | 找包内 tectonic/dvisvgm；检查缺字 SVG；所有文本 I/O 显式使用 UTF-8 |
| `scene/scene_file_writer.py` | +42 / -1 | 找包内 ffmpeg；配置中的失效绝对路径自动回落 |
| `config.py` | +11 / -2 | 配置优先按 UTF-8（含 BOM）读取 |
| `tex_templates.yml` | +10 / -0 | 增加 `basic_ctex_tealc`，使用 Tectonic 和 FandolSong-Bold |
| `default_config.yml` | +7 / -2 | 设置默认 TeX 模板、中文字体和 ffmpeg 裸名 |
| `utils/space_ops.py` | +4 / -1 | 给 `mapbox_earcut >= 2.0` 传 ndarray，而不是 list |
| `mobject/svg/svg_mobject.py` | +3 / -1 | SVG 文件按 UTF-8 读取 |
| `mobject/svg/text_mobject.py` | +1 / -1 | 临时 SVG 按 UTF-8 读取 |
| `utils/shaders.py` | +1 / -1 | shader 按 UTF-8 读取 |

其中多处修复针对同一个环境：中文 Windows 的系统 locale 可能是 GBK，而源文件和子进程输出
实际需要 UTF-8。没有显式编码时，中文 `.tex` 会乱码，`subprocess(text=True)` 也可能抛出
`UnicodeDecodeError`。

## 文件布局

```text
patches/
  README.md            本说明
  manifest.json        每个文件的前后 SHA-256 和 diff 文件名
  manimlib/<路径>      打补丁后的完整文件
  diffs/*.patch        供审阅的统一 diff
```

## 使用

```powershell
# 给 venv 里的 manimgl 打补丁
powershell -ExecutionPolicy Bypass -File apply-patches.ps1 -VenvDir <你的 venv>

# 或者直接指定 manimlib 目录
powershell -ExecutionPolicy Bypass -File apply-patches.ps1 -ManimlibDir <...\site-packages\manimlib>

# 只检查，不写文件
powershell -ExecutionPolicy Bypass -File apply-patches.ps1 -VenvDir <你的 venv> -WhatIf
```

`manifest.json` 同时记录补丁前和补丁后的哈希：

* 当前文件等于 `post_sha256`：说明已经打过，跳过。
* 当前文件等于 `pre_sha256`：说明是上游原版，覆盖为补丁版本。
* 两者都不等：中止并列出冲突文件。

写入后还会再次校验哈希。因此版本不对或文件被其他改动时，脚本不会静默覆盖。

## 与上游的关系

上游 GitHub 仓库仍在更新，但 PyPI 版本停在 1.7.2。本补丁只针对这个 PyPI 版本；如果改用
上游 master，需要重新检查哪些补丁还需要保留。补丁和上游 manimgl 都使用 MIT 许可证，
详情见根目录的 `LICENSE` 和 `THIRD-PARTY.md`。
