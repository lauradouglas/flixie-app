import SwiftUI
import WidgetKit

private struct SearchEntry: TimelineEntry {
    let date: Date
}

private struct SearchProvider: TimelineProvider {
    func placeholder(in context: Context) -> SearchEntry { SearchEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (SearchEntry) -> Void) {
        completion(SearchEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SearchEntry>) -> Void) {
        completion(Timeline(entries: [SearchEntry(date: .now)], policy: .never))
    }
}

private struct SearchWidgetView: View {
    @Environment(\.widgetFamily) private var family
    private let purple = Color(red: 124 / 255, green: 77 / 255, blue: 1)
    private let background = Color(red: 18 / 255, green: 10 / 255, blue: 36 / 255)

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            (Text("flix").foregroundColor(.white) + Text("ie").foregroundColor(purple))
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.5)
                .accessibilityLabel("Flixie")
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                Text(family == .systemSmall ? "Search" : "Search movies & shows")
                    .font(.system(size: 16, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundColor(.white)
            .padding(12)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Search Flixie")
        .accessibilityHint("Opens Discover with the search field ready to type")
        .widgetURL(URL(string: "flixie:///search?focus=1"))
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(background, for: .widget)
        } else {
            content.padding(16).background(background)
        }
    }
}

struct FlixieSearchWidget: Widget {
    let kind = "FlixieSearchWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SearchProvider()) { _ in
            SearchWidgetView()
        }
        .configurationDisplayName("Search Flixie")
        .description("Jump into Discover and search for your next favourite.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}


private struct WatchlistEntry: TimelineEntry {
    let date: Date
    let items: [[String: Any]]
    let signedIn: Bool
}

private struct WatchlistProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchlistEntry {
        WatchlistEntry(date: .now, items: [], signedIn: true)
    }
    private func entry() -> WatchlistEntry {
        let defaults = UserDefaults(suiteName: "group.com.flixie.flixieApp")
        return WatchlistEntry(date: .now,
            items: defaults?.array(forKey: "watchlistItems") as? [[String: Any]] ?? [],
            signedIn: defaults?.bool(forKey: "watchlistSignedIn") ?? false)
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchlistEntry) -> Void) {
        completion(entry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchlistEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .never))
    }
}

private struct WatchlistWidgetView: View {
    let entry: WatchlistEntry
    @Environment(\.widgetFamily) private var family
    private let purple = Color(red: 124 / 255, green: 77 / 255, blue: 1)
    private let background = Color(red: 18 / 255, green: 10 / 255, blue: 36 / 255)

    private func poster(_ item: [String: Any]) -> UIImage? {
        guard let name = item["file"] as? String, !name.contains("/"),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.flixie.flixieApp") else { return nil }
        return UIImage(contentsOfFile: container.appendingPathComponent("watchlist/" + name).path)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                (Text("flix").foregroundColor(.white) + Text("ie").foregroundColor(purple))
                    .font(.system(size: 24, weight: .heavy)).accessibilityLabel("Flixie")
                Spacer(minLength: 4)
                if family == .systemMedium {
                    Label("Watchlist", systemImage: "bookmark.fill")
                        .font(.caption.weight(.semibold)).foregroundColor(.white)
                }
            }
            if family == .systemMedium && !entry.items.isEmpty {
                GeometryReader { geometry in
                    HStack(spacing: 8) {
                        ForEach(0..<min(4, entry.items.count), id: \.self) { index in
                            let item = entry.items[index]
                            Group {
                                if let image = poster(item) {
                                    Image(uiImage: image).resizable().scaledToFill()
                                } else {
                                    ZStack {
                                        background.opacity(0.6)
                                        Text(item["title"] as? String ?? "Saved title")
                                            .font(.caption).multilineTextAlignment(.center).padding(5)
                                    }
                                }
                            }
                            .frame(width: (geometry.size.width - 24) / 4, height: geometry.size.height)
                            .clipped().clipShape(RoundedRectangle(cornerRadius: 7))
                            .accessibilityLabel(item["title"] as? String ?? "Saved title")
                        }
                    }
                }
            } else {
                Spacer(minLength: 0)
                Label("Watchlist", systemImage: "bookmark.fill")
                    .font(.callout.weight(.semibold))
                Text(entry.signedIn ? (entry.items.isEmpty ? "Save something for later" : "Your next watches, ready") : "Sign in to see your saved titles")
                    .font(.caption).foregroundColor(.white.opacity(0.85))
            }
        }
        .foregroundColor(.white)
        .widgetURL(URL(string: "flixie:///watchlist"))
        .accessibilityHint("Opens your Flixie watchlist")
    }
    var body: some View {
        if #available(iOS 17.0, *) { content.containerBackground(background, for: .widget) }
        else { content.padding(16).background(background) }
    }
}

struct FlixieWatchlistWidget: Widget {
    let kind = "FlixieWatchlistWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchlistProvider()) { entry in
            WatchlistWidgetView(entry: entry)
        }
        .configurationDisplayName("Flixie Watchlist")
        .description("Open your watchlist. The wide widget shows your four most recently saved titles.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FlixieWidgets: WidgetBundle {
    var body: some Widget {
        FlixieSearchWidget()
        FlixieWatchlistWidget()
    }
}
