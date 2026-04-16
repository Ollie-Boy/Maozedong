import Foundation

extension Notification.Name {
    /// Posted when `HorizontalReaderPager` commits to a new center document (poetry + anthology).
    static let readerPagerActiveDocumentDidChange = Notification.Name("MaozedongReader.readerPagerActiveDocumentDidChange")
}

enum ReaderPagerNotificationKeys {
    static let documentId = "documentId"
}
