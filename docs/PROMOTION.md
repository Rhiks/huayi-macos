# Huayi 宣传素材包

这份文件里的文案可以直接复制发布。涉及在线服务、模型和安装方式的表述均与当前版本一致。

![Huayi 社交预览图](assets/huayi-social-preview.png)

## 素材文件

| 用途 | 文件 | 规格 |
| --- | --- | --- |
| GitHub Social Preview、横版头图 | [`docs/assets/huayi-social-preview.png`](assets/huayi-social-preview.png) | 1280×640 PNG |
| 应用图标、方形头像 | [`Assets/HuayiIcon-1024.png`](../Assets/HuayiIcon-1024.png) | 1024×1024 PNG |

GitHub 仓库头图需要在仓库的 `Settings → General → Social preview → Edit` 中上传，推荐直接使用上面的 1280×640 文件。

## 核心信息

- 名称：Huayi 划译
- 类型：原生 macOS 菜单栏划词翻译工具
- 技术：Swift、AppKit、Ollama、TranslateGemma 12B
- 交互：划选后显示 18×18 触点，悬停展开译文
- 翻译：自动、极速、AI 精译三种模式
- 本地 AI：TranslateGemma 12B 流式输出，适合长文和技术语境
- 阅读体验：译文面板不主动抢键盘焦点，长文可滚动
- 语音：macOS 系统语音；可选 Microsoft Neural 在线语音
- 隐私：没有分析遥测；AI 精译只访问本机 Ollama，不静默在线回退
- 当前发布方式：源码构建，macOS 13+，本地 AI 推荐 Apple Silicon
- 项目地址：https://github.com/Rhiks/huayi-macos

## 一句话介绍

Huayi 是一款原生 macOS 划词翻译工具：划选后出现轻量触点，悬停查看译文；短句快速翻译，长文和技术术语可交给本机 TranslateGemma 12B 流式处理。

## 超短版

原生 macOS 划词翻译，支持轻量悬停触发和本机 TranslateGemma 12B 流式精译。

## GitHub About

原生 macOS 划词翻译：18×18 悬浮触点、本机 TranslateGemma 12B 流式精译、快速在线翻译和系统语音朗读。

## GitHub About（英文）

Native macOS selection translator with a hover UI, local TranslateGemma 12B streaming, fast online translation, and system speech.

## 通用短帖

Huayi 开源了，一个用 Swift + AppKit 写的原生 macOS 划词翻译工具。

划选文字后，鼠标附近只出现一个 18×18 的小触点；需要翻译时悬停展开，不需要时尽量少挡正文。短词短句可以快速翻译，长文、代码术语和 OpenTelemetry 这类专名可以交给本机 TranslateGemma 12B 流式处理。

项目没有 Electron，也不带分析遥测。明确选择 AI 精译时，正文只发给本机 Ollama，不会静默切到在线服务。

源码与安装说明：https://github.com/Rhiks/huayi-macos

## 微博 / X 短版

开源了一个原生 macOS 划词翻译工具 Huayi。划选后只显示 18×18 小触点，悬停展开译文，不主动抢键盘焦点；支持本机 TranslateGemma 12B 流式精译、长文滚动和系统语音。Swift + AppKit，无 Electron。https://github.com/Rhiks/huayi-macos

## 小红书

### 标题备选

1. 我把 macOS 划词翻译做成了 18×18 的小触点
2. 开源一个不抢焦点的 macOS 划词翻译工具
3. 本机 12B 模型做划词翻译，Huayi 开源了

### 正文

最近把自己一直在用的 macOS 划词翻译工具整理开源了，名字叫 Huayi。

它的交互很简单：划选文字后不会立刻弹出一大块窗口，只在鼠标附近出现一个 18×18 的小触点。想看译文就把鼠标移上去，不想看时它尽量不挡正文，也不会主动抢走键盘焦点。

短词短句可以走快速翻译；长文、代码里的驼峰词和技术术语可以交给本机 TranslateGemma 12B。AI 译文是流式出来的，长文面板可以滚动，旧请求也能及时取消。明确切到 AI 精译后，正文只会发到本机 Ollama，不会悄悄改走在线服务。

项目用 Swift + AppKit 编写，没有 Electron，也没有分析遥测。目前是 source-first 版本，需要从源码安装，macOS 13+ 可用，本地 12B 模型更推荐 Apple Silicon。

GitHub：Rhiks/huayi-macos

### 标签

`#macOS` `#开源软件` `#效率工具` `#翻译工具` `#Swift` `#AppKit` `#本地AI` `#Ollama` `#TranslateGemma`

## V2EX / 少数派 / 掘金

### 标题

Huayi：一个轻量、不抢焦点的原生 macOS 划词翻译工具

### 正文

Huayi 起初是为了解决一个很具体的问题：划词翻译很方便，但结果窗口常常比原文更抢眼，写代码或阅读长文时还容易打断键盘操作。

现在的交互是，划选后先显示一个 18×18 的小触点，悬停才展开译文。译文面板使用原生 AppKit，不主动成为主窗口；短文本保持低延迟，长文和技术术语则可以交给本机 TranslateGemma 12B 流式翻译。长文支持滚动，流式过程中如果用户自己翻到前面，面板也不会强行把视图拉回底部。

翻译分为自动、极速和 AI 精译三种模式。AI 精译只连接 `127.0.0.1:11434` 的 Ollama，不做静默在线回退；自动和极速模式会按 README 中说明的数据路径访问在线翻译服务。项目不包含分析 SDK，发布构建也不记录选中的正文。

目前仓库以源码为主，没有分发未经公证的安装包。欢迎试用、提 Issue 或参与改进。

项目地址：https://github.com/Rhiks/huayi-macos

## 英文短帖

Huayi is now open source — a native macOS selection translator built with Swift and AppKit.

Select text to reveal a tiny 18×18 hover target, then move over it only when you want the translation. Huayi supports fast online translation, local TranslateGemma 12B streaming through Ollama, scrollable long-form results, and system speech without actively stealing keyboard focus.

No Electron and no analytics telemetry. Explicit AI mode stays on the local Ollama endpoint and never silently falls back online.

https://github.com/Rhiks/huayi-macos

## README / 发布页长版

Huayi 想减少划词翻译对阅读节奏的打断。划选文字后，界面先显示一个很小的触点；只有鼠标悬停时才展开译文。这样既保留了随手翻译的速度，也不会让结果窗口一直盖住正文。

应用使用 Swift 和 AppKit 编写，提供自动、极速和 AI 精译三种模式。短词短句可以低延迟返回，长文、代码术语和驼峰专名可以交给本机 TranslateGemma 12B 流式生成。结果面板支持长文滚动，并在用户主动阅读前文时停止自动追随最新内容。

AI 精译模式只访问本机 Ollama，不做静默在线回退。自动和极速模式的数据路径、Google 未文档化端点的限制、Microsoft Neural 语音以及剪贴板行为，都在仓库的隐私说明中公开列出。

项目目前采用 source-first 发布方式，支持 macOS 13 及以上版本。本地 12B 模型主要面向 Apple Silicon。源码、安装步骤与隐私边界见：https://github.com/Rhiks/huayi-macos

## 截图拍摄清单

发布帖子建议配 3～4 张真实截图：

1. 英文单词或短句划选后出现 18×18 小触点。
2. 悬停后展开短译文，画面同时保留原文和鼠标位置。
3. TranslateGemma 12B 正在流式翻译一段技术长文。
4. 菜单栏中的三种翻译模式、语音和模型状态。

截图前请清理浏览器标签、账号头像、文件路径、通知和选区中的个人信息。不要用模拟界面冒充真实运行效果。

## 发布顺序

1. GitHub 仓库设置 Social Preview 图。
2. 发布一条带横版头图的短帖，正文使用“通用短帖”。
3. 小红书使用 3～4 张真实运行截图，首图可用横版头图裁成 4:3。
4. V2EX、少数派或掘金使用长版说明，并明确 source-first 和在线数据边界。
5. 收集 Issue 后再发布带签名、公证和自动更新的正式安装包。

## 推荐 Topics

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
~~~

## 不建议使用的措辞

- “完全离线”：自动和极速模式会访问在线服务。
- “官方 Google 翻译”：当前使用的是未文档化端点。
- “永久免费无限”：第三方服务可能限流、变更或停止。
- “强制 Quinn 音质”：默认跟随用户的系统 Siri Natural 配置。
- “通用已签名安装包”：当前没有 Developer ID 公证发行物。
- “零权限”：划词读取和临时复制需要 macOS 辅助功能权限。
