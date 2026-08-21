# Huayi 宣传素材

## 一句话

Huayi 是一款原生 macOS 划词翻译工具：划选后出现轻量触点，悬停查看译文；短句快速翻译，长文和技术术语可交给本机 TranslateGemma 12B 流式处理。

## GitHub 描述

Native macOS selection translator with a hover UI, local TranslateGemma 12B streaming, fast online translation, and system speech.

## 短帖

开源了 Huayi：一个 Swift + AppKit 写的原生 macOS 划词翻译工具。

划选文字后先出现 18×18 轻量触点，悬停再展开译文，不主动抢键盘焦点。短文本可以走快速在线翻译，长文和 OpenTelemetry 一类技术专名可交给本机 TranslateGemma 12B 流式生成；明确选择 AI 精译时不会静默上传正文。

项目地址：https://github.com/Rhiks/huayi-macos

## 长帖

Huayi 想解决的不是“再做一个翻译窗口”，而是减少阅读时的打断：划选后只出现一个很小的触点，需要时悬停展开，不需要时不遮正文。结果面板使用原生 AppKit，保持轻量且不主动抢占键盘焦点。

它提供三种路径：

- 极速：短词短句低延迟；
- 自动：短文本快速翻译，长文和技术专名优先走本机 AI；
- AI 精译：只连接本机 Ollama，不静默在线回退。

本地模型使用 TranslateGemma 12B，支持流式显示、取消旧请求和长文滚动；朗读默认跟随 macOS 的 Siri Natural 系统声音。项目没有 Electron，也不包含分析遥测。

源码、安装方式、隐私边界和第三方条款都已写在仓库：

https://github.com/Rhiks/huayi-macos

## 推荐 Topics

~~~text
macos
swift
appkit
menubar-app
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
