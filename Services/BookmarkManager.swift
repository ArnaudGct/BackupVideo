import Foundation

class BookmarkManager {
    static let shared = BookmarkManager()
    private let userDefaults = UserDefaults.standard
    private let bookmarksKey = "BackupVideo_Bookmarks"
    
    private var bookmarks: [String: Data] = [:]
    
    private init() {
        loadBookmarks()
    }
    
    private func loadBookmarks() {
        if let saved = userDefaults.dictionary(forKey: bookmarksKey) as? [String: Data] {
            bookmarks = saved
        }
    }
    
    private func saveBookmarks() {
        userDefaults.set(bookmarks, forKey: bookmarksKey)
    }
    
    func saveBookmark(for url: URL, key: String) {
        do {
            // Sans l'App Sandbox, on utilise un bookmark classique (sans security scope)
            let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            bookmarks[key] = data
            saveBookmarks()
        } catch {
            print("Erreur de sauvegarde du bookmark pour \(url): \(error.localizedDescription)")
        }
    }
    
    func getURL(forKey key: String) -> URL? {
        guard let data = bookmarks[key] else { return nil }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                saveBookmark(for: url, key: key)
            }
            return url
        } catch {
            print("Erreur de restauration du bookmark pour \(key): \(error.localizedDescription)")
            return nil
        }
    }
    
    func startAccessing(url: URL) -> Bool {
        return true // Sandbox n'est pas utilisé
    }
    
    func stopAccessing(url: URL) {
        // Rien à faire sans Sandbox
    }
}
