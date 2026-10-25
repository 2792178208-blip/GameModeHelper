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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in execProgram() }
    }

    private func execProgram() {
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
        fputs("GameStubRunner: 无法启动 \(program)（exec 失败，errno=\(errno)）\n", stderr)
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
    let app = NSApplication.shared
    let delegate = StubDelegate(cfg: cfg)
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.activate(ignoringOtherApps: true)
    app.run()
}
