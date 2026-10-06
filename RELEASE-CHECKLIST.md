# 发布检查

这份文件记录发行包做过的检查。普通使用请看 `README.md` 和 `START-HERE.txt`。

## 已完成

| 项目 | 检查方式 | 结果 |
|---|---|---|
| TeX 输出 | 自带 dvisvgm 与完整 TeX Live 渲染同一 XDV，逐字形比较 | 结构一致 |
| 端到端渲染 | 真跑场景，生成 H.264 1280×720 视频 | 通过 |
| 分数线 | 抽帧和 SVG 检查 | 通过，分数线是 fill 型 rect |
| 包内工具 | 抓子进程、移除系统 PATH、移走包内 exe 反证 | 通过 |
| 缺字体处理 | 故意破坏字体树 | 明确报错并指出缺字 |
| Text / Tex 中文 | 渲染检查，覆盖 GBK locale 问题 | 通过 |
| 换路径和深路径 | 解压到新路径、超长路径 | 通过，超长时自动迁移 |
| 目标机依赖 | 移除系统 Python 和 TeX | 通过 |
| 安装恢复 | 移走缓存、改变解释器路径 | 能自动补齐 |
| 包体审计 | `audit_zip.py` | [A] 0，[B] 0 意外，[C] 0 |
| 从零构建 | `make-release.ps1` 全流程 | 产物可以解压并渲染视频 |
| 补丁复现 | 打到干净的 manimgl 1.7.2 | 逐字节一致且幂等 |

## 异机测试

测试包使用 `manimgl-selfcontained-win64.zip`。

```text
1. 解压到短路径，例如 D:\mgl
2. 双击 setup.cmd，确认自检完成（这一步会装 TeX 缓存）
3. 双击 run-demo.cmd，确认 videos\Demo.mp4 出现
```

要看画面，不只看命令有没有退出：

* 标题和 `中文公式` 没有方框或乱码
* `a/b` 的分数线、求和、积分都在
* 卡片四边和四个圆角完整

出问题时运行 `check.cmd`，把窗口截图和错误一起发回来。

## 离线首跑要单独验

不能靠「先联网跑一遍、再断网跑一遍」来证明首跑离线 —— 第一次联网跑的时候缓存就已经装好了，
后面那次断网跑只证明了「缓存已存在时能离线」，不是「首跑不需要网络」。

要证明首跑离线，得在**首次公式编译之前**就断网，或者用没有缓存的机器。本次是另行验证的：
把 Release 里的 `tectonic-cache.zip` 解到 `%LOCALAPPDATA%`，再用 `--only-cached` 强制只读
本地资源编译同一份 `.tex`。空缓存时同一条命令会失败，所以通过是有意义的。

## 这次构建前检查过的坑

早期审计曾经漏扫 `.cnf` 文件，导致 `texmf.cnf` 里的构建机路径没有被发现；后来改成排除
二进制扩展名、扫描其他文件。另一个问题是路径前缀误匹配，例如 `<build-root>` 不应该命中
`<build-root>-portable-build`。现在检查使用路径边界。

`texmf.cnf` 使用 `$SELFAUTOLOC` 自定位，`activate.bat` 使用 `%~dp0..` 自定位；其他非 Windows
激活脚本不放进产物。

## 构建和发布

每次改动 `manimlib` 或包根文件后，重新运行：

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1 -VenvDir <已打好补丁的 venv>
powershell -ExecutionPolicy Bypass -File build-exe.ps1
```

`build.ps1` 的 `-VenvDir` 是必需的，不传会在前置检查直接失败。

发布前检查：

1. `build.ps1` 返回成功，审计通过。
2. `MANIFEST.txt` 的 SHA-256 与产物一致。
3. 另一台机器完成异机测试。
4. Release 附件的 digest 与 MANIFEST 一致。

审计检查三类问题：构建机路径、配置文件里的意外绝对路径、配置文件中的非 ASCII 字节。

验证时不要设置 `PYTHONUTF8` 或 `PYTHONIOENCODING`，否则可能把 locale 编码问题藏起来。

`tectonic-cache.zip` 已折进主包，也作为单独附件保留；`tex-assets.zip` 给需要从源码构建的人使用。

## 许可证

发行包含 GPLv3 的 dvisvgm 和 FFmpeg，以及 GPL 字体 Fandol。公开发布时保留 `LICENSES/`、
`THIRD-PARTY.md` 和上游源码地址。
