import SwiftUI
import UIKit

@main
struct SpectralStartupProbeApp: App {
    @State private var count = 0
    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 16) {
                Text("SwiftUI 启动成功")
                    .font(.title.bold())
                Text("这是不包含照片处理、Metal、C++ 引擎的最小程序。")
                Text("系统：" + UIDevice.current.systemVersion)
                Button("交互测试：" + String(count)) {
                    count += 1
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
    }
}
