<div align="center">
  <img src="docs/assets/huayi-social-preview.png" width="100%" alt="Huayi 划译：原生 macOS 划词翻译">

  <h1>Huayi 划译</h1>

  <p><strong>划到哪，翻到哪。</strong></p>
  <p>为英语学习、Paper 阅读和技术资料而做的原生 macOS 划词翻译工具。</p>

  <p>
    <a href="https://github.com/Rhiks/huayi-macos/actions/workflows/ci.yml"><img src="https://github.com/Rhiks/huayi-macos/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2563EB.svg" alt="MIT License"></a>
    <img src="https://img.shields.io/badge/macOS-26%2B-111827?logo=apple" alt="macOS 26+">
    <img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white" alt="Swift 5.9+">
    <a href="https://github.com/Rhiks/huayi-macos/stargazers"><img src="https://img.shields.io/github/stars/Rhiks/huayi-macos?style=flat&logo=github&color=7C3AED" alt="GitHub Stars"></a>
  </p>

  <p>
    <a href="#-快速安装"><strong>快速安装</strong></a>
    · <a href="#-三种翻译模式">翻译模式</a>
    · <a href="#-apple-translation">Apple Translation</a>
    · <a href="#-隐私与数据路径">隐私说明</a>
    · <a href="docs/PROMOTION.md">宣传素材</a>
  </p>
</div>

---

选中文字后，鼠标附近只出现一个 **18×18** 的小触点。需要译文时悬停展开，不需要时尽量少挡正文。单词、论文术语、复杂句和长段落默认交给 macOS **Apple Translation** 本机处理。

<p align="center">
  <kbd>划选文字</kbd>
  &nbsp;→&nbsp;
  <kbd>出现 18×18 触点</kbd>
  &nbsp;→&nbsp;
  <kbd>悬停查看译文</kbd>
  &nbsp;→&nbsp;
  <kbd>留在原文继续读</kbd>
</p>

<p align="center">
  <a href="#-快速安装"><strong>下载 Huayi Preview →</strong></a>
  &nbsp;&nbsp;·&nbsp;&nbsp;
  <a href="PRIVACY.md">先看完整隐私说明</a>
</p>

> [!IMPORTANT]
> Release 页面提供通用预编译 Preview，但目前只有 ad-hoc 本地签名，尚未经过 Apple Developer ID 签名与公证。正式可信分发仍需要开发者证书与公证条件。

## ✨ 为什么是 Huayi

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🔎 少打断</h3>
      <p>先显示小触点，悬停才展开译文。查完继续读，不必复制、切换应用、粘贴再返回。</p>
    </td>
    <td width="50%" valign="top">
      <h3>🍎 Apple 本机翻译</h3>
      <p>直接使用 macOS Translation 框架和系统语言包，不需要 Ollama，不常驻 12B，也不用等待大模型冷启动。</p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🪶 不主动抢焦点</h3>
      <p>译文使用非激活面板，尽量保留原应用的键盘焦点；Option+Q 模式还能减少代码编辑器里的误触。</p>
    </td>
    <td width="50%" valign="top">
      <h3>🔐 数据路径透明</h3>
      <p>默认翻译由 Apple Translation 在本机完成；Google 只作为自动失败回退或手动选择的在线备用。</p>
    </td>
  </tr>
</table>

## 📚 用在你真正阅读的地方

| 学英语 | 读 Paper | 看技术资料 |
| :---: | :---: | :---: |
| 随手查词、理解短句，再用系统语音听发音。 | 翻译术语、复杂句和长段落，长文结果支持滚动回看。 | 在浏览器、PDF 阅读器和代码编辑器中理解文档、注释与报错。 |

### 阅读体验里的小细节

- **自动、在线备用、Apple 本机**三种模式，默认始终优先系统本机翻译。
- 不加载 TranslateGemma 12B；`OpenTelemetry` 一类技术词和长段落使用同一条低延迟系统链路。
- 长文面板支持滚动，译文会一直保留到主动点击外部区域。
- 使用 macOS 系统 Siri Natural 语音本机朗读，也可选 Microsoft Neural 在线语音。
- 临时读取剪贴板后安全恢复，不覆盖其间由用户或其他应用写入的新内容。
- 发布构建无分析遥测，也不会记录选中文本。

## 🚀 快速安装

### 系统要求

- macOS 26 或更高版本。
- Swift 5.9+ 与 Xcode Command Line Tools。
- Apple Translation 英→简中语言包（本机已安装即可直接使用）。
- 不需要 Ollama、模型权重或额外后台服务。

> [!NOTE]
> 当前版本按作者自己的 macOS 26 设备优化，直接使用系统 Translation 框架。

### 下载预编译 Preview

不想在本机编译，可以前往 [Releases](https://github.com/Rhiks/huayi-macos/releases) 下载最新的通用 DMG，拖入 Applications 后运行。包同时包含 Apple Silicon 与 Intel 架构。

> [!WARNING]
> 当前 Preview 尚未公证。macOS 可能阻止首次直接打开；请确认文件来自本仓库，然后在 Finder 中右键 **Huayi → 打开**。这不是受 Gatekeeper 无提示信任的正式发行包。

### 从源码安装

~~~bash
git clone https://github.com/Rhiks/huayi-macos.git
cd huayi-macos
chmod +x install.sh uninstall.sh script/build_and_run.sh
./install.sh
~~~

首次运行后，前往：

~~~text
系统设置 → 隐私与安全性 → 辅助功能
~~~

允许 **Huayi**。这项权限用于读取其他应用的当前选区，以及发送临时复制快捷键。

如果刚授权后仍无法触发，请从菜单栏退出 Huayi，再运行一次 `./install.sh`。

## 🎛️ 三种翻译模式

| 模式 | 数据路径 | 更适合 |
| :---: | --- | --- |
| **自动** | 优先 Apple Translation 本机处理；系统语言包不可用时回退 Google | 日常阅读，无需反复切换 |
| **在线备用** | 文本通过 HTTPS POST 发往 Google 的非公开翻译端点 | 手动排查或比较译文 |
| **Apple 本机** | 只使用 macOS Translation 框架，不在线回退 | 敏感文本、长文、技术语境 |

自动模式不再按字符数或语义复杂度分流。Apple Translation 足够轻量，短词和长文都直接走同一条本机路径；只有系统翻译失败时，自动模式才使用 Google 备用。

> [!WARNING]
> Google 路径使用未文档化端点，可能随时变化，也不代表 Google 官方 SDK 或可用性承诺。

## 🍎 Apple Translation

Huayi 直接调用 macOS 26 的 Translation 框架。菜单栏会显示英→简中语言包状态；语言包安装后，翻译完全由系统在本机完成。它由 macOS 管理资源回收，不需要 Huayi 常驻一个独立大模型进程。

## 🔊 语音

默认美音路径调用 macOS 当前配置的系统 Siri Natural 语音，不固定强制某个声音。若希望使用 Quinn，可在 macOS 的“朗读内容 / 系统声音”设置中，把美式英语声音改为 Quinn。

菜单中也可以启用 Microsoft Neural 在线语音。此模式需要安装 `edge-tts`：

~~~bash
uv tool install edge-tts
~~~

在线 Neural 会把待朗读文本发送给 Microsoft；网络失败时，Huayi 会回退到系统语音。

## 🔐 隐私与数据路径

Huayi 不包含分析 SDK。发布构建默认不写行为日志，选中文本不会写入磁盘缓存或 Unified Log。

| 功能 | 文本会去哪里 |
| --- | --- |
| 自动、Apple 本机 | Apple Translation；仅自动模式失败时可能回退 Google |
| 在线备用 | Google |
| 可选 Neural 语音 | Microsoft |
| 系统语音 | 英语使用本机 `/usr/bin/say`，其他语言使用 `AVSpeechSynthesizer` |

完整的数据流、剪贴板行为和临时文件说明见 [PRIVACY.md](PRIVACY.md)。

## 🛠️ 本地开发

<details>
<summary><strong>展开构建与测试命令</strong></summary>

构建并启动：

~~~bash
./script/build_and_run.sh
~~~

构建并做启动验证：

~~~bash
./script/build_and_run.sh --verify
~~~

运行无需网络的回归测试：

~~~bash
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Huayi"
"$BIN" --filter-self-test
"$BIN" --routing-self-test
"$BIN" --clipboard-self-test
~~~

运行 Apple Translation 真实集成测试：

~~~bash
"$BIN" --ai-self-test
~~~

</details>

## 🧹 卸载

~~~bash
./uninstall.sh
~~~

卸载脚本会把应用移动到废纸篓，不会删除 macOS 系统语言包或权限记录。

## 🤝 参与贡献

提交改动前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。

如果 Huayi 对你的阅读有帮助，欢迎：

- 为仓库点一颗 Star，让更多英语学习者和 Paper 阅读者找到它。
- 提交 Issue，说明无法触发、翻译路由或长文体验中的具体问题。
- 参与代码、文档和兼容性改进。

需要介绍或分享 Huayi 时，可直接使用 [宣传素材包](docs/PROMOTION.md)，其中包含短帖、长帖和平台化文案。

<details>
<summary><strong>为什么暂时没有 Homebrew Cask 和自动更新？</strong></summary>

当前仓库还没有 Developer ID 签名与 Apple 公证条件。此时加入 Cask 并不能消除 Gatekeeper 提示，也容易让用户误以为安装包已被系统信任。Sparkle 自动更新还需要独立更新签名和稳定发布源。

现阶段先提供可校验哈希的预编译 Preview；完成 Developer ID 签名、公证和稳定发布后，再接入 Homebrew Cask 与自动更新更合适。

</details>

## ⚖️ 第三方与许可证

Huayi 源码以 [MIT License](LICENSE) 开源。Apple 系统框架、Google 在线备用和可选的 edge-tts 各自适用独立条款；详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

本项目与 Apple、Google、Microsoft 均无隶属、赞助或背书关系。
