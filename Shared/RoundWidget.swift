import SwiftUI

/// The two lock screen widgets: the rectangle that takes two slots, and the circle that
/// takes one. iOS offers nothing wider than the rectangle.
enum WidgetShape: String, CaseIterable, Identifiable, Codable, Sendable {
    case rectangle, round

    var id: String { rawValue }

    var name: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .round: return "Round"
        }
    }
}

/// What the round widget puts in its circle.
enum RoundContent: String, CaseIterable, Identifiable, Codable, Sendable {
    /// The line and the minutes until its next train.
    case minutes
    /// The line and when its next train leaves.
    case clock
    /// A ring that empties as the train nears, the minutes inside.
    case ring
    /// The line and the minutes until its next two trains.
    case nextTwo
    /// Two lines, the minutes until each one's next train.
    case twoLines

    var id: String { rawValue }
}

/// Everything about how the round widget looks: what a round preset holds.
struct RoundLook: Hashable, Codable, Sendable {
    var content: RoundContent = .minutes
    var font: WidgetFontStyle = .standard
    /// Follows the line's second train: for a walk too long to catch the next one.
    var skipNext = false
    /// AM or PM under a clock time.
    var showsPeriod = false

    enum CodingKeys: String, CodingKey {
        case content, font, skipNext, showsPeriod
    }

    /// Whether `showsPeriod` changes anything: only a clock time has an AM or PM.
    var hasClock: Bool { content == .clock }

    /// What the board is built with for this look.
    var boardStyle: WidgetStyle {
        var style = WidgetStyle()
        style.skipNext = skipNext
        return style
    }
}

extension RoundLook {
    /// A look saved before an option existed still reads, with that option at its default.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        content = try values.decodeIfPresent(RoundContent.self, forKey: .content) ?? content
        font = try values.decodeIfPresent(WidgetFontStyle.self, forKey: .font) ?? font
        skipNext = try values.decodeIfPresent(Bool.self, forKey: .skipNext) ?? skipNext
        showsPeriod = try values.decodeIfPresent(Bool.self, forKey: .showsPeriod) ?? showsPeriod
    }
}

/// A named look for the round widget.
struct RoundPreset: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let detail: String
    let look: RoundLook

    static let builtIn: [RoundPreset] = [
        RoundPreset(id: "minutes", name: "Minutes", detail: "Minutes until the next train",
                    look: RoundLook(content: .minutes, font: .standard)),
        RoundPreset(id: "clock", name: "Clock time", detail: "When the next train leaves",
                    look: RoundLook(content: .clock, font: .standard)),
        RoundPreset(id: "ring", name: "Countdown ring", detail: "A ring that empties as the train nears",
                    look: RoundLook(content: .ring, font: .standard)),
        RoundPreset(id: "nexttwo", name: "Next two", detail: "This train and the one after",
                    look: RoundLook(content: .nextTwo, font: .rounded)),
        RoundPreset(id: "twolines", name: "Two lines", detail: "Minutes for two lines",
                    look: RoundLook(content: .twoLines, font: .condensed)),
    ]

    static func matching(_ look: RoundLook) -> RoundPreset? {
        builtIn.first { $0.look == look }
    }
}

/// What the circle says, worked out apart from drawing it.
struct RoundFace: Hashable, Sendable {
    /// One line's name beside its minutes, for `twoLines`.
    struct Pair: Hashable, Sendable {
        var label: String
        var value: String
    }

    /// The line's name with its delay mark: "33rd?".
    var label = ""
    /// The large text: "4", "Now", "9:20" or "4, 14".
    var value = ""
    /// "min" under minutes, "PM" under a clock time set to show it; empty otherwise.
    var unit = ""
    /// How full the ring is, 0 to 1. Full when the train is `ringMinutes` or more away.
    var fraction = 0.0
    var pairs: [Pair] = []

    /// A full ring is this many minutes.
    static let ringMinutes = 20

    /// Whole minutes until `time`. Zero once it is under a minute away.
    static func minutes(until time: Date, now: Date) -> Int {
        max(0, Int(time.timeIntervalSince(now) / 60))
    }

    /// "Now" under a minute, the minutes under an hour, then the clock time.
    private static func wait(_ time: Date, now: Date) -> (value: String, isMinutes: Bool) {
        let minutes = minutes(until: time, now: now)
        if time.timeIntervalSince(now) < 60 { return ("Now", false) }
        if minutes < 60 { return ("\(minutes)", true) }
        return (CompactTimes.clock(time), false)
    }

    /// The face for `content`, following `line` if the board has it and the board's first
    /// line otherwise. `nil` when the board has no trains.
    static func make(board: Board, content: RoundContent, line: Station?, now: Date, showsPeriod: Bool = false) -> RoundFace? {
        let rows = board.rows.filter { !$0.times.isEmpty }
        guard let row = rows.first(where: { $0.target == line }) ?? rows.first, let next = row.times.first else { return nil }
        var face = RoundFace(label: row.label + row.delay.marker)
        let first = wait(next, now: now)
        switch content {
        case .minutes:
            face.value = first.value
            face.unit = first.isMinutes ? "min" : ""
        case .clock:
            face.value = CompactTimes.clock(next)
            if showsPeriod { face.unit = PathTime.calendar.component(.hour, from: next) < 12 ? "AM" : "PM" }
        case .ring:
            face.value = first.value
            face.fraction = min(1, Double(minutes(until: next, now: now)) / Double(ringMinutes))
        case .nextTwo:
            if first.isMinutes, row.times.count > 1, case let second = wait(row.times[1], now: now), second.isMinutes {
                face.value = "\(first.value), \(second.value)"
            } else {
                face.value = first.value
            }
            face.unit = first.isMinutes ? "min" : ""
        case .twoLines:
            // The followed line first, then the board's other line.
            let ordered = [row] + rows.filter { $0.target != row.target }
            face.pairs = ordered.prefix(2).compactMap { row in
                row.times.first.map { Pair(label: row.label + row.delay.marker, value: wait($0, now: now).value) }
            }
        }
        return face
    }

    /// When the round widget redraws: `now`, then every whole minute after it up to `end`.
    static func minuteDates(from now: Date, until end: Date) -> [Date] {
        var dates = [now]
        var next = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60 + 60)
        while next <= end {
            dates.append(next)
            next = next.addingTimeInterval(60)
        }
        return dates
    }

    /// For VoiceOver: "33rd, 4 min".
    var spokenText: String {
        if !pairs.isEmpty { return pairs.map { "\($0.label) \($0.value)" }.joined(separator: ", ") }
        return [label, [value, unit].filter { !$0.isEmpty }.joined(separator: " ")].joined(separator: ", ")
    }
}

/// The whole round lock screen widget. The widget and the app's preview both draw this.
/// Line names are heavier than the numbers, as on the rectangle.
struct RoundWidgetView: View {
    let face: RoundFace?
    let look: RoundLook

    private func font(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        look.font.font(size: size, weight: weight)
    }

    var body: some View {
        Group {
            if let face {
                switch look.content {
                case .ring: ring(face)
                case .twoLines: twoLines(face)
                case .minutes, .clock, .nextTwo: stacked(face)
                }
            } else {
                Text("No trains")
                    .font(font(11))
                    .multilineTextAlignment(.center)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(face?.spokenText ?? "No upcoming trains")
    }

    private func stacked(_ face: RoundFace) -> some View {
        VStack(spacing: -2) {
            Text(face.label)
                .font(font(11, WidgetFontStyle.nameWeight))
            Text(face.value)
                .font(font(face.value.count > 2 ? 18 : 26, .semibold))
                .contentTransition(.numericText())
            if !face.unit.isEmpty {
                Text(face.unit)
                    .font(font(10))
            }
        }
        .padding(.horizontal, 7)
    }

    private func ring(_ face: RoundFace) -> some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.25), lineWidth: 5)
            Circle()
                .trim(from: 0, to: face.fraction)
                .stroke(.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text(face.value)
                    .font(font(face.value.count > 2 ? 15 : 22, .semibold))
                    .contentTransition(.numericText())
                Text(face.label)
                    .font(font(10, WidgetFontStyle.nameWeight))
            }
            .padding(.horizontal, 11)
        }
        .padding(3)
    }

    private func twoLines(_ face: RoundFace) -> some View {
        VStack(spacing: 0) {
            ForEach(face.pairs, id: \.self) { pair in
                (Text(pair.label).font(font(13, WidgetFontStyle.nameWeight)) + Text(" \(pair.value)").font(font(13)))
            }
        }
        .padding(.horizontal, 7)
    }
}
