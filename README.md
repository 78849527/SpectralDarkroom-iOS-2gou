# Spectral Darkroom for iPhone

这是一个面向 iPhone 的**非官方实验性移植**，不是 SpektraLab 桌面版的完整移植，也不代表原项目发布的 iOS 版本。

## 原项目与来源

- 直接移植来源：[JamesQiu2005/SpektraLab](https://github.com/JamesQiu2005/SpektraLab)，由 Hanze Qiu 开发的 macOS 胶片与相纸模拟器。本项目复用了其中的 C++/Metal 渲染引擎及部分资源，并重新编写了适用于 iPhone 的 SwiftUI 界面和构建脚本。
- 更早的胶片过程模型、胶片与相纸配置及印相 LUT 来源：[andreavolpato/spektrafilm](https://github.com/andreavolpato/spektrafilm)，作者 Andrea Volpato。SpektraLab 本身基于该项目进行原生 C++/Metal 移植。

感谢两位原作者及相关贡献者。本仓库与上述项目没有官方关联；名称 **Spectral Darkroom** 用于区分该 iPhone 原型与 SpektraLab 桌面产品。

## 当前范围

- iOS 18 及以上，面向 arm64 iPhone。
- 从系统照片选择器导入图片，选择部分胶片与相纸，预览效果，并通过系统分享界面导出 Display P3 JPEG。
- 导入图片的长边目前限制为 4096 像素。尚未覆盖桌面版的完整编辑流程和色彩管理选项，真机渲染结果仍需继续验证。

## 构建

在安装了 Xcode 和 iOS SDK 的 Apple 芯片 Mac 上运行：

```sh
./ios/build-iphone.sh /path/to/output-directory
```

脚本生成 `SpectralDarkroom-unsigned.ipa`，采用 ad-hoc 签名，**不能直接安装到 iPhone**。安装前需要使用自己的 Apple 开发团队和适当的描述文件重新签名。若 Xcode 的 Metal Toolchain 不可用，构建会打包 MSL 源码供运行时编译；该路径需要在真机上验证。构建细节见 [ios/README.md](ios/README.md)。

本仓库只公开源码与构建所需资源，不包含签名 IPA、开发证书、描述文件或私人会话记录。

## 许可与致谢

- 应用及 C++/Metal 引擎：[GPL-3.0-or-later](LICENSE.txt)。
- 胶片与相纸配置、印相 LUT：来自 `spektrafilm`，采用 [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)。
- Apple `metal-cpp` 头文件：[Apache-2.0](engine/third_party/metal-cpp/LICENSE.txt)。

详细来源及限制见 [iOS 应用声明](ios/SpectralDarkroom/NOTICE.md) 和原项目的许可说明。SpektraLab 的名称与图标不包含在上述代码和数据许可中；本项目不使用其应用图标。
