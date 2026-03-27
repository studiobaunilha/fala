import Foundation

@MainActor
public protocol InsertionReviewPresenting: AnyObject {
    func present(insertedText: String, using inserter: any TextInserting)
    func dismiss()
}
