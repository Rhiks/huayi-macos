import Cocoa
import ApplicationServices
import AVFoundation
import NaturalLanguage
import os
import Darwin

private let appLogger = Logger(subsystem: "io.github.rhiks.huayi", category: "app")

func log(_ message: String) {
  #if DEBUG
  appLogger.debug("\(message, privacy: .private)")
  #else
  _ = message
  #endif
}

private let maxSelectionTranslateChars = 6000
private let maxSelectionSpeakChars = 360
private let localAIModel = "translategemma:12b"

private enum TranslationMode: String, CaseIterable {
  case automatic
  case fast
  case ai

  var title: String {
    switch self {
    case .automatic: return "自动（短文极速，长文 AI）"
    case .fast: return "极速（Google）"
    case .ai: return "AI 精译（本机 TranslateGemma）"
    }
  }
}

private enum TranslationEngine: Equatable {
  case google
  case localAI
}

private struct TranslationOutput {
  let text: String
  let source: String
}

final class OllamaStreamRequest: NSObject, URLSessionDataDelegate {
  private let delegateQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "io.github.rhiks.huayi.ollama-stream"
    queue.maxConcurrentOperationCount = 1
    return queue
  }()
  private let lifecycleLock = NSLock()
  private var session: URLSession?
  private var task: URLSessionDataTask?
  private var buffer = Data()
  private var accumulated = ""
  private var responseStatus = 0
  private var serverError: String?
  private var sawTerminalFrame = false
  private var terminalReason: String?
  private var lastProgressAt = Date.distantPast
  private var lastProgressLength = 0
  private var completed = false
  private let onProgress: (String) -> Void
  private let completion: (Result<String, Error>) -> Void

  init(onProgress: @escaping (String) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
    self.onProgress = onProgress
    self.completion = completion
  }

  func start(request: URLRequest) -> URLSessionDataTask {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 180
    configuration.timeoutIntervalForResource = 300
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
    lifecycleLock.lock()
    self.session = session
    let task = session.dataTask(with: request)
    self.task = task
    lifecycleLock.unlock()
    task.resume()
    return task
  }

  func cancel() {
    lifecycleLock.lock()
    let task = self.task
    let session = self.session
    lifecycleLock.unlock()
    task?.cancel()
    session?.invalidateAndCancel()
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    responseStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    buffer.append(data)
    consumeCompleteLines()
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if !buffer.isEmpty {
      parseLine(buffer)
      buffer.removeAll(keepingCapacity: false)
    }
    guard !completed else { return }
    completed = true
    defer {
      self.lifecycleLock.lock()
      self.task = nil
      self.session = nil
      self.lifecycleLock.unlock()
      session.finishTasksAndInvalidate()
    }

    if let error {
      completion(.failure(error))
      return
    }
    if !(200...299).contains(responseStatus) {
      completion(.failure(NSError(
        domain: "TranslateGemma",
        code: responseStatus,
        userInfo: [NSLocalizedDescriptionKey: serverError ?? "HTTP \(responseStatus)"]
      )))
      return
    }
    if let serverError {
      completion(.failure(NSError(
        domain: "TranslateGemma",
        code: -7,
        userInfo: [NSLocalizedDescriptionKey: serverError]
      )))
      return
    }
    guard sawTerminalFrame else {
      completion(.failure(NSError(
        domain: "TranslateGemma",
        code: -8,
        userInfo: [NSLocalizedDescriptionKey: "本地 AI 流式响应意外中断，未收到完成标记"]
      )))
      return
    }
    guard terminalReason == "stop" else {
      let message: String
      if terminalReason == "length" {
        message = "本地 AI 输出达到长度上限，译文不完整"
      } else {
        message = "本地 AI 异常结束：\(terminalReason ?? "未知原因")"
      }
      completion(.failure(NSError(
        domain: "TranslateGemma",
        code: -9,
        userInfo: [NSLocalizedDescriptionKey: message]
      )))
      return
    }
    let translated = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !translated.isEmpty else {
      completion(.failure(NSError(domain: "TranslateGemma", code: -5, userInfo: [NSLocalizedDescriptionKey: serverError ?? "本地 AI 译文为空"])))
      return
    }
    completion(.success(translated))
  }

  private func consumeCompleteLines() {
    while let newline = buffer.firstIndex(of: 0x0A) {
      let line = Data(buffer[..<newline])
      buffer.removeSubrange(buffer.startIndex...newline)
      parseLine(line)
    }
  }

  private func parseLine(_ line: Data) {
    guard let decoded = String(data: line, encoding: .utf8) else { return }
    let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          let data = trimmed.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
    if let message = object["error"] as? String {
      serverError = message
    }
    if object["done"] as? Bool == true {
      sawTerminalFrame = true
      terminalReason = object["done_reason"] as? String
    }
    if let chunk = object["response"] as? String, !chunk.isEmpty {
      accumulated += chunk
      let now = Date()
      let firstUpdate = lastProgressLength == 0
      let hasUsefulDelta = accumulated.count - lastProgressLength >= 2
      if firstUpdate || (hasUsefulDelta && now.timeIntervalSince(lastProgressAt) >= 0.12) {
        lastProgressAt = now
        lastProgressLength = accumulated.count
        onProgress(accumulated)
      }
    }
  }
}

final class PassivePanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

final class BubbleScrollView: NSScrollView {
  var onUserScroll: (() -> Void)?

  override func scrollWheel(with event: NSEvent) {
    super.scrollWheel(with: event)
    onUserScroll?()
  }
}

final class BubbleScroller: NSScroller {
  var onUserScrollBegan: (() -> Void)?
  var onUserScroll: (() -> Void)?

  override func mouseDown(with event: NSEvent) {
    onUserScrollBegan?()
    super.mouseDown(with: event)
    onUserScroll?()
  }
}

final class BubbleTextView: NSTextView {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class PasteboardSnapshot {
  private let items: [NSPasteboardItem]

  init(pasteboard: NSPasteboard) {
    self.items = pasteboard.pasteboardItems?.map { item in
      let copy = NSPasteboardItem()
      for type in item.types {
        if let data = item.data(forType: type) {
          copy.setData(data, forType: type)
        }
      }
      return copy
    } ?? []
  }

  @discardableResult
  func restore(to pasteboard: NSPasteboard, ifUnchangedSince expectedChangeCount: Int) -> Bool {
    guard pasteboard.changeCount == expectedChangeCount else { return false }
    pasteboard.clearContents()
    if !items.isEmpty {
      pasteboard.writeObjects(items)
    }
    return true
  }
}

final class FloatingBubble {
  private enum VerticalPlacement {
    case below
    case above
  }

  private var panel: NSPanel?
  private var contentView: NSView?
  private var scrollView: BubbleScrollView?
  private var textView: BubbleTextView?
  private var sourceField: NSTextField?
  private var hideWorkItem: DispatchWorkItem?
  private var dismissOnMouseMove = false
  private var streamingPlacement: VerticalPlacement?
  private var isStreaming = false
  private var followsStreamingTail = true

  func show(text: String, source: String, at point: CGPoint, autoHideAfter delay: TimeInterval = 3.0, dismissOnMouseMove: Bool = false) {
    isStreaming = false
    followsStreamingTail = true
    streamingPlacement = nil
    render(text: text, source: source, at: point, autoHideAfter: delay, dismissOnMouseMove: dismissOnMouseMove, forceLongForm: false, logUpdate: true)
  }

  func beginStreaming(text: String, source: String, at point: CGPoint) {
    isStreaming = true
    followsStreamingTail = true
    streamingPlacement = preferredStreamingPlacement(for: point)
    render(text: text, source: source, at: point, autoHideAfter: 0, dismissOnMouseMove: false, forceLongForm: true, logUpdate: true)
  }

  func updateStreaming(text: String, source: String, at point: CGPoint) {
    render(text: text, source: source, at: point, autoHideAfter: 0, dismissOnMouseMove: false, forceLongForm: true, logUpdate: false)
  }

  func finishStreaming(text: String, source: String, at point: CGPoint) {
    render(text: text, source: source, at: point, autoHideAfter: 0, dismissOnMouseMove: false, forceLongForm: true, logUpdate: true)
    isStreaming = false
    streamingPlacement = nil
  }

  private func render(
    text: String,
    source: String,
    at point: CGPoint,
    autoHideAfter delay: TimeInterval,
    dismissOnMouseMove: Bool,
    forceLongForm: Bool,
    logUpdate: Bool
  ) {
    if logUpdate {
      log("FloatingBubble: show called. Length: \(text.count), source: \(source)")
    }
    hideWorkItem?.cancel()
    hideWorkItem = nil
    self.dismissOnMouseMove = dismissOnMouseMove

    let visibleFrame = (NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main)?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let longForm = forceLongForm || text.count >= 160
    let panelWidth = min(longForm ? 560 : 420, visibleFrame.width - 24)
    let textWidth = panelWidth - 28
    let textFont = NSFont.systemFont(ofSize: 14)
    let measuredBounds = (text as NSString).boundingRect(
      with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: textFont]
    )
    let maximumTextHeight = longForm
      ? min(620, max(320, visibleFrame.height - 90))
      : min(340, max(180, visibleFrame.height - 90))
    let textHeight = min(maximumTextHeight, max(30, ceil(measuredBounds.height) + 4))
    let panelHeight = textHeight + 50
    let panelSize = CGSize(width: panelWidth, height: panelHeight)
    ensurePanel(initialSize: panelSize)
    guard let panel, let contentView, let scrollView, let textView, let sourceField else { return }

    let previousScrollOrigin = scrollView.contentView.bounds.origin
    textView.frame.size = NSSize(width: textWidth, height: max(textView.frame.height, textHeight))
    textView.textContainer?.containerSize = NSSize(width: textWidth, height: .greatestFiniteMagnitude)
    textView.textStorage?.setAttributedString(NSAttributedString(
      string: text,
      attributes: [.font: textFont, .foregroundColor: NSColor.white]
    ))
    var laidOutTextHeight = ceil(measuredBounds.height) + 4
    if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
      layoutManager.ensureLayout(for: textContainer)
      laidOutTextHeight = ceil(layoutManager.usedRect(for: textContainer).height + textView.textContainerInset.height * 2)
    }
    let documentHeight = max(textHeight, laidOutTextHeight)
    textView.frame = NSRect(x: 0, y: 0, width: textWidth, height: documentHeight)
    scrollView.frame = NSRect(x: 14, y: 34, width: textWidth, height: textHeight)
    scrollView.hasVerticalScroller = documentHeight > textHeight + 0.5
    sourceField.stringValue = source
    sourceField.frame = NSRect(x: 14, y: 12, width: textWidth, height: 14)
    contentView.frame = NSRect(origin: .zero, size: panelSize)
    panel.setFrame(
      NSRect(origin: frameOrigin(for: point, panelSize: panelSize, placement: streamingPlacement), size: panelSize),
      display: true,
      animate: false
    )
    if isStreaming {
      if followsStreamingTail {
        scrollToStreamingTail()
      } else {
        restoreScrollPosition(previousScrollOrigin)
      }
    } else if !isStreaming, logUpdate {
      scrollToTop()
    }
    if !panel.isVisible {
      panel.orderFrontRegardless()
      log("FloatingBubble: Panel ordered front.")
    }

    guard delay > 0 else {
      if logUpdate {
        log("FloatingBubble: Auto-hide disabled for this bubble.")
      }
      return
    }

    let workItem = DispatchWorkItem { [weak self] in
      log("FloatingBubble: Auto-hide timer fired. Ordering out panel.")
      self?.hideWorkItem = nil
      self?.panel?.orderOut(nil)
    }
    hideWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    log("FloatingBubble: Scheduled auto-hide in \(delay) seconds.")
  }

  private func ensurePanel(initialSize: CGSize) {
    guard panel == nil else { return }
    log("FloatingBubble: Creating reusable NSPanel.")

    let contentView = NSView(frame: NSRect(origin: .zero, size: initialSize))
    contentView.wantsLayer = true
    contentView.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.96).cgColor
    contentView.layer?.cornerRadius = 10
    contentView.layer?.borderWidth = 1
    contentView.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor

    let textView = BubbleTextView(frame: .zero)
    textView.drawsBackground = false
    textView.textColor = .white
    textView.font = .systemFont(ofSize: 14)
    textView.isEditable = false
    textView.isSelectable = true
    textView.isRichText = false
    textView.importsGraphics = false
    textView.allowsUndo = false
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.autoresizingMask = [.width]
    textView.textContainerInset = NSSize(width: 0, height: 2)
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false

    let scrollView = BubbleScrollView(frame: .zero)
    scrollView.borderType = .noBorder
    scrollView.drawsBackground = false
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.scrollerStyle = .overlay
    scrollView.verticalScrollElasticity = .automatic
    let verticalScroller = BubbleScroller()
    scrollView.verticalScroller = verticalScroller
    scrollView.documentView = textView
    scrollView.onUserScroll = { [weak self] in
      self?.updateStreamingTailPreference()
    }
    verticalScroller.onUserScrollBegan = { [weak self] in
      self?.pauseStreamingTail()
    }
    verticalScroller.onUserScroll = { [weak self] in
      self?.updateStreamingTailPreference()
    }
    contentView.addSubview(scrollView)

    let sourceField = NSTextField(labelWithString: "")
    sourceField.textColor = NSColor.white.withAlphaComponent(0.62)
    sourceField.font = .systemFont(ofSize: 11)
    sourceField.alignment = .right
    contentView.addSubview(sourceField)

    let panel = PassivePanel(
      contentRect: contentView.frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.level = .popUpMenu
    panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = false
    panel.becomesKeyOnlyIfNeeded = true
    panel.contentView = contentView

    self.contentView = contentView
    self.scrollView = scrollView
    self.textView = textView
    self.sourceField = sourceField
    self.panel = panel
  }

  private func updateStreamingTailPreference() {
    guard isStreaming else { return }
    followsStreamingTail = isScrolledToBottom()
  }

  private func pauseStreamingTail() {
    guard isStreaming else { return }
    followsStreamingTail = false
  }

  private func isScrolledToBottom(tolerance: CGFloat = 8) -> Bool {
    guard let scrollView, let textView else { return true }
    let visibleBottom = scrollView.documentVisibleRect.maxY
    return textView.bounds.maxY - visibleBottom <= tolerance
  }

  private func scrollToStreamingTail() {
    guard let scrollView, let textView else { return }
    let viewportHeight = scrollView.contentView.bounds.height
    let y = max(0, textView.bounds.height - viewportHeight)
    scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
    scrollView.reflectScrolledClipView(scrollView.contentView)
  }

  private func restoreScrollPosition(_ origin: NSPoint) {
    guard let scrollView, let textView else { return }
    let viewportHeight = scrollView.contentView.bounds.height
    let maximumY = max(0, textView.bounds.height - viewportHeight)
    scrollView.contentView.scroll(to: NSPoint(x: 0, y: min(max(0, origin.y), maximumY)))
    scrollView.reflectScrolledClipView(scrollView.contentView)
  }

  private func scrollToTop() {
    guard let scrollView else { return }
    scrollView.contentView.scroll(to: .zero)
    scrollView.reflectScrolledClipView(scrollView.contentView)
  }

  func hide() {
    log("FloatingBubble: hide() called explicitly.")
    hideWorkItem?.cancel()
    hideWorkItem = nil
    dismissOnMouseMove = false
    isStreaming = false
    followsStreamingTail = true
    streamingPlacement = nil
    panel?.orderOut(nil)
  }

  func scheduleHideIfNeededForMouseMove(after delay: TimeInterval = 3.0) {
    guard dismissOnMouseMove, hideWorkItem == nil else { return }
    let workItem = DispatchWorkItem { [weak self] in
      log("FloatingBubble: Mouse moved after translation. Delayed hide timer fired.")
      self?.hide()
    }
    hideWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    log("FloatingBubble: Mouse moved after translation. Scheduled hide in \(delay) seconds.")
  }

  func hideIfNeededForMouseDown() {
    guard dismissOnMouseMove else { return }
    log("FloatingBubble: Mouse clicked after translation. Hiding panel immediately.")
    hide()
  }

  func isPointInside(_ point: CGPoint) -> Bool {
    guard let panel = panel, panel.isVisible else { return false }
    return NSMouseInRect(point, panel.frame, false)
  }

  private func preferredStreamingPlacement(for point: CGPoint) -> VerticalPlacement {
    let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
    let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let spaceBelow = point.y - visible.minY
    let spaceAbove = visible.maxY - point.y
    return spaceBelow >= spaceAbove ? .below : .above
  }

  private func frameOrigin(for point: CGPoint, panelSize: CGSize, placement: VerticalPlacement? = nil) -> CGPoint {
    let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
    let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

    var x = point.x + 12
    var y: CGFloat
    switch placement {
    case .above:
      y = point.y + 18
    case .below, .none:
      y = point.y - panelSize.height - 12
    }

    if x + panelSize.width > visible.maxX {
      x = visible.maxX - panelSize.width - 12
    }
    if x < visible.minX {
      x = visible.minX + 12
    }
    if placement == nil, y < visible.minY {
      y = point.y + 18
    }
    if y < visible.minY {
      y = visible.minY + 12
    }
    if y + panelSize.height > visible.maxY {
      y = visible.maxY - panelSize.height - 12
    }

    return CGPoint(x: x, y: y)
  }
}

final class HoverTriggerView: NSView {
  var onHover: (() -> Void)?
  private var trackingAreaRef: NSTrackingArea?
  private var hasTriggered = false

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingAreaRef {
      removeTrackingArea(trackingAreaRef)
    }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    trackingAreaRef = area
    addTrackingArea(area)
  }

  override func mouseEntered(with event: NSEvent) {
    guard !hasTriggered else { return }
    hasTriggered = true
    onHover?()
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    let visualSize: CGFloat = 18
    let visualRect = NSRect(
      x: (bounds.width - visualSize) / 2,
      y: (bounds.height - visualSize) / 2,
      width: visualSize,
      height: visualSize
    )
    NSColor(calibratedWhite: 0.10, alpha: 0.96).setFill()
    NSBezierPath(roundedRect: visualRect, xRadius: 5, yRadius: 5).fill()

    if let image = NSImage(
      systemSymbolName: "character.bubble.fill",
      accessibilityDescription: "划译"
    )?.withSymbolConfiguration(.init(paletteColors: [.white])) {
      image.draw(in: visualRect.insetBy(dx: 4, dy: 4))
    }
  }
}

final class HoverTriggerBubble {
  private var panel: NSPanel?
  private var hideWorkItem: DispatchWorkItem?
  private var activation: (() -> Void)?

  func show(at point: CGPoint, onHover: @escaping () -> Void) {
    hideWorkItem?.cancel()
    activation = onHover

    // Keep the visible control exactly 18x18 while giving it transparent
    // pointer tolerance so a one-pixel miss does not lose the hover action.
    let size = CGSize(width: 32, height: 32)
    let view = HoverTriggerView(frame: NSRect(origin: .zero, size: size))
    view.wantsLayer = true
    view.onHover = { [weak self] in
      guard let self else { return }
      let action = self.activation
      self.hide()
      action?()
    }

    if panel == nil {
      panel = PassivePanel(
        contentRect: view.frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
      )
      panel?.isOpaque = false
      panel?.backgroundColor = .clear
      panel?.hasShadow = true
      panel?.level = .popUpMenu
      panel?.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
      panel?.hidesOnDeactivate = false
      panel?.ignoresMouseEvents = false
      panel?.becomesKeyOnlyIfNeeded = true
    }

    panel?.contentView = view
    panel?.setFrameOrigin(frameOrigin(for: point, panelSize: size))
    panel?.orderFrontRegardless()
    log("HoverTriggerBubble: Small trigger shown.")

    let workItem = DispatchWorkItem { [weak self] in
      self?.hide()
    }
    hideWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 12.0, execute: workItem)
  }

  func hide() {
    hideWorkItem?.cancel()
    hideWorkItem = nil
    activation = nil
    panel?.orderOut(nil)
  }

  func isPointInside(_ point: CGPoint) -> Bool {
    guard let panel, panel.isVisible else { return false }
    return NSMouseInRect(point, panel.frame, false)
  }

  private func frameOrigin(for point: CGPoint, panelSize: CGSize) -> CGPoint {
    let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
    let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    var x = point.x + 2
    var y = point.y - panelSize.height

    if x + panelSize.width > visible.maxX { x = visible.maxX - panelSize.width - 8 }
    if x < visible.minX { x = visible.minX + 8 }
    if y < visible.minY { y = point.y + 10 }
    if y + panelSize.height > visible.maxY { y = visible.maxY - panelSize.height - 8 }
    return CGPoint(x: x, y: y)
  }
}

private enum SelectionActivation: Equatable {
  case hover
  case immediate
}

final class TranslatorApp: NSObject, NSApplicationDelegate {
  private struct CachedSpeechVoice {
    let name: String
    let language: String
    let quality: Int
  }

  private final class ClipboardCaptureTransaction {
    let generation: UInt64
    let snapshot: PasteboardSnapshot
    let initialChangeCount: Int

    init(generation: UInt64, pasteboard: NSPasteboard) {
      self.generation = generation
      self.snapshot = PasteboardSnapshot(pasteboard: pasteboard)
      self.initialChangeCount = pasteboard.changeCount
    }
  }

  private var statusItem: NSStatusItem!
  private var speechRateMenuItem: NSMenuItem?
  private var translationModeMenuItem: NSMenuItem?
  private var localAIStatusMenuItem: NSMenuItem?
  private var shortcutModeMenuItem: NSMenuItem?
  private var englishAccentMenuItem: NSMenuItem?
  private var speechModeMenuItem: NSMenuItem?
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var eventTapHealthTimer: Timer?
  private var instanceLockFileDescriptor: Int32 = -1
  private let bubble = FloatingBubble()
  private let hoverTrigger = HoverTriggerBubble()
  private let speaker = AVSpeechSynthesizer()
  private var enabled = true
  private var lastText = ""
  private var lastTextAt = Date.distantPast
  private var pendingCapture: DispatchWorkItem?
  private var captureGeneration: UInt64 = 0
  private var activeClipboardCapture: ClipboardCaptureTransaction?
  private var retryTimer: Timer?
  private var currentSpeechProcess: Process?
  private var currentSpeechAudioURL: URL?
  private var speechWarmupProcess: Process?
  private var speechGeneration = 0
  private var mouseDownPoint: CGPoint?
  private var mouseDownSourceBundleID: String?
  private var mouseDownSourceProcessIdentifier: pid_t?
  private var mouseDownStartedInsideHuayiUI = false

  private let shortcutModeKey = "Huayi.shortcutOnlyModeEnabled_v1"
  private let englishAccentKey = "Huayi.englishAccent_v1"
  private let neuralSpeechModeKey = "Huayi.neuralSpeechModeEnabled_v1"
  private let speechRatePreferenceName = "Huayi.speechRate_v1"
  private let translationModeKey = "Huayi.translationMode_v1"
  private let speechRateOptions: [(rate: Int, label: String)] = [
    (110, "很慢"),
    (130, "慢"),
    (145, "较慢"),
    (165, "标准"),
    (185, "快"),
    (230, "很快")
  ]
  private var shortcutModeEnabled = false
  private var englishAccent = "en-US"
  private var neuralSpeechModeEnabled = false
  private var speechRate = 145
  private var translationMode: TranslationMode = .automatic
  private var localAIAvailable = false
  private var localAIStatusText = "检测中"
  private var localAIWarmupRequested = false
  private var translationCache: [String: TranslationOutput] = [:]
  private var translationCacheOrder: [String] = []
  private var activeTranslationTask: URLSessionDataTask?
  private var activeOllamaStream: OllamaStreamRequest?
  private var translationGeneration = 0
  private var cachedEnglishVoices: [String: CachedSpeechVoice] = [:]

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard acquireSingleInstanceLock() else {
      log("applicationDidFinishLaunching: Another Huayi instance is already running; terminating this launch.")
      NSApp.terminate(nil)
      return
    }
    log("applicationDidFinishLaunching called. Trusted: \(AXIsProcessTrusted())")
    cleanupSpeechFilesLeftByPreviousRuns()
    shortcutModeEnabled = UserDefaults.standard.object(forKey: shortcutModeKey) as? Bool ?? false
    englishAccent = UserDefaults.standard.string(forKey: englishAccentKey) == "en-GB" ? "en-GB" : "en-US"
    neuralSpeechModeEnabled = UserDefaults.standard.bool(forKey: neuralSpeechModeKey)
    let storedSpeechRate = UserDefaults.standard.integer(forKey: speechRatePreferenceName)
    speechRate = speechRateOptions.contains(where: { $0.rate == storedSpeechRate }) ? storedSpeechRate : 145
    translationMode = UserDefaults.standard.string(forKey: translationModeKey)
      .flatMap(TranslationMode.init(rawValue:)) ?? .automatic
    log("applicationDidFinishLaunching: Loaded shortcutModeEnabled = \(shortcutModeEnabled)")
    log("applicationDidFinishLaunching: Loaded English accent = \(englishAccent)")
    log("applicationDidFinishLaunching: Loaded neuralSpeechModeEnabled = \(neuralSpeechModeEnabled)")
    log("applicationDidFinishLaunching: Loaded speech rate = \(speechRate)")
    log("applicationDidFinishLaunching: Loaded translation mode = \(translationMode.rawValue)")
    cachePreferredEnglishVoices()
    prewarmSystemSpeech()
    NSApp.setActivationPolicy(.accessory)
    setupMenu()
    refreshLocalAIStatus()
    if !AXIsProcessTrusted() {
      log("Accessibility not trusted. Requesting permissions...")
      requestAccessibilityIfNeeded(prompt: true)
    }
    _ = installEventTap()
    startEventTapHealthMonitor()

    log("Huayi ready: hover trigger mode with Option+Q fallback; translation mode \(translationMode.rawValue).")
  }

  func applicationWillTerminate(_ notification: Notification) {
    invalidateSelectionCapture()
    stopSpeaking()
    cancelTranslation()
    eventTapHealthTimer?.invalidate()
    eventTapHealthTimer = nil
    retryTimer?.invalidate()
    retryTimer = nil
    tearDownEventTap()
    if instanceLockFileDescriptor >= 0 {
      _ = flock(instanceLockFileDescriptor, LOCK_UN)
      close(instanceLockFileDescriptor)
      instanceLockFileDescriptor = -1
    }
  }

  private func acquireSingleInstanceLock() -> Bool {
    guard instanceLockFileDescriptor < 0 else { return true }
    let lockURL = FileManager.default.temporaryDirectory.appendingPathComponent("huayi.instance.lock")
    let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else {
      log("acquireSingleInstanceLock: Could not open the per-user lock file; continuing without the lock.")
      return true
    }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      close(descriptor)
      return false
    }
    instanceLockFileDescriptor = descriptor
    return true
  }

  private func setupMenu() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.autosaveName = "HuayiStatusItem"
    statusItem.isVisible = true
    if let image = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "划译") {
      image.isTemplate = true
      statusItem.button?.image = image
      statusItem.button?.imagePosition = .imageOnly
    } else {
      statusItem.button?.title = "译"
    }
    statusItem.button?.toolTip = "划译"

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "划词翻译和朗读：开启", action: #selector(toggleEnabled), keyEquivalent: ""))

    let translationItem = NSMenuItem(title: translationModeMenuTitle, action: nil, keyEquivalent: "")
    let translationMenu = NSMenu(title: "翻译模式")
    for mode in TranslationMode.allCases {
      let item = NSMenuItem(title: mode.title, action: #selector(selectTranslationMode(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = mode.rawValue
      item.state = mode == translationMode ? .on : .off
      translationMenu.addItem(item)
    }
    translationItem.submenu = translationMenu
    translationModeMenuItem = translationItem
    menu.addItem(translationItem)

    let aiStatusItem = NSMenuItem(title: localAIStatusTitle, action: #selector(refreshLocalAIStatus), keyEquivalent: "")
    aiStatusItem.target = self
    localAIStatusMenuItem = aiStatusItem
    menu.addItem(aiStatusItem)
    menu.addItem(.separator())

    let modeItem = NSMenuItem(title: "仅快捷键 Option+Q（代码/笔试模式）", action: #selector(toggleShortcutMode), keyEquivalent: "")
    modeItem.state = shortcutModeEnabled ? .on : .off
    shortcutModeMenuItem = modeItem
    menu.addItem(modeItem)

    let accentItem = NSMenuItem(title: englishAccentMenuTitle, action: #selector(toggleEnglishAccent), keyEquivalent: "")
    englishAccentMenuItem = accentItem
    menu.addItem(accentItem)

    let speechModeItem = NSMenuItem(title: speechModeMenuTitle, action: #selector(toggleSpeechMode), keyEquivalent: "")
    speechModeMenuItem = speechModeItem
    menu.addItem(speechModeItem)

    let rateItem = NSMenuItem(title: speechRateMenuTitle, action: nil, keyEquivalent: "")
    let rateMenu = NSMenu(title: "Siri Natural 语速")
    for option in speechRateOptions {
      let item = NSMenuItem(title: "\(option.label)（\(option.rate)）", action: #selector(selectSpeechRate(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = NSNumber(value: option.rate)
      item.state = option.rate == speechRate ? .on : .off
      rateMenu.addItem(item)
    }
    rateItem.submenu = rateMenu
    speechRateMenuItem = rateItem
    menu.addItem(rateItem)

    menu.addItem(NSMenuItem(title: "重新请求辅助功能权限", action: #selector(openAccessibilityPrompt), keyEquivalent: ""))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
    statusItem.menu = menu
  }

  @objc private func selectTranslationMode(_ sender: NSMenuItem) {
    guard let rawValue = sender.representedObject as? String,
          let mode = TranslationMode(rawValue: rawValue) else { return }
    translationMode = mode
    UserDefaults.standard.set(mode.rawValue, forKey: translationModeKey)
    translationModeMenuItem?.title = translationModeMenuTitle
    translationModeMenuItem?.submenu?.items.forEach { item in
      item.state = (item.representedObject as? String) == mode.rawValue ? .on : .off
    }
    if mode != .fast {
      refreshLocalAIStatus()
    }
    log("selectTranslationMode: Translation mode is now \(mode.rawValue).")
  }

  private var translationModeMenuTitle: String {
    switch translationMode {
    case .automatic: return "翻译模式：自动"
    case .fast: return "翻译模式：极速"
    case .ai: return "翻译模式：AI 精译"
    }
  }

  private var localAIStatusTitle: String {
    "本地 AI：\(localAIStatusText)（点此刷新）"
  }

  @objc private func refreshLocalAIStatus() {
    localAIStatusText = "检测中"
    localAIStatusMenuItem?.title = localAIStatusTitle
    guard let url = URL(string: "http://127.0.0.1:11434/api/tags") else { return }
    var request = URLRequest(url: url)
    request.timeoutInterval = 2
    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      var available = false
      var status = "未启动，使用极速回退"

      if error == nil,
         let http = response as? HTTPURLResponse,
         (200...299).contains(http.statusCode),
         let data,
         let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let models = object["models"] as? [[String: Any]] {
        let modelNames = models.compactMap { model in
          (model["name"] as? String) ?? (model["model"] as? String)
        }
        available = modelNames.contains { name in
          name == localAIModel || name.hasPrefix("\(localAIModel):")
        }
        status = available ? "TranslateGemma 12B 已就绪" : "服务已启动，模型未下载"
      }

      DispatchQueue.main.async {
        guard let self else { return }
        self.localAIAvailable = available
        self.localAIStatusText = available && self.localAIWarmupRequested
          ? "TranslateGemma 12B 已就绪 · 常驻"
          : status
        self.localAIStatusMenuItem?.title = self.localAIStatusTitle
        log("refreshLocalAIStatus: \(status)")
        if available, self.translationMode != .fast {
          self.warmUpLocalAIIfNeeded()
        }
      }
    }.resume()
  }

  private func warmUpLocalAIIfNeeded() {
    guard localAIAvailable, !localAIWarmupRequested else { return }
    localAIWarmupRequested = true
    localAIStatusText = "TranslateGemma 12B 预热中"
    localAIStatusMenuItem?.title = localAIStatusTitle

    guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else { return }
    let payload: [String: Any] = [
      "model": localAIModel,
      "prompt": " ",
      "stream": false,
      "keep_alive": -1,
      "options": ["num_predict": 1]
    ]
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 90
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

    URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
      let succeeded = error == nil && ((response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false)
      DispatchQueue.main.async {
        guard let self else { return }
        self.localAIWarmupRequested = succeeded
        self.localAIStatusText = succeeded ? "TranslateGemma 12B 已就绪 · 常驻" : "TranslateGemma 12B 已就绪"
        self.localAIStatusMenuItem?.title = self.localAIStatusTitle
        log("warmUpLocalAIIfNeeded: \(succeeded ? "Model warm-up completed." : "Model warm-up failed; on-demand loading remains available.")")
      }
    }.resume()
  }

  @objc private func toggleShortcutMode() {
    invalidateSelectionCapture()
    hoverTrigger.hide()
    shortcutModeEnabled.toggle()
    UserDefaults.standard.set(shortcutModeEnabled, forKey: shortcutModeKey)
    shortcutModeMenuItem?.state = shortcutModeEnabled ? .on : .off
    log("toggleShortcutMode: shortcutModeEnabled is now \(shortcutModeEnabled)")
  }

  @objc private func toggleEnglishAccent() {
    englishAccent = englishAccent == "en-US" ? "en-GB" : "en-US"
    UserDefaults.standard.set(englishAccent, forKey: englishAccentKey)
    englishAccentMenuItem?.title = englishAccentMenuTitle
    stopSpeaking()
    log("toggleEnglishAccent: English accent is now \(englishAccent), neural voice: \(englishNeuralVoice)")
  }

  private var englishAccentMenuTitle: String {
    englishAccent == "en-GB"
      ? "英语口音：英音"
      : "英语口音：美音（Siri Natural）"
  }

  @objc private func toggleSpeechMode() {
    neuralSpeechModeEnabled.toggle()
    UserDefaults.standard.set(neuralSpeechModeEnabled, forKey: neuralSpeechModeKey)
    speechModeMenuItem?.title = speechModeMenuTitle
    stopSpeaking()
    log("toggleSpeechMode: neuralSpeechModeEnabled is now \(neuralSpeechModeEnabled)")
  }

  private var speechModeMenuTitle: String {
    neuralSpeechModeEnabled
      ? "朗读模式：在线 Neural（会等待）"
      : "朗读模式：极速本机（无网络等待）"
  }

  @objc private func selectSpeechRate(_ sender: NSMenuItem) {
    guard let rate = (sender.representedObject as? NSNumber)?.intValue,
          speechRateOptions.contains(where: { $0.rate == rate }) else { return }
    speechRate = rate
    UserDefaults.standard.set(rate, forKey: speechRatePreferenceName)
    speechRateMenuItem?.title = speechRateMenuTitle
    speechRateMenuItem?.submenu?.items.forEach { item in
      item.state = (item.representedObject as? NSNumber)?.intValue == rate ? .on : .off
    }
    stopSpeaking()
    log("selectSpeechRate: Local Siri speech rate is now \(rate).")
  }

  private var speechRateMenuTitle: String {
    let label = speechRateOptions.first(where: { $0.rate == speechRate })?.label ?? "自定义"
    return "Siri Natural 语速：\(label)（\(speechRate)）"
  }

  private var englishNeuralVoice: String {
    englishAccent == "en-GB" ? "en-GB-SoniaNeural" : "en-US-AvaMultilingualNeural"
  }

  private func cachePreferredEnglishVoices() {
    let voices = AVSpeechSynthesisVoice.speechVoices()
    // US English intentionally follows the configured Siri Natural system
    // voice, which is not exposed through AVSpeechSynthesisVoice. Cache only
    // the explicit British fallback used by the accent switch.
    let preferences: [(locale: String, names: [String])] = [
      ("en-GB", ["Serena", "Daniel"])
    ]

    for preference in preferences {
      let selectedVoice = voices
        .filter { $0.language.caseInsensitiveCompare(preference.locale) == .orderedSame }
        .sorted { lhs, rhs in
          if lhs.quality.rawValue != rhs.quality.rawValue {
            return lhs.quality.rawValue > rhs.quality.rawValue
          }
          let lhsRank = preference.names.firstIndex(of: lhs.name) ?? preference.names.count
          let rhsRank = preference.names.firstIndex(of: rhs.name) ?? preference.names.count
          return lhsRank < rhsRank
        }
        .first

      if let selectedVoice {
        cachedEnglishVoices[preference.locale] = CachedSpeechVoice(
          name: selectedVoice.name,
          language: selectedVoice.language,
          quality: selectedVoice.quality.rawValue
        )
        log("cachePreferredEnglishVoices: Cached '\(selectedVoice.name)' for \(preference.locale), quality: \(selectedVoice.quality.rawValue).")
      }
    }
  }

  @objc private func toggleEnabled() {
    enabled.toggle()
    log("toggleEnabled called. Enabled state is now: \(enabled)")
    statusItem.menu?.item(at: 0)?.title = enabled ? "划词翻译和朗读：开启" : "划词翻译和朗读：关闭"
    if !enabled {
      invalidateSelectionCapture()
      cancelTranslation()
      hoverTrigger.hide()
      bubble.hide()
      stopSpeaking()
    }
  }

  private func stopSpeaking() {
    speechGeneration += 1
    speaker.stopSpeaking(at: .immediate)
    if let process = currentSpeechProcess, process.isRunning {
      process.terminate()
    }
    currentSpeechProcess = nil
    removeCurrentSpeechAudio()
  }

  private func cancelTranslation() {
    translationGeneration += 1
    activeTranslationTask?.cancel()
    activeTranslationTask = nil
    activeOllamaStream?.cancel()
    activeOllamaStream = nil
  }

  private func removeCurrentSpeechAudio() {
    guard let url = currentSpeechAudioURL else { return }
    try? FileManager.default.removeItem(at: url)
    currentSpeechAudioURL = nil
  }

  private func cleanupSpeechFilesLeftByPreviousRuns() {
    let directory = FileManager.default.temporaryDirectory
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else { return }

    for file in files where file.lastPathComponent.hasPrefix("huayi-speech-") && file.pathExtension == "mp3" {
      let values = try? file.resourceValues(forKeys: [.isRegularFileKey])
      guard values?.isRegularFile == true else { continue }
      try? FileManager.default.removeItem(at: file)
    }
  }

  @objc private func openAccessibilityPrompt() {
    log("openAccessibilityPrompt called.")
    requestAccessibilityIfNeeded(prompt: true)
    _ = installEventTap()
  }

  @objc private func quit() {
    log("quit called. Exiting...")
    retryTimer?.invalidate()
    retryTimer = nil
    invalidateSelectionCapture()
    stopSpeaking()
    cancelTranslation()
    NSApp.terminate(nil)
  }

  private func requestAccessibilityIfNeeded(prompt: Bool = false) {
    log("requestAccessibilityIfNeeded called (prompt: \(prompt))")
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  private func scheduleEventTapRetry() {
    guard retryTimer == nil else { return }
    retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      self?.checkAndInstallEventTap()
    }
  }

  private func startEventTapHealthMonitor() {
    guard eventTapHealthTimer == nil else { return }
    let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
      self?.ensureEventTapHealthy()
    }
    timer.tolerance = 0.5
    eventTapHealthTimer = timer
  }

  private func tearDownEventTap() {
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
      self.runLoopSource = nil
    }
    if let eventTap {
      CFMachPortInvalidate(eventTap)
      self.eventTap = nil
    }
  }

  private func ensureEventTapHealthy() {
    guard AXIsProcessTrusted() else {
      if eventTap != nil {
        log("ensureEventTapHealthy: Accessibility trust was revoked; removing the event tap.")
        tearDownEventTap()
      }
      scheduleEventTapRetry()
      return
    }

    if let eventTap, CFMachPortIsValid(eventTap) {
      if !CGEvent.tapIsEnabled(tap: eventTap) {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      if CGEvent.tapIsEnabled(tap: eventTap) {
        return
      }
    }

    log("ensureEventTapHealthy: Event tap is invalid or disabled; recreating it.")
    tearDownEventTap()
    _ = installEventTap()
  }

  @discardableResult
  private func installEventTap() -> Bool {
    guard AXIsProcessTrusted() else {
      log("installEventTap: App is not trusted yet. Setting up retry timer.")
      tearDownEventTap()
      scheduleEventTapRetry()
      return false
    }

    if let eventTap, CFMachPortIsValid(eventTap) {
      if !CGEvent.tapIsEnabled(tap: eventTap) {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      if CGEvent.tapIsEnabled(tap: eventTap) {
        return true
      }
    }
    if eventTap != nil || runLoopSource != nil {
      tearDownEventTap()
    }

    log("installEventTap: Attempting to create event tap...")
    let callback: CGEventTapCallBack = { _, type, event, refcon in
      guard let refcon else { return Unmanaged.passUnretained(event) }
      let app = Unmanaged<TranslatorApp>.fromOpaque(refcon).takeUnretainedValue()

      if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let eventTap = app.eventTap {
          CGEvent.tapEnable(tap: eventTap, enable: true)
          log("installEventTap: Event tap was disabled and has been re-enabled automatically.")
          if !CGEvent.tapIsEnabled(tap: eventTap) {
            DispatchQueue.main.async { [weak app] in
              app?.ensureEventTapHealthy()
            }
          }
        }
        return Unmanaged.passUnretained(event)
      }

      if type == .leftMouseDown {
        app.invalidateSelectionCapture()
        let screenPoint = NSEvent.mouseLocation
        let startedInsideHuayiUI = app.bubble.isPointInside(screenPoint) || app.hoverTrigger.isPointInside(screenPoint)
        app.mouseDownStartedInsideHuayiUI = startedInsideHuayiUI
        if startedInsideHuayiUI {
          // Click is inside bubble, do not dismiss or stop speaking.
          app.mouseDownPoint = nil
          app.mouseDownSourceBundleID = nil
          app.mouseDownSourceProcessIdentifier = nil
        } else {
          app.cancelTranslation()
          app.stopSpeaking()
          app.hoverTrigger.hide()
          app.bubble.hide()
          app.mouseDownPoint = event.location
          let sourceApplication = NSWorkspace.shared.frontmostApplication
          app.mouseDownSourceBundleID = sourceApplication?.bundleIdentifier
          app.mouseDownSourceProcessIdentifier = sourceApplication?.processIdentifier
        }
      } else if type == .leftMouseUp {
        if app.mouseDownStartedInsideHuayiUI {
          app.mouseDownStartedInsideHuayiUI = false
          app.mouseDownPoint = nil
          app.mouseDownSourceBundleID = nil
          app.mouseDownSourceProcessIdentifier = nil
          return Unmanaged.passUnretained(event)
        }
        var clickCount = 1
        if let nsEvent = NSEvent(cgEvent: event) {
          clickCount = nsEvent.clickCount
        }
        app.handleMouseUp(at: NSEvent.mouseLocation, eventLocation: event.location, clickCount: clickCount)
      } else if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        let optionPressed = flags.contains(.maskAlternate)
        let cmdPressed = flags.contains(.maskCommand)
        let ctrlPressed = flags.contains(.maskControl)

        // Keycode for Q is 12
        if keyCode == 12 && optionPressed && !cmdPressed && !ctrlPressed {
          app.handleShortcutPressed()
          return nil // Swallow the Option+Q keydown event
        }
      }
      return Unmanaged.passUnretained(event)
    }

    let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue) | (1 << CGEventType.keyDown.rawValue)
    guard let createdEventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(mask),
      callback: callback,
      userInfo: Unmanaged.passUnretained(self).toOpaque()
    ) else {
      log("installEventTap: CGEvent.tapCreate returned nil unexpectedly.")
      scheduleEventTapRetry()
      return false
    }

    eventTap = createdEventTap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdEventTap, 0)
    if let runLoopSource {
      CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    CGEvent.tapEnable(tap: createdEventTap, enable: true)
    guard CGEvent.tapIsEnabled(tap: createdEventTap) else {
      log("installEventTap: The new event tap could not be enabled.")
      tearDownEventTap()
      scheduleEventTapRetry()
      return false
    }

    log("installEventTap: Event tap created successfully.")
    retryTimer?.invalidate()
    retryTimer = nil
    return true
  }

  private func checkAndInstallEventTap() {
    let trusted = AXIsProcessTrusted()
    log("checkAndInstallEventTap: Checking trust status... Trusted: \(trusted)")
    if trusted, installEventTap() {
      bubble.show(text: "已成功获得辅助功能权限，系统级划译服务已启动！", source: "macOS", at: NSEvent.mouseLocation)
    }
  }

  private func handleMouseUp(at point: CGPoint, eventLocation: CGPoint, clickCount: Int) {
    guard enabled else { return }
    guard !shortcutModeEnabled else {
      hoverTrigger.hide()
      bubble.hide()
      return
    }

    var dragDistance: CGFloat = 0.0
    if let startPoint = mouseDownPoint {
      let dx = eventLocation.x - startPoint.x
      let dy = eventLocation.y - startPoint.y
      dragDistance = sqrt(dx*dx + dy*dy)
    }
    mouseDownPoint = nil
    let currentSourceApplication = NSWorkspace.shared.frontmostApplication
    let sourceBundleID = mouseDownSourceBundleID ?? currentSourceApplication?.bundleIdentifier
    let sourceProcessIdentifier = mouseDownSourceProcessIdentifier ?? currentSourceApplication?.processIdentifier
    mouseDownSourceBundleID = nil
    mouseDownSourceProcessIdentifier = nil

    log("handleMouseUp: mouse up detected. Click count: \(clickCount), drag distance: \(dragDistance)")

    if clickCount < 2 && dragDistance < 2.5 {
      return
    }

    log("handleMouseUp: triggering capture at screen point: \(point)")
    let generation = beginSelectionCapture()
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.captureGeneration == generation else { return }
      self.captureSelectedText(
        at: point,
        activation: .hover,
        generation: generation,
        sourceBundleID: sourceBundleID,
        sourceProcessIdentifier: sourceProcessIdentifier
      )
    }
    pendingCapture = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: workItem)
  }

  private func handleShortcutPressed() {
    guard enabled else { return }
    log("handleShortcutPressed: Option+Q pressed, triggering capture...")
    let sourceApplication = NSWorkspace.shared.frontmostApplication
    let generation = beginSelectionCapture()
    DispatchQueue.main.async { [weak self] in
      guard let self, self.captureGeneration == generation else { return }
      self.captureSelectedText(
        at: NSEvent.mouseLocation,
        activation: .immediate,
        generation: generation,
        sourceBundleID: sourceApplication?.bundleIdentifier,
        sourceProcessIdentifier: sourceApplication?.processIdentifier
      )
    }
  }

  private func beginSelectionCapture() -> UInt64 {
    invalidateSelectionCapture()
    return captureGeneration
  }

  private func invalidateSelectionCapture() {
    captureGeneration &+= 1
    pendingCapture?.cancel()
    pendingCapture = nil
  }

  private func captureSelectedText(
    at point: CGPoint,
    activation: SelectionActivation,
    generation: UInt64,
    retriesRemaining: Int = 3,
    sourceBundleID originalSourceBundleID: String? = nil,
    sourceProcessIdentifier originalSourceProcessIdentifier: pid_t? = nil
  ) {
    guard captureGeneration == generation else {
      log("captureSelectedText: Ignoring superseded capture generation \(generation).")
      return
    }

    guard AXIsProcessTrusted() else {
      log("captureSelectedText: AXIsProcessTrusted is false.")
      bubble.show(text: "请先授予辅助功能权限。", source: "macOS", at: point)
      requestAccessibilityIfNeeded(prompt: true)
      return
    }

    let currentApplication = NSWorkspace.shared.frontmostApplication
    let sourceBundleID = originalSourceBundleID ?? currentApplication?.bundleIdentifier ?? ""
    let sourceProcessIdentifier = originalSourceProcessIdentifier ?? currentApplication?.processIdentifier
    if let selected = selectedTextFromFocusedElement(processIdentifier: sourceProcessIdentifier) {
      log("captureSelectedText: Read selection from \(sourceBundleID) through Accessibility. Length: \(selected.count)")
      handleCapturedText(selected, at: point, sourceBundleID: sourceBundleID, activation: activation)
      return
    }

    if retriesRemaining > 0 {
      log("captureSelectedText: Selection is not ready; retrying Accessibility (\(retriesRemaining) remaining).")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
        guard let self, self.captureGeneration == generation else { return }
        self.captureSelectedText(
          at: point,
          activation: activation,
          generation: generation,
          retriesRemaining: retriesRemaining - 1,
          sourceBundleID: sourceBundleID,
          sourceProcessIdentifier: sourceProcessIdentifier
        )
      }
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
      guard let self, self.captureGeneration == generation else { return }
      self.captureSelectedTextViaClipboard(
        at: point,
        sourceBundleID: sourceBundleID,
        sourceProcessIdentifier: sourceProcessIdentifier,
        activation: activation,
        generation: generation
      )
    }
  }

  private func selectedTextFromFocusedElement(processIdentifier: pid_t?) -> String? {
    let accessibilityRoot = processIdentifier.map(AXUIElementCreateApplication) ?? AXUIElementCreateSystemWide()
    var focusedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
      accessibilityRoot,
      kAXFocusedUIElementAttribute as CFString,
      &focusedValue
    ) == .success,
      let focusedValue,
      CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return nil }

    let focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)
    var selectedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
      focusedElement,
      kAXSelectedTextAttribute as CFString,
      &selectedValue
    ) == .success,
      let selected = selectedValue as? String else { return nil }

    let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func captureSelectedTextViaClipboard(
    at point: CGPoint,
    sourceBundleID: String,
    sourceProcessIdentifier: pid_t?,
    activation: SelectionActivation,
    generation: UInt64,
    waitingForClipboardSlot: Bool = false
  ) {
    guard captureGeneration == generation else { return }
    guard let sourceProcessIdentifier else {
      log("captureSelectedText: Clipboard fallback skipped because the original source PID is unavailable.")
      return
    }

    if activeClipboardCapture != nil {
      if !waitingForClipboardSlot {
        log("captureSelectedText: Waiting for the previous clipboard capture transaction to settle.")
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
        guard let self, self.captureGeneration == generation else { return }
        self.captureSelectedTextViaClipboard(
          at: point,
          sourceBundleID: sourceBundleID,
          sourceProcessIdentifier: sourceProcessIdentifier,
          activation: activation,
          generation: generation,
          waitingForClipboardSlot: true
        )
      }
      return
    }

    let pasteboard = NSPasteboard.general
    let transaction = ClipboardCaptureTransaction(generation: generation, pasteboard: pasteboard)

    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == sourceProcessIdentifier else {
      log("captureSelectedText: Clipboard fallback skipped because source PID \(sourceProcessIdentifier) is no longer frontmost.")
      return
    }

    activeClipboardCapture = transaction
    log("captureSelectedText: Accessibility selection unavailable for \(sourceBundleID). Sending Cmd+C fallback...")
    sendCopyShortcut()

    waitForCopiedText(on: pasteboard, transaction: transaction, attemptsRemaining: 24) { [weak self] copied, copiedChangeCount in
      guard let self else { return }
      guard self.activeClipboardCapture === transaction else { return }
      defer {
        if self.activeClipboardCapture === transaction {
          self.activeClipboardCapture = nil
        }
      }

      log("captureSelectedText: Capture callback. Length: \(copied.count)")
      if let copiedChangeCount {
        let restored = transaction.snapshot.restore(to: pasteboard, ifUnchangedSince: copiedChangeCount)
        log(restored
          ? "captureSelectedText: Restored the previous clipboard snapshot."
          : "captureSelectedText: Clipboard changed after capture; preserving the newer contents.")
      }

      guard self.captureGeneration == generation else {
        log("captureSelectedText: Discarding clipboard result from superseded capture generation \(generation).")
        return
      }
      self.handleCapturedText(copied, at: point, sourceBundleID: sourceBundleID, activation: activation)
    }
  }

  private func waitForCopiedText(
    on pasteboard: NSPasteboard,
    transaction: ClipboardCaptureTransaction,
    attemptsRemaining: Int,
    completion: @escaping (String, Int?) -> Void
  ) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
      guard let self, self.activeClipboardCapture === transaction else { return }
      // A superseded transaction still has to settle the Cmd+C it already
      // posted. Its generation gate prevents result delivery, while retaining
      // the single clipboard slot keeps a newer snapshot from racing it.
      let observedChangeCount = pasteboard.changeCount
      let changed = observedChangeCount != transaction.initialChangeCount
      if changed {
        let copied = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        log("waitForCopiedText: Pasteboard changed, length: \(copied.count)")
        completion(copied, observedChangeCount)
        return
      }

      guard attemptsRemaining > 0 else {
        log("waitForCopiedText: Pasteboard did not change after copy shortcut.")
        completion("", nil)
        return
      }

      self.waitForCopiedText(
        on: pasteboard,
        transaction: transaction,
        attemptsRemaining: attemptsRemaining - 1,
        completion: completion
      )
    }
  }

  private func sendCopyShortcut() {
    let source = CGEventSource(stateID: .combinedSessionState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
  }

  private func detectLanguage(_ text: String) -> String? {
    if looksLikeEnglish(text) {
      return "en"
    }

    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    return recognizer.dominantLanguage?.rawValue
  }

  private func looksLikeEnglish(_ text: String) -> Bool {
    let scalars = text.unicodeScalars
    let visibleScalars = scalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
    guard !visibleScalars.isEmpty else { return false }

    let latinCharCount = visibleScalars.filter { scalar in
      (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
    }.count
    guard latinCharCount > 0 else { return false }

    let visibleCharCount = visibleScalars.count
    guard visibleCharCount > 0 else { return false }

    let allowedPunctuation = CharacterSet(charactersIn: ".,;:!?()[]{}'\"-_/+%$#@&*<>=")
    let asciiPunctuationAndDigits = scalars.allSatisfy { scalar in
      scalar.isASCII && (
        CharacterSet.alphanumerics.contains(scalar) ||
        CharacterSet.whitespacesAndNewlines.contains(scalar) ||
        allowedPunctuation.contains(scalar)
      )
    }

    return asciiPunctuationAndDigits && Double(latinCharCount) / Double(visibleCharCount) >= 0.45
  }

  private func handleCapturedText(_ text: String, at point: CGPoint, sourceBundleID: String, activation: SelectionActivation) {
    let normalized = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)

    if activation == .hover, isExcludedFromAutomaticTrigger(sourceBundleID) {
      log("handleCapturedText: Automatic trigger blocked for app \(sourceBundleID).")
      hoverTrigger.hide()
      bubble.hide()
      return
    }

    if let reason = rejectionReason(for: text, normalized: normalized) {
      log("handleCapturedText: Rejected selection (\(reason)); length: \(normalized.count).")
      hoverTrigger.hide()
      bubble.hide()
      return
    }

    guard normalized.count >= 4 && normalized.count <= maxSelectionTranslateChars else {
      log("handleCapturedText: Text length \(normalized.count) out of bounds, skipping.")
      hoverTrigger.hide()
      bubble.hide()
      return
    }

    let isNumericOnly = normalized.range(of: "^[\\d.,\\s%+$¥€£#-]+$", options: .regularExpression) != nil
    if isNumericOnly {
      log("handleCapturedText: Numeric-only selection skipped; length: \(normalized.count).")
      hoverTrigger.hide()
      bubble.hide()
      return
    }

    // Skip if the text contains digits and is both short and has few words (likely a part number, version, code, etc.)
    let hasDigit = normalized.range(of: "\\d", options: .regularExpression) != nil
    if hasDigit {
      let words = normalized.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
      if words.count < 4 && normalized.count < 15 {
        log("handleCapturedText: Numeric code or short phrase skipped; length: \(normalized.count).")
        hoverTrigger.hide()
        bubble.hide()
        return
      }
    }

    if normalized.range(of: "[\\u4e00-\\u9fa5]", options: .regularExpression) != nil {
      log("handleCapturedText: Contains Chinese characters, skipping.")
      hoverTrigger.hide()
      bubble.hide()
      return
    }

    let detectedLang = detectLanguage(normalized) ?? "en"
    log("handleCapturedText: Detected language \(detectedLang); selection length: \(normalized.count).")

    if detectedLang.hasPrefix("zh") {
      log("handleCapturedText: Detected language is Chinese, skipping.")
      hoverTrigger.hide()
      bubble.hide()
      return
    }

    let now = Date()
    if normalized == lastText && now.timeIntervalSince(lastTextAt) < 0.4 {
      log("handleCapturedText: Duplicate selection within 0.4s, skipping.")
      return
    }
    lastText = normalized
    lastTextAt = now

    if activation == .hover {
      bubble.hide()
      hoverTrigger.show(at: point) { [weak self] in
        self?.activateSelection(normalized, languageCode: detectedLang, at: point)
      }
      return
    }

    activateSelection(normalized, languageCode: detectedLang, at: point)
  }

  private func activateSelection(_ text: String, languageCode: String, at point: CGPoint) {
    hoverTrigger.hide()
    if shouldSpeak(text) {
      log("activateSelection: Starting configured system voice; text length: \(text.count), language: \(languageCode).")
      speak(text, languageCode: languageCode)
    }

    cancelTranslation()
    let requestGeneration = translationGeneration
    let engine = selectedTranslationEngine(for: text)
    let loadingText = engine == .localAI ? "AI 精译中..." : "翻译中..."
    let loadingSource = engine == .localAI ? "本机 TranslateGemma 12B" : "Google"
    if engine == .localAI {
      bubble.beginStreaming(text: loadingText, source: "\(loadingSource) · 系统 Siri Natural", at: point)
    } else {
      bubble.show(text: loadingText, source: "\(loadingSource) · 系统 Siri Natural", at: point)
    }
    log("activateSelection: Initiating \(engine == .localAI ? "local AI" : "Google") translation...")

    translate(
      text,
      sourceLanguageCode: languageCode,
      using: engine,
      generation: requestGeneration,
      progress: { [weak self] partial in
        DispatchQueue.main.async {
          guard let self, self.translationGeneration == requestGeneration else { return }
          let visible = self.cleanTranslateGemmaResponse(partial)
          guard !visible.isEmpty else { return }
          self.bubble.updateStreaming(
            text: visible,
            source: "本机 TranslateGemma 12B · 生成中 · 系统 Siri Natural",
            at: point
          )
        }
      }
    ) { [weak self] result in
      DispatchQueue.main.async {
        guard let self, self.translationGeneration == requestGeneration else { return }
        self.activeTranslationTask = nil
        self.activeOllamaStream = nil
        switch result {
        case .success(let output):
          log("Translation success via \(output.source). Length: \(output.text.count)")
          let actualEngine: TranslationEngine = output.source.hasPrefix("本机 TranslateGemma") ? .localAI : .google
          self.storeCachedTranslation(output, engine: actualEngine, sourceLanguageCode: languageCode, text: text)
          if actualEngine == .localAI {
            self.bubble.finishStreaming(text: output.text, source: "\(output.source) · 系统 Siri Natural", at: point)
          } else {
            self.bubble.show(text: output.text, source: "\(output.source) · 系统 Siri Natural", at: point, autoHideAfter: 0, dismissOnMouseMove: false)
          }
        case .failure(let error):
          let nsError = error as NSError
          log("Translation failed; domain: \(nsError.domain), code: \(nsError.code).")
          if engine == .localAI {
            self.bubble.finishStreaming(text: "翻译失败：\(error.localizedDescription)", source: loadingSource, at: point)
          } else {
            self.bubble.show(text: "翻译失败：\(error.localizedDescription)", source: loadingSource, at: point, autoHideAfter: 0, dismissOnMouseMove: false)
          }
        }
      }
    }
  }

  private func selectedTranslationEngine(for text: String) -> TranslationEngine {
    switch translationMode {
    case .fast:
      return .google
    case .ai:
      return .localAI
    case .automatic:
      return shouldUseLocalAI(for: text) ? .localAI : .google
    }
  }

  private func shouldUseLocalAI(for text: String) -> Bool {
    let normalized = text
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let words = normalized.split(whereSeparator: { $0.isWhitespace })
    guard !words.isEmpty else { return false }

    // CamelCase / PascalCase product and API names benefit from contextual AI
    // translation even when the selection is short.
    let technicalTokens = words.filter { rawToken in
      let token = String(rawToken).trimmingCharacters(in: .punctuationCharacters)
      return token.count >= 7 &&
        token.range(of: "^[A-Z][A-Za-z0-9+.-]*[A-Z][A-Za-z0-9+.-]*$", options: .regularExpression) != nil
    }
    if !technicalTokens.isEmpty { return true }

    // Keep routing local and deterministic. Asking another model to classify
    // the text would add latency before translation even starts.
    var complexityScore = 0
    let sentenceWordCounts = normalized
      .split(whereSeparator: { ".!?;\n".contains($0) })
      .map { sentence in sentence.split(whereSeparator: { $0.isWhitespace }).count }
      .filter { $0 > 0 }
    let longestSentence = sentenceWordCounts.max() ?? words.count
    let averageSentenceLength = sentenceWordCounts.isEmpty
      ? Double(words.count)
      : Double(sentenceWordCounts.reduce(0, +)) / Double(sentenceWordCounts.count)

    let clausePattern = "\\b(although|whereas|notwithstanding|unless|because|despite|while|which|whose|whereby|therefore|however|moreover|consequently|insofar)\\b"
    let clauseCount = (try? NSRegularExpression(pattern: clausePattern, options: [.caseInsensitive]))?
      .numberOfMatches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) ?? 0
    if clauseCount >= 2 { complexityScore += 1 }

    let structuralPunctuationCount = normalized.unicodeScalars.reduce(into: 0) { count, scalar in
      if CharacterSet(charactersIn: ",:()[]—").contains(scalar) { count += 1 }
    }
    if structuralPunctuationCount >= 3 { complexityScore += 1 }

    let cleanedWordLengths = words.map {
      String($0).trimmingCharacters(in: .punctuationCharacters).count
    }.filter { $0 > 0 }
    let longWordCount = cleanedWordLengths.filter { $0 >= 12 }.count
    let averageWordLength = cleanedWordLengths.isEmpty
      ? 0
      : Double(cleanedWordLengths.reduce(0, +)) / Double(cleanedWordLengths.count)
    if averageWordLength >= 3.5, longestSentence >= 30 { complexityScore += 2 }
    if averageWordLength >= 3.5, averageSentenceLength >= 22 { complexityScore += 1 }
    if longWordCount >= 2 { complexityScore += 1 }
    if words.count >= 20, averageWordLength >= 6.3 { complexityScore += 1 }

    if words.count >= 100 { complexityScore += 2 }
    if text.count >= 900 { complexityScore += 2 }

    return complexityScore >= 3
  }

  private func translationCacheKey(engine: TranslationEngine, sourceLanguageCode: String, text: String) -> String {
    let engineName = engine == .localAI ? "ai" : "google"
    return "\(engineName)|\(sourceLanguageCode)|zh|\(text)"
  }

  private func cachedTranslation(engine: TranslationEngine, sourceLanguageCode: String, text: String) -> TranslationOutput? {
    translationCache[translationCacheKey(engine: engine, sourceLanguageCode: sourceLanguageCode, text: text)]
  }

  private func storeCachedTranslation(_ output: TranslationOutput, engine: TranslationEngine, sourceLanguageCode: String, text: String) {
    let key = translationCacheKey(engine: engine, sourceLanguageCode: sourceLanguageCode, text: text)
    if translationCache[key] == nil {
      translationCacheOrder.append(key)
    }
    translationCache[key] = output
    while translationCacheOrder.count > 100 {
      let oldest = translationCacheOrder.removeFirst()
      translationCache.removeValue(forKey: oldest)
    }
  }

  private func translate(
    _ text: String,
    sourceLanguageCode: String,
    using engine: TranslationEngine,
    generation: Int,
    progress: @escaping (String) -> Void,
    completion: @escaping (Result<TranslationOutput, Error>) -> Void
  ) {
    let allowsOnlineFallback = translationMode != .ai
    if let cached = cachedTranslation(engine: engine, sourceLanguageCode: sourceLanguageCode, text: text) {
      log("translate: Returning cached \(engine == .localAI ? "AI" : "Google") result.")
      completion(.success(cached))
      return
    }

    switch engine {
    case .google:
      activeTranslationTask = translateWithGoogle(text) { result in
        completion(result.map { TranslationOutput(text: $0, source: "Google") })
      }
    case .localAI:
      guard localAIAvailable else {
        if !allowsOnlineFallback {
          completion(.failure(NSError(
            domain: "TranslateGemma",
            code: -10,
            userInfo: [NSLocalizedDescriptionKey: "本地 AI 未就绪；AI 精译模式不会把文本发送到在线服务"]
          )))
          return
        }
        log("translate: Local AI is not ready; falling back to Google without waiting.")
        activeTranslationTask = translateWithGoogle(text) { result in
          completion(result.map { TranslationOutput(text: $0, source: "Google · AI 未就绪回退") })
        }
        return
      }

      var hasEmittedAIProgress = false
      activeTranslationTask = translateWithOllama(
        text,
        sourceLanguageCode: sourceLanguageCode,
        onProgress: { partial in
          if !partial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            hasEmittedAIProgress = true
          }
          progress(partial)
        }
      ) { [weak self] result in
        DispatchQueue.main.async {
          guard let self, self.translationGeneration == generation else { return }
          switch result {
          case .success(let translated):
            completion(.success(TranslationOutput(text: translated, source: "本机 TranslateGemma 12B")))
          case .failure(let aiError):
            if (aiError as? URLError)?.code == .cancelled {
              completion(.failure(aiError))
              return
            }
            if hasEmittedAIProgress {
              log("translate: Local AI failed after streaming began; preserving the AI result instead of switching engines.")
              self.refreshLocalAIStatus()
              completion(.failure(aiError))
              return
            }
            if !allowsOnlineFallback {
              completion(.failure(aiError))
              return
            }
            log("translate: Local AI failed before the first streamed token; falling back to Google.")
            self.refreshLocalAIStatus()
            self.activeTranslationTask = self.translateWithGoogle(text) { googleResult in
              completion(googleResult.map {
                TranslationOutput(text: $0, source: "Google · AI 失败回退")
              })
            }
          }
        }
      }
    }
  }

  private func isExcludedFromAutomaticTrigger(_ bundleID: String) -> Bool {
    let exact: Set<String> = [
      "com.apple.Terminal",
      "com.googlecode.iterm2",
      "dev.warp.Warp-Stable",
      "com.apple.dt.Xcode",
      "com.microsoft.VSCode",
      "com.todesktop.230313mzl4w4u92",
      "dev.zed.Zed"
    ]
    if exact.contains(bundleID) { return true }
    return bundleID.hasPrefix("com.jetbrains.") ||
      bundleID.localizedCaseInsensitiveContains("exam") ||
      bundleID.localizedCaseInsensitiveContains("assessment") ||
      bundleID.localizedCaseInsensitiveContains("interview")
  }

  private func rejectionReason(for raw: String, normalized: String) -> String? {
    guard normalized.count >= 2 else { return "too-short" }
    if raw.unicodeScalars.contains(where: { scalar in
      scalar.value == 0xFFFD ||
        (CharacterSet.controlCharacters.contains(scalar) && scalar != "\n" && scalar != "\r" && scalar != "\t")
    }) {
      return "garbled-control-character"
    }

    if normalized.range(of: "(?i)^(https?://|www\\.)", options: .regularExpression) != nil ||
       normalized.range(of: "(?i)^(file://|/[A-Za-z0-9._-]+/|[A-Za-z]:\\\\)", options: .regularExpression) != nil {
      return "url-or-path"
    }

    if normalized.range(of: "(?i)^\\s*[\\[{].*[\\]}]\\s*$", options: .regularExpression) != nil {
      return "code-structure"
    }

    let codeSyntaxPatterns = [
      "(?i)\\b(?:const|let|var)\\s+[A-Za-z_$][A-Za-z0-9_$]*\\s*(?::|=)",
      "(?i)\\b(?:func|def|class|struct|enum|protocol)\\s+[A-Za-z_][A-Za-z0-9_]*\\s*(?:\\(|:|\\{)",
      "(?i)\\b(?:public|private|protected|static)\\s+(?:class|func|def|let|var|const|void|int|string|bool|boolean)\\b",
      "(?i)\\bfrom\\s+[A-Za-z_][A-Za-z0-9_.]*\\s+import\\b|\\bimport\\s+[A-Za-z_][A-Za-z0-9_.]*",
      "(?i)^\\s*(?:SELECT\\s+.+\\s+FROM|INSERT\\s+INTO|UPDATE\\s+.+\\s+SET|DELETE\\s+FROM)\\b"
    ]
    if codeSyntaxPatterns.contains(where: { normalized.range(of: $0, options: .regularExpression) != nil }) {
      return "code-syntax"
    }

    if raw.range(of: "(?im)^\\s*(Traceback|at\\s+.+\\(.+:\\d+(:\\d+)?\\)|File\\s+\".+\",\\s+line\\s+\\d+|[A-Za-z]+(?:Error|Exception):)", options: .regularExpression) != nil {
      return "stack-trace"
    }

    if normalized.range(of: "^[A-Za-z_][A-Za-z0-9_.]*\\s*\\([^)]*\\)\\s*;?$", options: .regularExpression) != nil ||
       normalized.range(of: "^</?[A-Za-z][^>]*>$", options: .regularExpression) != nil {
      return "code-call-or-markup"
    }

    let codeOperators = [" = ", "=>", "==", "!=", "===", "&&", "||", "::", "->", "→", "←", "⇢", "</", "/>", "```", "#{", "${"]
    let operatorHits = codeOperators.reduce(0) { $0 + (normalized.contains($1) ? 1 : 0) }
    let visible = normalized.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
    let letters = visible.filter { CharacterSet.letters.contains($0) }.count
    let codePunctuation = visible.filter { CharacterSet(charactersIn: "{}[];`=<>\\|").contains($0) }.count
    let words = normalized.split(whereSeparator: { $0.isWhitespace })

    if operatorHits >= 1 && words.count < 14 { return "code-operator" }
    if !visible.isEmpty, Double(codePunctuation) / Double(visible.count) > 0.10 { return "symbol-heavy" }
    if !visible.isEmpty, Double(letters) / Double(visible.count) < 0.45 { return "low-letter-ratio" }
    if raw.contains("\n"), raw.split(separator: "\n").contains(where: { $0.hasPrefix("    ") || $0.hasPrefix("\t") }) {
      return "indented-code"
    }
    if words.count == 1,
       normalized.range(of: "^[A-Za-z][A-Za-z'-]{1,48}$", options: .regularExpression) == nil {
      return "invalid-single-word"
    }
    if words.count == 1 {
      let startsWithLowercase = normalized.unicodeScalars.first.map {
        CharacterSet.lowercaseLetters.contains($0)
      } ?? false
      let looksLikeLowerCamelVariable = startsWithLowercase &&
        normalized.range(of: "[a-z][A-Z]", options: .regularExpression) != nil
      if normalized.contains("_") || looksLikeLowerCamelVariable {
        return "code-identifier"
      }
    }
    if !normalized.contains(" "), normalized.count >= 24,
       normalized.range(of: "^[A-Za-z0-9+/=_-]+$", options: .regularExpression) != nil {
      return "encoded-or-generated-token"
    }
    return nil
  }

  func runFilterSelfTest() -> Bool {
    let accepted = [
      "A useful selection translator should feel immediate and natural.",
      "Natural pronunciation matters when learning a language.",
      "In this post, we share what we have learned from working with customers and building agents ourselves.",
      "OpenTelemetry",
      "ChatGPT",
      "ephemeral"
    ]
    let rejected = [
      "https://example.com/api?q=test",
      "/Users/example/project/main.swift",
      "{\"name\":\"Codex\",\"enabled\":true}",
      "for (let i = 0; i < items.length; i++) {",
      "print(\"hello\")",
      "sult = generat",
      "user → LLM → tool → LLM → tool",
      "foo_bar",
      "helloWorld",
      "Traceback (most recent call last):\n  File \"main.py\", line 4",
      "abc123+/=_abc123+/=_abc123+/=_",
      "broken\u{FFFD}text"
    ]

    var failed = false
    for text in accepted {
      if let reason = rejectionReason(for: text, normalized: text) {
        print("FILTER_SELF_TEST unexpected rejection [\(reason)]: \(text)")
        failed = true
      }
    }
    for text in rejected {
      if rejectionReason(for: text, normalized: text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)) == nil {
        print("FILTER_SELF_TEST unexpected acceptance: \(text)")
        failed = true
      }
    }
    print(failed ? "FILTER_SELF_TEST=FAIL" : "FILTER_SELF_TEST=PASS")
    return !failed
  }

  func runTranslationRoutingSelfTest() -> Bool {
    let originalMode = translationMode
    defer { translationMode = originalMode }

    var failed = false
    let simpleLongText = String(repeating: "We read books and share notes every day. ", count: 10)
    let complexShortText = "Although the proposed method appears efficient, its assumptions, which depend on independently distributed observations, become difficult to defend because the sampling process changes over time and therefore introduces a systematic bias into the final estimate."
    let checks: [(TranslationMode, String, TranslationEngine)] = [
      (.automatic, "hello world", .google),
      (.automatic, String(repeating: "a ", count: 159), .google),
      (.automatic, simpleLongText, .google),
      (.automatic, complexShortText, .localAI),
      (.automatic, "OpenTelemetry", .localAI),
      (.automatic, "OpenTelemetry correlates traces, metrics, and logs across distributed services.", .localAI),
      (.automatic, String(repeating: "A short sentence. ", count: 60), .localAI),
      (.fast, "OpenTelemetry", .google),
      (.ai, "hello world", .localAI)
    ]

    for (mode, text, expected) in checks {
      translationMode = mode
      let actual = selectedTranslationEngine(for: text)
      if actual != expected {
        print("ROUTING_SELF_TEST unexpected route [\(mode.rawValue)]: \(text.prefix(40))")
        failed = true
      }
    }
    print(failed ? "ROUTING_SELF_TEST=FAIL" : "ROUTING_SELF_TEST=PASS")
    return !failed
  }

  func runLocalAIIntegrationSelfTest() -> Bool {
    let cases = [
      "OpenTelemetry",
      "In a distributed system, traces, metrics, and logs must be correlated so engineers can identify latency regressions without guessing which service caused them."
    ]
    var allPassed = true

    for text in cases {
      let semaphore = DispatchSemaphore(value: 0)
      var passed = false
      var detail = ""
      var progressCount = 0
      var firstProgressLatency: TimeInterval?
      let startedAt = Date()
      _ = translateWithOllama(
        text,
        sourceLanguageCode: "en",
        onProgress: { partial in
          guard !partial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
          progressCount += 1
          if firstProgressLatency == nil {
            firstProgressLatency = Date().timeIntervalSince(startedAt)
          }
        }
      ) { result in
        switch result {
        case .success(let translated):
          passed = translated.range(of: "[\\u4e00-\\u9fa5]", options: .regularExpression) != nil && progressCount > 0
          let firstLatency = firstProgressLatency.map { String(format: "%.2fs", $0) } ?? "none"
          detail = "progress=\(progressCount) first=\(firstLatency) final=\(translated)"
        case .failure(let error):
          detail = error.localizedDescription
        }
        semaphore.signal()
      }

      if semaphore.wait(timeout: .now() + 90) == .timedOut {
        print("AI_SELF_TEST=FAIL timeout")
        return false
      }
      print(passed ? "AI_SELF_TEST=PASS \(detail)" : "AI_SELF_TEST=FAIL \(detail)")
      allPassed = allPassed && passed
    }

    let terminalSemaphore = DispatchSemaphore(value: 0)
    var rejectedTruncatedOutput = false
    var terminalDetail = ""
    _ = translateWithOllama(
      "This deliberately long sentence must not be accepted as a complete translation when the model output limit is only four tokens.",
      sourceLanguageCode: "en",
      onProgress: { _ in },
      numPredict: 4
    ) { result in
      switch result {
      case .success(let translated):
        terminalDetail = "unexpected success: \(translated)"
      case .failure(let error):
        let nsError = error as NSError
        rejectedTruncatedOutput = nsError.domain == "TranslateGemma" &&
          nsError.code == -9 &&
          error.localizedDescription.contains("长度上限")
        terminalDetail = error.localizedDescription
      }
      terminalSemaphore.signal()
    }
    if terminalSemaphore.wait(timeout: .now() + 45) == .timedOut {
      print("AI_TERMINAL_SELF_TEST=FAIL timeout")
      return false
    }
    print(rejectedTruncatedOutput
      ? "AI_TERMINAL_SELF_TEST=PASS \(terminalDetail)"
      : "AI_TERMINAL_SELF_TEST=FAIL \(terminalDetail)")
    allPassed = allPassed && rejectedTruncatedOutput
    return allPassed
  }

  private func shouldSpeak(_ text: String) -> Bool {
    return text.count >= 4 && text.count <= maxSelectionSpeakChars
  }

  private func prewarmSystemSpeech() {
    guard !neuralSpeechModeEnabled, englishAccent == "en-US", speechWarmupProcess == nil else { return }
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("huayi-quinn-warmup-\(ProcessInfo.processInfo.processIdentifier)")
      .appendingPathExtension("aiff")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    process.arguments = ["-r", String(speechRate), "-o", outputURL.path, "ready"]
    speechWarmupProcess = process
    process.terminationHandler = { [weak self] _ in
      try? FileManager.default.removeItem(at: outputURL)
      DispatchQueue.main.async {
        self?.speechWarmupProcess = nil
        log("prewarmSystemSpeech: Configured Siri Natural voice is warm.")
      }
    }
    do {
      try process.run()
    } catch {
      speechWarmupProcess = nil
      try? FileManager.default.removeItem(at: outputURL)
      log("prewarmSystemSpeech: Warm-up failed: \(error.localizedDescription)")
    }
  }

  private func speak(_ text: String, languageCode: String) {
    stopSpeaking()
    let requestGeneration = speechGeneration
    let langPrefix = languageCode.lowercased()

    if neuralSpeechModeEnabled,
       let neuralVoice = neuralVoice(for: langPrefix),
       startNeuralSpeech(text, voice: neuralVoice, requestGeneration: requestGeneration) {
      return
    }

    log("speak: Starting zero-network-wait local speech.")
    startSystemSpeech(text, languageCode: languageCode, requestGeneration: requestGeneration)
  }

  private func neuralVoice(for languageCode: String) -> String? {
    if languageCode.hasPrefix("en") { return englishNeuralVoice }

    let voices: [(prefix: String, voice: String)] = [
      ("fr", "fr-FR-DeniseNeural"),
      ("de", "de-DE-KatjaNeural"),
      ("es", "es-ES-ElviraNeural"),
      ("it", "it-IT-ElsaNeural"),
      ("pt", "pt-PT-RaquelNeural"),
      ("ja", "ja-JP-NanamiNeural"),
      ("ko", "ko-KR-SunHiNeural"),
      ("ru", "ru-RU-SvetlanaNeural"),
      ("nl", "nl-NL-ColetteNeural"),
      ("sv", "sv-SE-SofieNeural"),
      ("da", "da-DK-ChristelNeural"),
      ("no", "nb-NO-PernilleNeural"),
      ("fi", "fi-FI-NooraNeural"),
      ("pl", "pl-PL-AgnieszkaNeural"),
      ("tr", "tr-TR-EmelNeural"),
      ("uk", "uk-UA-PolinaNeural")
    ]
    return voices.first { languageCode.hasPrefix($0.prefix) }?.voice
  }

  private func edgeTTSExecutableURL() -> URL? {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let candidates = [
      "\(home)/.local/bin/edge-tts",
      "/opt/homebrew/bin/edge-tts",
      "/usr/local/bin/edge-tts"
    ]
    return candidates.first(where: FileManager.default.isExecutableFile(atPath:)).map(URL.init(fileURLWithPath:))
  }

  @discardableResult
  private func startNeuralSpeech(_ text: String, voice: String, requestGeneration: Int) -> Bool {
    guard let executableURL = edgeTTSExecutableURL() else {
      log("startNeuralSpeech: edge-tts is unavailable; falling back to the system voice.")
      return false
    }

    let audioURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("huayi-speech-\(UUID().uuidString)")
      .appendingPathExtension("mp3")
    guard FileManager.default.createFile(
            atPath: audioURL.path,
            contents: Data(),
            attributes: [.posixPermissions: 0o600]
          ) else {
      log("startNeuralSpeech: Could not create the protected audio file; falling back to the system voice.")
      return false
    }
    let process = Process()
    process.executableURL = executableURL
    process.arguments = [
      "--voice", voice,
      "--rate=-5%",
      "--file", "/dev/stdin",
      "--write-media", audioURL.path
    ]
    let inputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardInput = inputPipe
    process.standardError = errorPipe
    currentSpeechProcess = process
    currentSpeechAudioURL = audioURL

    process.terminationHandler = { [weak self] completedProcess in
      let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
      let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      DispatchQueue.main.async {
        guard let self else {
          try? FileManager.default.removeItem(at: audioURL)
          return
        }
        guard self.speechGeneration == requestGeneration else {
          try? FileManager.default.removeItem(at: audioURL)
          return
        }

        self.currentSpeechProcess = nil
        let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path)
        let byteCount = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        guard completedProcess.terminationStatus == 0, byteCount > 0 else {
          self.removeCurrentSpeechAudio()
          log("startNeuralSpeech: Neural synthesis failed; status: \(completedProcess.terminationStatus), diagnostic length: \(errorText.count).")
          self.startSystemSpeech(text, languageCode: voice, requestGeneration: requestGeneration)
          return
        }

        log("startNeuralSpeech: Synthesized \(byteCount) bytes with \(voice).")
        self.playNeuralAudio(audioURL, requestGeneration: requestGeneration)
      }
    }

    do {
      log("startNeuralSpeech: Synthesizing with \(voice).")
      try process.run()
      if let data = text.data(using: .utf8) {
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
      }
      try inputPipe.fileHandleForWriting.close()
      return true
    } catch {
      if process.isRunning {
        process.terminate()
      }
      try? inputPipe.fileHandleForWriting.close()
      currentSpeechProcess = nil
      removeCurrentSpeechAudio()
      log("startNeuralSpeech: Failed to launch edge-tts: \(error.localizedDescription)")
      return false
    }
  }

  private func playNeuralAudio(_ audioURL: URL, requestGeneration: Int) {
    guard speechGeneration == requestGeneration else {
      try? FileManager.default.removeItem(at: audioURL)
      return
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
    process.arguments = [audioURL.path]
    currentSpeechProcess = process
    process.terminationHandler = { [weak self] _ in
      DispatchQueue.main.async {
        try? FileManager.default.removeItem(at: audioURL)
        guard let self, self.speechGeneration == requestGeneration else { return }
        self.currentSpeechProcess = nil
        self.currentSpeechAudioURL = nil
      }
    }

    do {
      try process.run()
    } catch {
      currentSpeechProcess = nil
      removeCurrentSpeechAudio()
      log("playNeuralAudio: Failed to launch afplay: \(error.localizedDescription)")
    }
  }

  private func startSystemSpeech(_ text: String, languageCode: String, requestGeneration: Int) {
    guard speechGeneration == requestGeneration else { return }

    if languageCode.lowercased().hasPrefix("en") {
      // `say` begins playback immediately and avoids the network and full-file
      // synthesis wait of edge-tts. Prefer the highest-quality downloaded voice
      // for the selected accent, with Ava Premium first for US English.
      let targetLocale = englishAccent
      let selectedVoice = targetLocale == "en-US" ? nil : cachedEnglishVoices[targetLocale]
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
      var arguments = ["-r", String(speechRate)]
      if targetLocale == "en-US" {
        // Omitting `-v` is required for Apple's Siri Natural voices: `say`
        // follows the configured Spoken Content voice (currently US Quinn).
        log("startSystemSpeech: Starting configured US Siri Natural system voice at rate \(speechRate).")
      } else if let selectedVoice {
        arguments += ["-v", selectedVoice.name]
        log("startSystemSpeech: Starting cached local voice '\(selectedVoice.name)' (\(selectedVoice.language), quality: \(selectedVoice.quality)).")
      } else {
        log("startSystemSpeech: No matching downloaded voice for \(targetLocale); using the configured system voice.")
      }
      process.arguments = arguments
      let inputPipe = Pipe()
      process.standardInput = inputPipe
      currentSpeechProcess = process
      process.terminationHandler = { [weak self] _ in
        DispatchQueue.main.async {
          guard let self, self.speechGeneration == requestGeneration else { return }
          self.currentSpeechProcess = nil
        }
      }
      do {
        try process.run()
        if let data = text.data(using: .utf8) {
          try inputPipe.fileHandleForWriting.write(contentsOf: data)
        }
        try inputPipe.fileHandleForWriting.close()
        log("startSystemSpeech: say process launched at rate \(speechRate).")
      } catch {
        if process.isRunning {
          process.terminate()
        }
        try? inputPipe.fileHandleForWriting.close()
        currentSpeechProcess = nil
        log("startSystemSpeech: Failed to run say process: \(error.localizedDescription)")
      }
      return
    }

    let utterance = AVSpeechUtterance(string: text)
    let voices = AVSpeechSynthesisVoice.speechVoices()
    let langPrefix = languageCode.lowercased().split(separator: "-").first.map(String.init) ?? languageCode.lowercased()
    let langVoices = voices.filter { $0.language.lowercased().hasPrefix(langPrefix) }

    // Prefer downloaded Premium/Enhanced voices. Within the same quality tier,
    // prefer natural general-purpose voices over novelty/Eloquence voices.
    let preferredNames = langPrefix.hasPrefix("en")
      ? ["Ava", "Samantha", "Allison", "Susan", "Daniel", "Karen"]
      : []
    let selectedVoice = langVoices.sorted { lhs, rhs in
      if lhs.quality.rawValue != rhs.quality.rawValue {
        return lhs.quality.rawValue > rhs.quality.rawValue
      }
      let lhsRank = preferredNames.firstIndex(of: lhs.name) ?? preferredNames.count
      let rhsRank = preferredNames.firstIndex(of: rhs.name) ?? preferredNames.count
      return lhsRank < rhsRank
    }.first
      ?? AVSpeechSynthesisVoice(language: languageCode)
      ?? AVSpeechSynthesisVoice(language: "en-US")

    if let voice = selectedVoice {
      log("speak: Using voice '\(voice.name)' (\(voice.language), quality: \(voice.quality.rawValue)) for language '\(languageCode)'")
      utterance.voice = voice
    }

    utterance.rate = 0.47
    utterance.pitchMultiplier = 1.0
    utterance.volume = 1.0
    utterance.preUtteranceDelay = 0.03
    utterance.postUtteranceDelay = 0.05
    speaker.speak(utterance)
  }

  private func languageName(for code: String) -> String {
    let normalized = code.lowercased().split(separator: "-").first.map(String.init) ?? code.lowercased()
    let names = [
      "en": "English", "fr": "French", "de": "German", "es": "Spanish",
      "it": "Italian", "pt": "Portuguese", "ja": "Japanese", "ko": "Korean",
      "ru": "Russian", "nl": "Dutch", "sv": "Swedish", "da": "Danish",
      "no": "Norwegian", "fi": "Finnish", "pl": "Polish", "tr": "Turkish",
      "uk": "Ukrainian", "ar": "Arabic", "hi": "Hindi", "vi": "Vietnamese"
    ]
    return names[normalized] ?? "the source language"
  }

  private func translateGemmaPrompt(_ text: String, sourceLanguageCode: String) -> String {
    let sourceCode = sourceLanguageCode.lowercased().hasPrefix("en") ? "en" : sourceLanguageCode
    let sourceName = languageName(for: sourceCode)
    let technicalTermInstruction: String
    if shouldUseLocalAI(for: text), !text.contains(" ") {
      technicalTermInstruction = " If the source is a technical proper name without a direct Chinese equivalent, preserve the original name and add a concise Chinese meaning in parentheses."
    } else {
      technicalTermInstruction = ""
    }

    return """
    Translate \(sourceName) (\(sourceCode)) into natural Simplified Chinese (zh-CN). Preserve meaning, tone, and terminology.\(technicalTermInstruction) Output only the translation.

    \(text)
    """
  }

  private func cleanTranslateGemmaResponse(_ response: String) -> String {
    var cleaned = response
    for token in ["<end_of_turn>", "<eos>", "<bos>", "<pad>", "</s>", "<s>"] {
      cleaned = cleaned.replacingOccurrences(of: token, with: "")
    }
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  @discardableResult
  private func translateWithOllama(
    _ text: String,
    sourceLanguageCode: String,
    onProgress: @escaping (String) -> Void = { _ in },
    numPredict: Int? = nil,
    completion: @escaping (Result<String, Error>) -> Void
  ) -> URLSessionDataTask? {
    guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else {
      completion(.failure(NSError(domain: "TranslateGemma", code: -1, userInfo: [NSLocalizedDescriptionKey: "本地 AI 地址无效"])))
      return nil
    }

    let payload: [String: Any] = [
      "model": localAIModel,
      "prompt": translateGemmaPrompt(text, sourceLanguageCode: sourceLanguageCode),
      "stream": true,
      "keep_alive": -1,
      "options": [
        "temperature": 0.1,
        "num_predict": numPredict ?? min(4096, max(256, text.count * 3))
      ]
    ]

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 180
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: payload)
    } catch {
      completion(.failure(error))
      return nil
    }

    let stream = OllamaStreamRequest(onProgress: onProgress) { [weak self] result in
      guard let self else {
        completion(.failure(NSError(domain: "TranslateGemma", code: -6, userInfo: [NSLocalizedDescriptionKey: "AI 请求已结束"])))
        return
      }
      completion(result.map(self.cleanTranslateGemmaResponse))
    }
    activeOllamaStream = stream
    let task = stream.start(request: request)
    return task
  }

  @discardableResult
  private func translateWithGoogle(_ text: String, completion: @escaping (Result<String, Error>) -> Void) -> URLSessionDataTask? {
    guard let url = URL(string: "https://translate.googleapis.com/translate_a/single") else {
      completion(.failure(NSError(domain: "GoogleTranslate", code: -4, userInfo: [NSLocalizedDescriptionKey: "请求地址无效"])))
      return nil
    }

    var form = URLComponents()
    form.queryItems = [
      URLQueryItem(name: "client", value: "gtx"),
      URLQueryItem(name: "sl", value: "auto"),
      URLQueryItem(name: "tl", value: "zh-CN"),
      URLQueryItem(name: "dt", value: "t"),
      URLQueryItem(name: "q", value: text)
    ]
    guard let body = form.percentEncodedQuery?.data(using: .utf8) else {
      completion(.failure(NSError(domain: "GoogleTranslate", code: -5, userInfo: [NSLocalizedDescriptionKey: "请求编码失败"])))
      return nil
    }

    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    request.httpBody = body
    request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.4.0"
    request.setValue("Huayi/\(appVersion) (macOS)", forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    let session = URLSession(configuration: configuration)
    let task = session.dataTask(with: request) { data, response, error in
      defer { session.finishTasksAndInvalidate() }
      if let error {
        completion(.failure(error))
        return
      }

      if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        completion(.failure(NSError(domain: "GoogleTranslate", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])))
        return
      }

      guard let data else {
        completion(.failure(NSError(domain: "GoogleTranslate", code: -1, userInfo: [NSLocalizedDescriptionKey: "响应为空"])))
        return
      }

      do {
        let json = try JSONSerialization.jsonObject(with: data)
        guard
          let outer = json as? [Any],
          let segments = outer.first as? [Any]
        else {
          throw NSError(domain: "GoogleTranslate", code: -2, userInfo: [NSLocalizedDescriptionKey: "响应格式异常"])
        }

        let translated = segments.compactMap { segment -> String? in
          guard let values = segment as? [Any] else { return nil }
          return values.first as? String
        }.joined().trimmingCharacters(in: .whitespacesAndNewlines)

        if translated.isEmpty {
          throw NSError(domain: "GoogleTranslate", code: -3, userInfo: [NSLocalizedDescriptionKey: "译文为空"])
        }

        completion(.success(translated))
      } catch {
        completion(.failure(error))
      }
    }
    task.resume()
    return task
  }
}

private func runClipboardSnapshotSelfTest() -> Bool {
  let pasteboard = NSPasteboard(name: NSPasteboard.Name("HuayiClipboardSelfTest-\(UUID().uuidString)"))
  pasteboard.clearContents()
  pasteboard.setString("before", forType: .string)

  let restorableSnapshot = PasteboardSnapshot(pasteboard: pasteboard)
  pasteboard.clearContents()
  pasteboard.setString("captured", forType: .string)
  let capturedChangeCount = pasteboard.changeCount
  guard restorableSnapshot.restore(to: pasteboard, ifUnchangedSince: capturedChangeCount),
        pasteboard.string(forType: .string) == "before" else {
    print("CLIPBOARD_SELF_TEST=FAIL restore")
    return false
  }

  let guardedSnapshot = PasteboardSnapshot(pasteboard: pasteboard)
  pasteboard.clearContents()
  pasteboard.setString("captured-again", forType: .string)
  let staleChangeCount = pasteboard.changeCount
  pasteboard.clearContents()
  pasteboard.setString("newer-user-content", forType: .string)
  guard !guardedSnapshot.restore(to: pasteboard, ifUnchangedSince: staleChangeCount),
        pasteboard.string(forType: .string) == "newer-user-content" else {
    print("CLIPBOARD_SELF_TEST=FAIL guard")
    return false
  }

  print("CLIPBOARD_SELF_TEST=PASS")
  return true
}

if CommandLine.arguments.contains("--clipboard-self-test") {
  exit(runClipboardSnapshotSelfTest() ? 0 : 1)
} else if CommandLine.arguments.contains("--filter-self-test") {
  exit(TranslatorApp().runFilterSelfTest() ? 0 : 1)
} else if CommandLine.arguments.contains("--routing-self-test") {
  exit(TranslatorApp().runTranslationRoutingSelfTest() ? 0 : 1)
} else if CommandLine.arguments.contains("--ai-self-test") {
  let testApp = TranslatorApp()
  exit(testApp.runLocalAIIntegrationSelfTest() ? 0 : 1)
} else {
  let app = NSApplication.shared
  let delegate = TranslatorApp()
  app.delegate = delegate
  app.run()
}
