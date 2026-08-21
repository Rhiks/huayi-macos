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

- 主定位：在 Mac 上划到哪翻到哪，适合学英语、读 Paper 和阅读技术资料
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

Huayi 是一款原生 macOS 划词翻译工具：学英语时随手查词和听发音，读 Paper 时翻术语与长段落，在浏览器、PDF 阅读器和代码编辑器里划到哪翻到哪。

## 超短版

学英语、读 Paper，划到哪翻到哪。原生 macOS 划词翻译，支持本机 TranslateGemma 12B 流式精译。

## GitHub About

学英语、读 Paper，划到哪翻到哪：原生 macOS 划词翻译，支持系统发音和本机 TranslateGemma 12B 流式精译。

## GitHub About（英文）

Learn English and read papers without leaving the page. Native macOS selection translation with system speech and local TranslateGemma 12B streaming.

## 通用短帖

Huayi 开源了，一个用 Swift + AppKit 写的原生 macOS 划词翻译工具。

学英语遇到生词，划一下就能看译文、听发音；读 Paper 碰到术语和复杂长句，可以交给本机 TranslateGemma 12B 流式处理。浏览器、PDF 阅读器和代码编辑器里，不用复制到另一个页面，划到哪翻到哪。

划选文字后，鼠标附近只出现一个 18×18 的小触点；需要翻译时悬停展开，不需要时尽量少挡正文。

项目没有 Electron，也不带分析遥测。明确选择 AI 精译时，正文只发给本机 Ollama，不会静默切到在线服务。

源码与安装说明：https://github.com/Rhiks/huayi-macos

## 微博 / X 短版

学英语、读 Paper，不用再把文字复制到另一个页面。Huayi 是一个原生 macOS 划词翻译工具：划一下看译文、听发音，术语和长段落可交给本机 TranslateGemma 12B。浏览器、PDF、编辑器里划到哪翻到哪。https://github.com/Rhiks/huayi-macos

## 小红书

### 标题备选

1. Mac 读 Paper，不用再复制粘贴翻译了
2. 学英语时划一下就翻译，还能直接听发音
3. 做了一个划到哪翻到哪的 macOS 开源工具

### 正文

最近把自己用来学英语、读 Paper 的 macOS 划词翻译工具整理开源了，名字叫 Huayi。

遇到生词或不熟悉的表达，划一下就能看译文，也能直接听系统发音。读论文碰到术语、复杂句或一整段文字，可以交给本机 TranslateGemma 12B，译文会边生成边显示。浏览器、PDF 阅读器和代码编辑器里都不用来回复制粘贴。

它的交互很简单：划选文字后不会立刻弹出一大块窗口，只在鼠标附近出现一个 18×18 的小触点。想看译文就把鼠标移上去，不想看时它尽量不挡正文，也不会主动抢走键盘焦点。

短词短句可以走快速翻译；长文和技术语境可以走本机 AI。长文面板支持滚动，明确切到 AI 精译后，正文只会发到本机 Ollama，不会悄悄改走在线服务。

项目用 Swift + AppKit 编写，没有 Electron，也没有分析遥测。目前是 source-first 版本，需要从源码安装，macOS 13+ 可用，本地 12B 模型更推荐 Apple Silicon。

GitHub：Rhiks/huayi-macos

### 标签

`#macOS` `#学英语` `#论文阅读` `#效率工具` `#翻译工具` `#开源软件` `#本地AI` `#Ollama` `#TranslateGemma`

## V2EX / 少数派 / 掘金

### 标题

Huayi：学英语、读 Paper，划到哪翻到哪的 macOS 开源工具

### 正文

学英语或读 Paper 时，查一个词、确认一句话、看懂一段复杂论述，都是零碎但频繁的需求。复制、切换页面、粘贴、再回到原文，会不断打断阅读节奏。Huayi 把翻译入口留在正在阅读的文字旁边，让这些查询尽量一次完成。

划选后先显示一个 18×18 的小触点，悬停才展开译文。查词和短句时可以快速返回，并用系统语音朗读；论文术语、复杂句和长段落可以交给本机 TranslateGemma 12B 流式翻译。长文支持滚动，用户回看前文时，面板不会强行把视图拉回底部。

翻译分为自动、极速和 AI 精译三种模式。AI 精译只连接 `127.0.0.1:11434` 的 Ollama，不做静默在线回退；自动和极速模式会按 README 中说明的数据路径访问在线翻译服务。项目不包含分析 SDK，发布构建也不记录选中的正文。

目前仓库以源码为主，没有分发未经公证的安装包。欢迎试用、提 Issue 或参与改进。

项目地址：https://github.com/Rhiks/huayi-macos

## 英文短帖

Huayi is now open source — a native macOS tool for learning English and reading papers without leaving the page.

Select a word or sentence to see its translation and hear the system pronunciation. Technical terms and longer passages can stream through a local TranslateGemma 12B model. It works wherever text is selectable across browsers, PDF readers, and editors, while the small hover target keeps the original content visible.

No Electron and no analytics telemetry. Explicit AI mode stays on the local Ollama endpoint and never silently falls back online.

https://github.com/Rhiks/huayi-macos

## README / 发布页长版

Huayi 为英语学习和论文阅读里的高频小查询而做。遇到生词时划一下就能查看译文、听系统发音；读 Paper 碰到术语、复杂句和长段落时，可以交给本机 TranslateGemma 12B。浏览器、PDF 阅读器和代码编辑器里都不必反复复制、切换页面再粘贴。

划选文字后，界面先显示一个 18×18 的小触点；只有鼠标悬停时才展开译文。应用提供自动、极速和 AI 精译三种模式。短词短句保持低延迟，长文边生成边显示；结果面板支持滚动，并在用户主动阅读前文时停止自动追随最新内容。

AI 精译模式只访问本机 Ollama，不做静默在线回退。自动和极速模式的数据路径、Google 未文档化端点的限制、Microsoft Neural 语音以及剪贴板行为，都在仓库的隐私说明中公开列出。

项目目前采用 source-first 发布方式，支持 macOS 13 及以上版本。本地 12B 模型主要面向 Apple Silicon。源码、安装步骤与隐私边界见：https://github.com/Rhiks/huayi-macos

## 截图拍摄清单

发布帖子建议配 3～4 张真实截图：

1. 英语文章中划选生词后出现 18×18 小触点。
2. 悬停后显示译文与朗读入口，画面同时保留英文原文。
3. TranslateGemma 12B 正在流式翻译一段 Paper 内容。
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
