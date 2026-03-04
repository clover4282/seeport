import Foundation

struct ProcessInfo: Identifiable, Hashable {
    let id: Int32
    let name: String
    let user: String

    var pid: Int32 { id }
}
