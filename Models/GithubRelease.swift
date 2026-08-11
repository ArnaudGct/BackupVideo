import Foundation

struct GithubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let draft: Bool
    let prerelease: Bool
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case draft
        case prerelease
    }
}
