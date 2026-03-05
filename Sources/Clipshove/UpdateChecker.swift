import Foundation

enum UpdateChecker {
    static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    static private(set) var latestVersion: String?
    static private(set) var releaseURL: String?

    static var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return compare(latest, isNewerThan: currentVersion)
    }

    static func check() {
        guard let url = URL(string: "https://api.github.com/repos/jusunglee/clipshove/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String else { return }

            let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            DispatchQueue.main.async {
                latestVersion = version
                releaseURL = htmlURL
            }
        }.resume()
    }

    private static func compare(_ a: String, isNewerThan b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let count = max(aParts.count, bParts.count)
        for i in 0..<count {
            let aVal = i < aParts.count ? aParts[i] : 0
            let bVal = i < bParts.count ? bParts[i] : 0
            if aVal > bVal { return true }
            if aVal < bVal { return false }
        }
        return false
    }
}
