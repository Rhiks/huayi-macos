<div align="center">
  <img src="docs/assets/huayi-social-preview.png" width="100%" alt="Huayi 划译：原生 macOS 划词翻译">
  <br><br>
  <p>
    <a href="https://github.com/Rhiks/huayi-macos/actions/workflows/ci.yml"><img src="https://github.com/Rhiks/huayi-macos/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
    <img src="https://img.shields.io/badge/macOS-13%2B-black" alt="macOS 13+">
    <img src="https://img.shields.io/badge/Swift-5.9%2B-orange" alt="Swift 5.9+">
    <a href="https://github.com/Rhiks/huayi-macos/stargazers"><img src="https://img.shields.io/github/stars/Rhiks/huayi-macos?style=flat&logo=github" alt="GitHub Stars"></a>
  </p>
  <p>
    <a href="#快速安装">快速安装</a> ·
    <a href="#翻译模式">翻译模式</a> ·
    <a href="#启用本地-translategemma-12b">本地 AI</a> ·
    <a href="#隐私">隐私</a> ·
    <a href="#分享-huayi">宣传素材</a>
  </p>
</div>

**划到哪，翻到哪。**

学英语时随手查词、看短句、听发音；读 Paper 时翻术语、复杂句和长段落。在浏览器、PDF 阅读器和代码编辑器等可选文字场景里，Huayi 让你留在原文，不必复制、切换、粘贴再回来。

划选文字后，鼠标附近只出现一个 18×18 的小触点。需要译文时悬停展开，不需要时尽量少挡正文。短句快速返回，长文和技术语境可以交给本机 AI 模型 TranslateGemma 12B 流式处理。

<p align="center">
  <a href="#快速安装"><strong>从源码安装 Huayi →</strong></a>
  &nbsp;·&nbsp;
  <a href="#隐私">先看数据会发到哪里</a>
</p>

> 当前版本需要从源码安装。仓库暂不提供未经苹果公证的通用安装包。

## 学英语、读 Paper，留在原文里理解

| 学英语 | 读 Paper | 随手划译 |
| --- | --- | --- |
| 遇到生词或不熟悉的表达，划一下看译文，并用系统语音听发音。 | 技术术语、复杂句和长段落可交给本机 TranslateGemma 12B，译文边生成边显示。 | 浏览器、PDF 阅读器和代码编辑器等可选文字场景都能使用，译文面板不主动抢键盘焦点。 |

### 为什么用起来顺手

- **自动**、**极速**、**AI 精译**三种模式。
- 明确选择 **AI 精译** 时，正文只发给本机 Ollama，不静默回退到在线服务。
- 长文面板支持滚动；用户回看前文时，流式结果不会强行把视图拉回底部。
- 系统 Siri Natural 语音本机朗读；可选 Microsoft Neural 在线语音。
- Option+Q 快捷模式，适合代码编辑器等容易误触的界面。
- 临时读取剪贴板后安全恢复；不会覆盖其间由用户或其他应用写入的新内容。
- 发布构建无分析遥测，也不会记录选中文本。

## 三步完成一次翻译

1. **划选**：在正在阅读的页面里选中单词、句子或段落。
2. **悬停**：鼠标移到附近的 18×18 触点，展开译文。
3. **继续读**：查看或滚动译文，需要时朗读；原应用仍留在原来的工作位置。

## 系统要求

- macOS 13 Ventura 或更高版本。
- Swift 5.9+ 与 Xcode Command Line Tools。
- 基础在线翻译不需要额外运行时。
- 本地 AI 推荐 Apple Silicon；TranslateGemma 12B 约占 8 GB 磁盘，并需要数 GB 统一内存。

本项目主要在 Apple Silicon 上测试。Intel Mac 可以从源码尝试构建，但本地 12B 模型的速度和内存占用未作为支持目标验证。

## 快速安装

~~~bash
git clone https://github.com/Rhiks/huayi-macos.git
cd huayi-macos
chmod +x install.sh uninstall.sh script/build_and_run.sh
./install.sh
~~~

首次运行时，在：

~~~text
系统设置 → 隐私与安全性 → 辅助功能
~~~

允许 **Huayi**。这是读取其他应用当前选区和发送临时复制快捷键所必需的权限。

如果刚授权后仍无法触发，请从菜单栏退出 Huayi，再运行一次 ./install.sh。

## 翻译模式

| 模式 | 默认数据路径 | 适合场景 |
| --- | --- | --- |
| 自动 | 短文本走 Google；长文和部分技术专名走本机 Ollama；本地 AI 不可用时可在线回退 | 日常使用 |
| 极速 | 文本通过 HTTPS POST 发往 Google 的非公开翻译端点 | 单词、短句、低延迟 |
| AI 精译 | 只访问 127.0.0.1:11434，不在线回退 | 敏感文本、长文、技术语境 |

自动模式的 AI 阈值目前为 320 个字符；OpenTelemetry 一类驼峰技术专名也会优先路由到本机 AI。

Google 路径使用的是未文档化端点，可能随时变化，也不应被理解为 Google 官方 SDK 或可用性承诺。

## 启用本地 TranslateGemma 12B

~~~bash
brew install ollama
brew services start ollama
ollama pull translategemma:12b
~~~

Huayi 会在菜单栏显示模型状态，并在 **自动** 或 **AI 精译** 模式下预热模型。模型权重不包含在本仓库中，使用时需遵守 [Gemma Terms](https://ai.google.dev/gemma/terms)。

## 语音

默认美音路径调用 macOS 已配置的系统 Siri Natural 语音，不固定强制某个声音。若希望使用 Quinn，可在 macOS 的“朗读内容/系统声音”设置中把美式英语声音改为 Quinn。

菜单中也可以启用 Microsoft Neural 在线语音；此模式需要安装 edge-tts：

~~~bash
uv tool install edge-tts
~~~

在线 Neural 会把待朗读文本发送给 Microsoft。网络失败时 Huayi 回退到系统语音。

## 隐私

Huayi 不包含分析 SDK。发布构建默认不写行为日志，选中文本不会写入磁盘缓存或 Unified Log。在线功能仍会把正文发送给相应服务：

- **极速**以及**自动**模式的部分请求：Google。
- **AI 精译**：本机 Ollama。
- 可选 Neural 语音：Microsoft。
- 系统语音：英语使用本机 /usr/bin/say，其他语言使用 AVSpeechSynthesizer。

完整的数据流、剪贴板行为和临时文件说明见 [PRIVACY.md](PRIVACY.md)。

## 本地开发

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

本机已安装 Ollama 和模型时，可运行真实流式集成测试：

~~~bash
"$BIN" --ai-self-test
~~~

## 卸载

~~~bash
./uninstall.sh
~~~

卸载脚本会把应用移动到废纸篓，不会删除 Ollama 模型或 macOS 权限记录。

## 参与贡献

提交改动前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。

## 分享 Huayi

以下内容可以直接复制发布。涉及在线服务、模型和安装方式的表述均与当前版本一致。

### 素材文件

| 用途 | 文件 | 规格 |
| --- | --- | --- |
| GitHub Social Preview、横版头图 | [`docs/assets/huayi-social-preview.png`](docs/assets/huayi-social-preview.png) | 1280×640 PNG |
| 应用图标、方形头像 | [`Assets/HuayiIcon-1024.png`](Assets/HuayiIcon-1024.png) | 1024×1024 PNG |

GitHub 仓库头图可在 `Settings → General → Social preview → Edit` 中上传。

<details>
<summary><strong>一句话、超短版与 GitHub About</strong></summary>

**一句话介绍**

Huayi 是一款原生 macOS 划词翻译工具：学英语时随手查词和听发音，读 Paper 时翻术语与长段落，在浏览器、PDF 阅读器和代码编辑器里划到哪翻到哪。

**超短版**

学英语、读 Paper，划到哪翻到哪。原生 macOS 划词翻译，支持本机 TranslateGemma 12B 流式精译。

**GitHub About**

学英语、读 Paper，划到哪翻到哪：原生 macOS 划词翻译，支持系统发音和本机 TranslateGemma 12B 流式精译。

**GitHub About — English**

Learn English and read papers without leaving the page. Native macOS selection translation with system speech and local TranslateGemma 12B streaming.

</details>

<details>
<summary><strong>通用短帖</strong></summary>

Huayi 开源了，一个用 Swift + AppKit 写的原生 macOS 划词翻译工具。

学英语遇到生词，划一下就能看译文、听发音；读 Paper 碰到术语和复杂长句，可以交给本机 TranslateGemma 12B 流式处理。浏览器、PDF 阅读器和代码编辑器里，不用复制到另一个页面，划到哪翻到哪。

划选文字后，鼠标附近只出现一个 18×18 的小触点；需要翻译时悬停展开，不需要时尽量少挡正文。

项目没有 Electron，也不带分析遥测。明确选择 AI 精译时，正文只发给本机 Ollama，不会静默切到在线服务。

源码与安装说明：https://github.com/Rhiks/huayi-macos

</details>

<details>
<summary><strong>微博 / X 短版</strong></summary>

学英语、读 Paper，不用再把文字复制到另一个页面。Huayi 是一个原生 macOS 划词翻译工具：划一下看译文、听发音，术语和长段落可交给本机 TranslateGemma 12B。浏览器、PDF、编辑器里划到哪翻到哪。https://github.com/Rhiks/huayi-macos

</details>

<details>
<summary><strong>小红书标题、正文与标签</strong></summary>

**标题备选**

1. Mac 读 Paper，不用再复制粘贴翻译了
2. 学英语时划一下就翻译，还能直接听发音
3. 做了一个划到哪翻到哪的 macOS 开源工具

**正文**

最近把自己用来学英语、读 Paper 的 macOS 划词翻译工具整理开源了，名字叫 Huayi。

遇到生词或不熟悉的表达，划一下就能看译文，也能直接听系统发音。读论文碰到术语、复杂句或一整段文字，可以交给本机 TranslateGemma 12B，译文会边生成边显示。浏览器、PDF 阅读器和代码编辑器里都不用来回复制粘贴。

它的交互很简单：划选文字后不会立刻弹出一大块窗口，只在鼠标附近出现一个 18×18 的小触点。想看译文就把鼠标移上去，不想看时它尽量不挡正文，也不会主动抢走键盘焦点。

短词短句可以走快速翻译；长文和技术语境可以走本机 AI。长文面板支持滚动，明确切到 AI 精译后，正文只会发到本机 Ollama，不会悄悄改走在线服务。

项目用 Swift + AppKit 编写，没有 Electron，也没有分析遥测。当前需要从源码安装，支持 macOS 13 及以上版本；本机 12B 模型更推荐 Apple Silicon。

GitHub：Rhiks/huayi-macos

**标签**

`#macOS` `#学英语` `#论文阅读` `#效率工具` `#翻译工具` `#开源软件` `#本地AI` `#Ollama` `#TranslateGemma`

</details>

<details>
<summary><strong>V2EX / 少数派 / 掘金长版</strong></summary>

**标题**

Huayi：学英语、读 Paper，划到哪翻到哪的 macOS 开源工具

**正文**

学英语或读 Paper 时，查一个词、确认一句话、看懂一段复杂论述，都是零碎但频繁的需求。复制、切换页面、粘贴、再回到原文，会不断打断阅读节奏。Huayi 把翻译入口留在正在阅读的文字旁边，让这些查询尽量一次完成。

划选后先显示一个 18×18 的小触点，悬停才展开译文。查词和短句时可以快速返回，并用系统语音朗读；论文术语、复杂句和长段落可以交给本机 TranslateGemma 12B 流式翻译。长文支持滚动，用户回看前文时，面板不会强行把视图拉回底部。

翻译分为自动、极速和 AI 精译三种模式。AI 精译只连接 `127.0.0.1:11434` 的 Ollama，不做静默在线回退；自动和极速模式会按 README 中说明的数据路径访问在线翻译服务。项目不包含分析 SDK，发布构建也不记录选中的正文。

目前仓库以源码为主，没有分发未经公证的安装包。欢迎试用、提 Issue 或参与改进。

项目地址：https://github.com/Rhiks/huayi-macos

</details>

<details>
<summary><strong>English post</strong></summary>

Huayi is now open source — a native macOS tool for learning English and reading papers without leaving the page.

Select a word or sentence to see its translation and hear the system pronunciation. Technical terms and longer passages can stream through a local TranslateGemma 12B model. It works wherever text is selectable across browsers, PDF readers, and editors, while the small hover target keeps the original content visible.

No Electron and no analytics telemetry. Explicit AI mode stays on the local Ollama endpoint and never silently falls back online.

https://github.com/Rhiks/huayi-macos

</details>

### 截图拍摄清单

发布帖子建议配 3～4 张真实截图：

1. 英语文章中划选生词后出现 18×18 小触点。
2. 悬停后显示译文与朗读入口，画面同时保留英文原文。
3. TranslateGemma 12B 正在流式翻译一段 Paper 内容。
4. 菜单栏中的三种翻译模式、语音和模型状态。

截图前请清理浏览器标签、账号头像、文件路径、通知和选区中的个人信息。不要用模拟界面冒充真实运行效果。

### 发布顺序

1. 在 GitHub 仓库设置 Social Preview 图。
2. 发布一条带横版头图的短帖。
3. 小红书使用 3～4 张真实运行截图，首图可将横版头图裁成 4:3。
4. V2EX、少数派或掘金使用长版说明，并明确当前需要源码安装及在线数据边界。
5. 收集 Issue 后再发布带签名、公证和自动更新的正式安装包。

### 推荐 Topics

~~~text
macos
swift
appkit
menu-bar-app
translation
selection-translation
local-ai
ollama
translategemma
text-to-speech
apple-silicon
language-learning
pdf-translation
research-papers
~~~

### 宣传边界

- 不写“完全离线”：自动和极速模式会访问在线服务。
- 不写“官方 Google 翻译”：当前使用的是未文档化端点。
- 不写“永久免费无限”：第三方服务可能限流、变更或停止。
- 不写“强制 Quinn 音质”：默认跟随用户的系统 Siri Natural 配置。
- 不写“通用已签名安装包”：当前没有 Developer ID 公证发行物。
- 不写“零权限”：划词读取和临时复制需要 macOS 辅助功能权限。

## 第三方与许可证

Huayi 源码以 [MIT License](LICENSE) 开源。Ollama、TranslateGemma、Gemma 权重和 edge-tts 是未捆绑的第三方组件，各自适用独立条款；详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

本项目与 Apple、Google、Microsoft、Ollama 均无隶属、赞助或背书关系。
