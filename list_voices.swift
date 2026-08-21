import AVFoundation

let voices = AVSpeechSynthesisVoice.speechVoices()
  .filter { $0.language.lowercased().hasPrefix("en") }
  .sorted {
    if $0.quality.rawValue != $1.quality.rawValue {
      return $0.quality.rawValue > $1.quality.rawValue
    }
    return $0.name < $1.name
  }

for voice in voices {
  print("\(voice.name)\t\(voice.language)\tquality=\(voice.quality.rawValue)\t\(voice.identifier)")
}
