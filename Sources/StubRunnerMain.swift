import AppKit

/// 游戏模式启动器（替身 App）的主程序。
///
/// 原理（GameStub 模式，参考 CeciliaStudio/MinecraftGameStub）：
/// 替身 App 自带游戏模式声明；本程序以 App 身份启动后被系统识别为游戏，
/// 随后把进程镜像替换（execv）为真正的游戏程序——PID 不变，游戏天生继承
/// 本 bundle 的游戏身份。适用于 Java/jar、裸可执行程序等没有 App 包的程序。
///
/// 配置文件：本 bundle 的 Contents/config.json
///   {"program": "…", "args": ["…"], "cwd": "…", "passthrough": false}
/// passthrough=true 时忽略 args，把启动本程序时收到的参数原样透传（HMCL 等
/// 启动器以"自定义 Java 路径"方式调用本程序的场景，实验性）。

/// 注册期保存的真实 stderr（恢复用）
var savedStderr: Int32 = -1

struct StubConfig: Codable {
    let program: String
    var args: [String] = []
    var cwd: String?
    var passthrough: Bool = false
}

final class StubDelegate: NSObject, NSApplicationDelegate {
    let cfg: StubConfig
    init(cfg: StubConfig) { self.cfg = cfg; super.init() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let cwd = cfg.cwd, !cwd.isEmpty {
            _ = FileManager.default.changeCurrentDirectoryPath(cwd)
        }
        // 给 LaunchServices/游戏策略一点注册时间，再把进程镜像替换为游戏本体
        //（透传模式下启动器探测 Java 也会经过这里，0.5s 对探测无感知）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in execProgram() }
    }

    private func execProgram() {
        // 恢复真实 stderr 再 exec，让启动器/终端能看到游戏输出
        if savedStderr != -1 { dup2(savedStderr, STDERR_FILENO); close(savedStderr) }
        let program = cfg.program
        let argList: [String]
        if cfg.passthrough {
            // 透传模式：argv[0] 起就是目标程序需要的参数（java -Xmx… 等）
            argList = Array(CommandLine.arguments.dropFirst())
        } else {
            argList = cfg.args
        }

        var argv: [UnsafeMutablePointer<CChar>?] = [strdup(program)]
        for a in argList { argv.append(strdup(a)) }
        argv.append(nil)

        execv(program, &argv)
        // 只有 exec 失败才会走到这里
        let reason = errno == ENOENT ? "程序不存在" : errno == EACCES ? "没有执行权限" : "errno=\(errno)"
        fputs("GameStubRunner: 无法启动 \(program)（\(reason)）。\n"
              + "透传模式请检查 config.json 里 program 指向的 Java 是否有效。\n", stderr)
        exit(127)
    }
}

// 入口
let cfgResult: Result<StubConfig, Error>
do {
    let cfgURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        .appendingPathComponent("Contents/config.json")
    let data = try Data(contentsOf: cfgURL)
    cfgResult = .success(try JSONDecoder().decode(StubConfig.self, from: data))
} catch {
    cfgResult = .failure(error)
}

switch cfgResult {
case .failure(let err):
    fputs("GameStubRunner: 读取 config.json 失败——\(err)\n", stderr)
    exit(1)
case .success(let cfg):
    // 注册期静音 stderr：直接拉起（不经 LaunchServices）时 AppKit 会输出
    // "sandbox_extension_issue_file_to_process" 噪音，会污染启动器的 Java 版本解析。
    // execv 前在 execProgram 里恢复，真实程序的输出不受影响。
    savedStderr = dup(STDERR_FILENO)
    let devnull = open("/dev/null", O_WRONLY)
    if devnull != -1 { dup2(devnull, STDERR_FILENO); close(devnull) }

    let app = NSApplication.shared
    let delegate = StubDelegate(cfg: cfg)
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.activate(ignoringOtherApps: true)
    app.run()
}
