import AVFoundation

class TTSManager {
    // 싱글턴 패턴을 사용하여 인스턴스화
    static let shared = TTSManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    internal func play(_ string: String) {
        // 현재 말할 단어
        let utterance = AVSpeechUtterance(string: string)

        // 언어 로컬라이징
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")

        // 속도 (1.0에 가까워질 수록 빨라짐)
        utterance.rate = 0.7

        // 실행 중인 말 즉시 종료
        //synthesizer.stopSpeaking(at: .immediate)

        // 단어 출력
        synthesizer.speak(utterance)
    }
    
    internal func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}