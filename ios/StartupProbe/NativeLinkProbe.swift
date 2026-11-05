import SwiftUI
import UIKit

@main
struct NativeLinkStartupProbe: App {
    @State private var result = "引擎尚未调用"
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                Text("C++/Metal 链接测试").font(.title2.weight(.semibold))
                Text("看到本页，说明包含 C++ 引擎的可执行文件已成功启动。")
                Text("系统：iOS " + UIDevice.current.systemVersion)
                Text(result)
                Button("读取本地引擎错误字符串") {
                    // This C ABI symbol forces the native library to be linked.
                    // It must not create a Metal device or load film resources.
                    result = String(cString: spk_last_error(nil))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
