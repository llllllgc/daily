import WidgetKit
import SwiftUI

struct DailyEntry: TimelineEntry {
  let date: Date
  let completed: Int
  let total: Int
  let remaining: Int
  let tasks: [[String: String]]
}

struct DailyProvider: TimelineProvider {
  func placeholder(in context: Context) -> DailyEntry {
    DailyEntry(date: Date(), completed: 2, total: 5, remaining: 3, tasks: [["title": "今日事项", "time": "09:00"]])
  }
  func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
    completion(entries().first ?? placeholder(in: context))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
    let values = entries()
    let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 3600)
    completion(Timeline(entries: values.isEmpty ? [DailyEntry(date: Date(), completed: 0, total: 0, remaining: 0, tasks: [])] : values, policy: .after(tomorrow)))
  }
  private func entries() -> [DailyEntry] {
    guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.daily"),
      let data = try? Data(contentsOf: root.appendingPathComponent("daily-widget.json")),
      let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let days = payload["days"] as? [[String: Any]] else { return [] }
    let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX")
    let today = Calendar.current.startOfDay(for: Date())
    return days.compactMap { day in
      guard let key = day["date"] as? String, let date = formatter.date(from: key), date >= today else { return nil }
      return DailyEntry(date: date == today ? Date() : date, completed: day["completed"] as? Int ?? 0, total: day["total"] as? Int ?? 0, remaining: day["remaining"] as? Int ?? 0, tasks: day["tasks"] as? [[String: String]] ?? [])
    }
  }
}

struct DailyWidgetView: View {
  let entry: DailyEntry
  @Environment(\.widgetFamily) var family
  private let pine = Color(red: 0.04, green: 0.34, blue: 0.28)
  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text("Daily.").font(.system(.title3, design: .serif).bold())
        Spacer()
        Image(systemName: "calendar").foregroundColor(pine)
      }
      Text("已完成 \(entry.completed)/\(entry.total)").font(.subheadline.weight(.semibold)).foregroundColor(pine)
      ProgressView(value: Double(entry.completed), total: Double(max(1, entry.total))).tint(pine)
      if entry.tasks.isEmpty {
        Text(entry.total == 0 ? "今天暂无安排" : entry.remaining == 0 ? "今天的事项已处理" : "打开 Daily 查看安排").font(.caption).foregroundColor(.secondary)
      } else {
        ForEach(Array(entry.tasks.prefix(family == .systemSmall ? 1 : 3).enumerated()), id: \.offset) { _, task in
          HStack(spacing: 8) {
            Text(task["time"] ?? "").monospacedDigit().foregroundColor(pine)
            Text(task["title"] ?? "").lineLimit(1)
          }.font(.caption)
        }
      }
      Spacer(minLength: 0)
    }
    .widgetURL(URL(string: "daily://today"))
    .modifier(DailyBackground())
  }
}
struct DailyBackground: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      content.containerBackground(for: .widget) { Color(red: 0.96, green: 0.96, blue: 0.93) }
    } else { content.padding().background(Color(red: 0.96, green: 0.96, blue: 0.93)) }
  }
}
@main
struct DailyWidget: Widget {
  let kind = "DailyTodayWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DailyProvider()) { entry in DailyWidgetView(entry: entry) }
      .configurationDisplayName("今日事项")
      .description("查看今日完成进度与待办，轻点打开 Daily。")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}
