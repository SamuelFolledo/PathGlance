import Foundation

/// Which preset a widget is on, and the edits saved to each preset. A preset keeps its
/// own edits: there is no separate "custom" look.
struct PresetBook<Look: Hashable & Codable>: Hashable {
    /// The preset the widget is drawing.
    var selected: String
    /// Looks saved over a built-in preset, by the preset's id. A preset at its built-in
    /// values has no entry.
    var edits: [String: Look] = [:]

    /// The look `id` has now: its saved edits, or `builtIn` when it has none.
    func look(_ id: String, builtIn: Look) -> Look {
        edits[id] ?? builtIn
    }

    /// Records `look` as what `id` now is. A look equal to the built-in one clears the edits.
    mutating func save(_ look: Look, for id: String, builtIn: Look) {
        selected = id
        edits[id] = look == builtIn ? nil : look
    }

    /// Works out the book when the app starts.
    ///
    /// - `saved` is the look the widget is drawing with, which always wins.
    /// - `storedID` and `storedEdits` are what this build wrote last time, if it has run.
    /// - `custom` is the one custom look older builds kept, if any.
    ///
    /// An older build's look that matches no preset becomes edits on `fallback`. Its
    /// spare custom look does too, unless `fallback` is the preset in use: a preset
    /// cannot be both as built and edited, and what the widget shows is kept.
    static func resolve(saved: Look, storedID: String?, storedEdits: [String: Look], custom: Look?,
                        builtIn: [(id: String, look: Look)], fallback: String) -> PresetBook {
        func original(_ id: String) -> Look? { builtIn.first { $0.id == id }?.look }

        if let storedID, let own = original(storedID) {
            var book = PresetBook(selected: storedID, edits: storedEdits.filter { original($0.key) != nil && original($0.key) != $0.value })
            book.save(saved, for: storedID, builtIn: own)
            return book
        }
        var book = PresetBook(selected: fallback)
        if let match = builtIn.first(where: { $0.look == saved }) {
            book.selected = match.id
            if let custom, match.id != fallback, let own = original(fallback), custom != own {
                book.edits[fallback] = custom
            }
        } else if let own = original(fallback) {
            book.save(saved, for: fallback, builtIn: own)
        }
        return book
    }
}
