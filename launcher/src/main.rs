//! manimgl-portable 单文件启动器
//!
//! 结构：`[本 exe][payload.zip][offset:u64 LE][magic:8B]`
//! 首次运行把内嵌的 zip 解到 `%LOCALAPPDATA%\manimgl-portable\<版本>\`，
//! 接着跑包内的 `bootstrap.ps1`（自适应安装/自检），然后：
//!   * 不带参数（双击）→ 跑 demo，成功则打开输出目录
//!   * 带参数         → 原样转发给 `python -m manimlib`

use std::env;
use std::fs;
use std::io::{self, Cursor, Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::process::{exit, Command};

const VERSION: &str = env!("CARGO_PKG_VERSION");
const MAGIC: &[u8; 8] = b"MGLPORT1";
const TRAILER: usize = 16; // u64 offset + magic

// 中文 Windows 的控制台默认是 CP936，而我们把 UTF-8 字节直接写出去 ——
// 不切码页的话用户会看到乱码。设置成 65001 即可（失败也无所谓）。
#[cfg(windows)]
extern "system" {
    fn SetConsoleOutputCP(cp: u32) -> i32;
}

fn force_utf8_console() {
    #[cfg(windows)]
    unsafe {
        SetConsoleOutputCP(65001);
    }
}

fn main() {
    force_utf8_console();
    if let Err(e) = run() {
        eprintln!();
        eprintln!("[错误] {e}");
        pause();
        exit(1);
    }
}

fn run() -> Result<(), String> {
    let exe = env::current_exe().map_err(|e| format!("取自身路径失败: {e}"))?;
    // 只读尾部 16 字节的 trailer，不把整个 exe（约 234 MB）读进内存
    let (off, len) = payload_span(&exe)?;

    let target = install_dir()?;
    let marker = target.join(".payload-ok");
    let stamp = format!("{VERSION}:{len}");

    let fresh = fs::read_to_string(&marker).map(|s| s.trim().to_string()).ok().as_deref()
        != Some(stamp.as_str());

    if fresh {
        // 防止两个实例同时解包到同一个目录
        let _lock = ExtractLock::acquire(&target)?;
        // 拿到锁之后再查一次：可能另一个实例刚把它装完了
        let done = fs::read_to_string(&marker)
            .map(|s| s.trim().to_string())
            .ok()
            .as_deref()
            == Some(stamp.as_str());
        if !done {
            println!("============================================");
            println!("  manimgl-portable {VERSION}  首次运行：解包");
            println!("============================================");
            println!("目标目录: {}", target.display());
            println!("（约 0.5 GB，需要一两分钟）");
            println!();
            // 只有真要解包时才把载荷读进来
            let payload = read_payload(&exe, off, len)?;
            extract(&payload, &target)?;
            fs::write(&marker, &stamp).map_err(|e| format!("写标记失败: {e}"))?;

            let bootstrap = target.join("bootstrap.ps1");
            println!();
            println!("-- 环境自检 --");
            let st = Command::new("powershell")
                .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"])
                .arg(&bootstrap)
                .status()
                .map_err(|e| format!("无法运行 powershell: {e}"))?;
            if !st.success() {
                return Err("环境自检未通过（请把上面的输出发回）".into());
            }
        }
    } else {
        println!("== manimgl-portable {VERSION} ==");
        println!("已安装于: {}", target.display());
    }

    let py = target.join("manim-env").join("Scripts").join("python.exe");
    if !py.is_file() {
        return Err(format!("找不到解释器: {}", py.display()));
    }

    let args: Vec<String> = env::args().skip(1).collect();

    if args.is_empty() {
        // 双击：跑 demo 并展示结果
        let demo = target.join("demo.py");
        let videos = target.join("videos");
        println!();
        println!("-- 跑 demo（首次编译公式较慢，请耐心）--");
        let st = Command::new(&py)
            .arg("-m").arg("manimlib")
            .arg(&demo)
            .args(["Demo", "-w", "-m", "--video_dir"])
            .arg(&videos)
            .current_dir(&target)
            .status()
            .map_err(|e| format!("运行 manimgl 失败: {e}"))?;

        println!();
        let out = videos.join("Demo.mp4");
        if out.is_file() {
            println!("[成功] 视频已生成：{}", out.display());
            println!("       想看完整功能巡礼：双击 run-showcase.cmd（约 25 秒）");
            let _ = Command::new("explorer").arg(&videos).spawn();
        } else {
            println!("[失败] 没有生成 Demo.mp4（退出码 {:?}）", st.code());
            println!("       把上面的报错发回，或双击目录里的 check.cmd 自查。");
        }
        pause();
    } else {
        // 转发给 manimgl
        let st = Command::new(&py)
            .arg("-m").arg("manimlib")
            .args(&args)
            .status()
            .map_err(|e| format!("运行 manimgl 失败: {e}"))?;
        exit(st.code().unwrap_or(1));
    }
    Ok(())
}

/// 只读文件尾部的 trailer，算出载荷的 [起点, 长度)，不加载整个文件
fn payload_span(exe: &Path) -> Result<(u64, u64), String> {
    let mut f = fs::File::open(exe).map_err(|e| format!("打开自身失败: {e}"))?;
    let total = f.metadata().map_err(|e| format!("取文件大小失败: {e}"))?.len();
    if total < TRAILER as u64 {
        return Err("文件太小，不是合法载荷".into());
    }
    let mut t = [0u8; TRAILER];
    f.seek(SeekFrom::Start(total - TRAILER as u64))
        .map_err(|e| format!("定位 trailer 失败: {e}"))?;
    f.read_exact(&mut t).map_err(|e| format!("读 trailer 失败: {e}"))?;
    if &t[8..16] != MAGIC {
        return Err("找不到内嵌载荷（这个 exe 没被打过包？）".into());
    }
    let off = u64::from_le_bytes(t[0..8].try_into().unwrap());
    if off >= total - TRAILER as u64 {
        return Err("载荷偏移非法".into());
    }
    Ok((off, total - TRAILER as u64 - off))
}

/// 只在确认需要解包时才把载荷读进内存
fn read_payload(exe: &Path, off: u64, len: u64) -> Result<Vec<u8>, String> {
    let mut f = fs::File::open(exe).map_err(|e| format!("打开自身失败: {e}"))?;
    f.seek(SeekFrom::Start(off)).map_err(|e| format!("定位载荷失败: {e}"))?;
    let mut buf = vec![0u8; len as usize];
    f.read_exact(&mut buf)
        .map_err(|e| format!("读载荷失败（文件被截断？）: {e}"))?;
    Ok(buf)
}

/// 首启解包期间的互斥锁：create_new 原子创建，进程退出时删除
struct ExtractLock {
    path: PathBuf,
}

impl ExtractLock {
    fn acquire(target: &Path) -> Result<Self, String> {
        fs::create_dir_all(target).map_err(|e| format!("建目录失败: {e}"))?;
        let path = target.join(".extracting");
        for _ in 0..600 {
            match fs::OpenOptions::new().write(true).create_new(true).open(&path) {
                Ok(mut f) => {
                    let _ = write!(f, "{}", std::process::id());
                    return Ok(Self { path });
                }
                Err(e) if e.kind() == io::ErrorKind::AlreadyExists => {
                    println!("  另一个实例正在解包，等它完成 ...");
                    std::thread::sleep(std::time::Duration::from_millis(500));
                }
                Err(e) => return Err(format!("创建锁文件失败: {e}")),
            }
        }
        Err("等另一个实例解包超时（60 秒）。确认没有其它实例后，删掉目标目录下的 .extracting 再试。".into())
    }
}

impl Drop for ExtractLock {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
    }
}

fn install_dir() -> Result<PathBuf, String> {
    let base = env::var_os("LOCALAPPDATA")
        .map(PathBuf::from)
        .ok_or("找不到 %LOCALAPPDATA%")?;
    Ok(base.join("manimgl-portable").join(VERSION))
}

fn extract(zip_bytes: &[u8], target: &Path) -> Result<(), String> {
    fs::create_dir_all(target).map_err(|e| format!("建目录失败: {e}"))?;
    let mut archive = zip::ZipArchive::new(Cursor::new(zip_bytes))
        .map_err(|e| format!("解析内嵌 zip 失败: {e}"))?;
    let n = archive.len();
    for i in 0..n {
        let mut f = archive.by_index(i).map_err(|e| format!("读取第 {i} 项失败: {e}"))?;
        let rel = match f.enclosed_name() {
            Some(p) => p.to_path_buf(),
            None => continue, // 不安全的路径，跳过
        };
        let out = target.join(&rel);
        if f.is_dir() {
            fs::create_dir_all(&out).map_err(|e| format!("建目录 {} 失败: {e}", out.display()))?;
            continue;
        }
        if let Some(parent) = out.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("建目录失败: {e}"))?;
        }
        let mut w = fs::File::create(&out)
            .map_err(|e| format!("创建 {} 失败: {e}", out.display()))?;
        io::copy(&mut f, &mut w).map_err(|e| format!("写入 {} 失败: {e}", out.display()))?;
        if i % 2000 == 0 {
            print!("\r  解包中 {i}/{n} ...");
            let _ = io::stdout().flush();
        }
    }
    println!("\r  解包完成（{n} 个文件）          ");
    Ok(())
}

fn pause() {
    print!("按回车键关闭 ...");
    let _ = io::stdout().flush();
    let mut s = String::new();
    let _ = io::stdin().read_line(&mut s);
}
