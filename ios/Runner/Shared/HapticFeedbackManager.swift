//
//  HapticFeedbackManager.swift
//  Runner
//
//  Created by 정민호 on 11/24/23.
//

import UIKit

class HapticFeedbackManager {
    // Selection Feedback 예시
    func selectionFeedbackExample() {
        let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        selectionFeedbackGenerator.prepare()
        selectionFeedbackGenerator.selectionChanged()
    }

    // Notification Feedback 메서드
    func notificationFeedback(style: String) {
        UINotificationFeedbackGenerator.notificationFeedback(type: style)
    }

    // Impact Feedback 메서드
    func impactFeedback(style: String) {
        if let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: style) {
            impactFeedbackGenerator.prepare()
            impactFeedbackGenerator.impactOccurred()
            // 추가적으로 필요한 작업 수행
        }
    }
}

extension UIImpactFeedbackGenerator {

    static func impactFeedback(style: String) -> UIImpactFeedbackGenerator? {
        guard let feedbackStyle = feedbackStyle(from: style) else { return nil }
        return UIImpactFeedbackGenerator(style: feedbackStyle)
    }

    convenience init?(style: String) {
        guard let feedbackStyle = UIImpactFeedbackGenerator.feedbackStyle(from: style) else { return nil }
        self.init(style: feedbackStyle)
    }

    // 메서드 이름 변경
    private static func feedbackStyle(from style: String) -> UIImpactFeedbackGenerator.FeedbackStyle? {
        switch style.lowercased() {
        case "light":
            return .light
        case "medium":
            return .medium
        case "heavy":
            return .heavy
        case "soft":
            if #available(iOS 13.0, *) {
                return .soft
            } else {
                return nil
            }
        case "rigid":
            if #available(iOS 13.0, *) {
                return .rigid
            } else {
                return nil
            }
        default:
            return nil
        }
    }
}

extension UINotificationFeedbackGenerator {
    static func notificationFeedback(type: String) {
        guard let feedbackType = notificationType(from: type) else { return }
        let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        notificationFeedbackGenerator.prepare()
        notificationFeedbackGenerator.notificationOccurred(feedbackType)
    }

    // 문자열로부터 UINotificationFeedbackGenerator.FeedbackType을 반환하는 메서드
    private static func notificationType(from type: String) -> UINotificationFeedbackGenerator.FeedbackType? {
        switch type.lowercased() {
        case "success":
            return .success
        case "warning":
            return .warning
        case "error":
            return .error
        default:
            return nil
        }
    }
}
