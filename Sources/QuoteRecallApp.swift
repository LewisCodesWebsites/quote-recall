import SwiftUI
import UIKit

// MARK: - App

@main
struct QuoteRecallApp: App {
    @StateObject private var store = QuoteStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            PractiseView()
                .tabItem { Label("Practise", systemImage: "brain.head.profile") }
            QuoteListView()
                .tabItem { Label("Quotes", systemImage: "text.quote") }
        }
    }
}

// MARK: - Model

struct QuoteCard: Identifiable, Codable, Equatable {
    var id = UUID()
    var character: String
    var moment: String
    var quote: String
    var themes: [String]
    var box = 0
    var due = Date()
    var attempts = 0
    var correct = 0

    var isFilled: Bool {
        !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum Schedule {
    // Box 0: now, 1: 10 min, 2: 1 day, 3: 2 days, 4: 4 days, 5: 7 days
    static let intervals: [TimeInterval] = [0, 10 * 60, 86_400, 2 * 86_400, 4 * 86_400, 7 * 86_400]
    static let maxBox = 5
}

final class QuoteStore: ObservableObject {
    @Published var cards: [QuoteCard] = [] {
        didSet { save() }
    }

    private let url: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("cards.json")

    init() {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([QuoteCard].self, from: data) {
            cards = decoded
        } else {
            cards = Seed.inspectorCalls
        }
        fillMissingFromSeed()
        save()
    }

    // Fills any empty quote whose prompt matches a built-in one, keeping progress and your own edits.
    private func fillMissingFromSeed() {
        cards = cards.map { card in
            guard !card.isFilled,
                  let seed = Seed.inspectorCalls.first(where: { $0.character == card.character && $0.moment == card.moment })
            else { return card }
            var c = card
            c.quote = seed.quote
            c.box = 0
            c.due = Date()
            return c
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(cards) {
            try? data.write(to: url, options: .atomic)
        }
    }

    var filled: [QuoteCard] { cards.filter { $0.isFilled } }

    var allThemes: [String] {
        Array(Set(cards.flatMap { $0.themes })).sorted()
    }

    var characters: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for card in cards where !seen.contains(card.character) {
            seen.insert(card.character)
            out.append(card.character)
        }
        return out
    }

    func record(_ id: UUID, correct: Bool) {
        guard let i = cards.firstIndex(where: { $0.id == id }) else { return }
        var c = cards[i]
        c.attempts += 1
        if correct {
            c.correct += 1
            c.box = min(c.box + 1, Schedule.maxBox)
        } else {
            c.box = 0
        }
        c.due = Date().addingTimeInterval(Schedule.intervals[c.box])
        cards[i] = c
    }

    func upsert(_ card: QuoteCard) {
        if let i = cards.firstIndex(where: { $0.id == card.id }) {
            cards[i] = card
        } else {
            cards.append(card)
        }
    }

    func delete(ids: [UUID]) {
        cards.removeAll { ids.contains($0.id) }
    }

    func resetProgress() {
        cards = cards.map { card in
            var c = card
            c.box = 0
            c.due = Date()
            c.attempts = 0
            c.correct = 0
            return c
        }
    }

    func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(cards) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    func importJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([QuoteCard].self, from: data),
              !decoded.isEmpty else { return false }
        cards = decoded
        return true
    }
}

// MARK: - Built-in Inspector Calls quotes

enum Seed {
    static let inspectorCalls: [QuoteCard] = [
        QuoteCard(character: "Mr Birling", moment: "His speech about a man looking after himself and his own (Act 1)", quote: "a man has to mind his own business and look after himself and his own", themes: ["Responsibility", "Class"]),
        QuoteCard(character: "Mr Birling", moment: "His Titanic prediction (Act 1)", quote: "unsinkable, absolutely unsinkable", themes: ["Dramatic irony", "Context"]),
        QuoteCard(character: "Mr Birling", moment: "Mocking community with the bees image (Act 1)", quote: "mixed up together like bees in a hive", themes: ["Responsibility", "Socialism"]),
        QuoteCard(character: "Mrs Birling", moment: "Dismissing the girl because of her class (Act 2)", quote: "Girls of that class", themes: ["Class"]),
        QuoteCard(character: "Mrs Birling", moment: "Blaming the father of the child (Act 2)", quote: "I blame the young man who was the father of the child", themes: ["Responsibility", "Dramatic irony"]),
        QuoteCard(character: "Mrs Birling", moment: "Refusing to accept any blame (Act 2)", quote: "I accept no blame at all", themes: ["Responsibility", "Age"]),
        QuoteCard(character: "Sheila", moment: "Admitting her guilt over Milwards", quote: "I know I'm to blame - and I'm desperately sorry", themes: ["Responsibility", "Gender"]),
        QuoteCard(character: "Sheila", moment: "Warning her mother about building a wall (Act 2)", quote: "build up a kind of wall between us and that girl", themes: ["Responsibility", "Age"]),
        QuoteCard(character: "Sheila", moment: "Telling her parents they haven't learnt anything (Act 3)", quote: "you don't seem to have learnt anything", themes: ["Age", "Responsibility"]),
        QuoteCard(character: "Eric", moment: "Telling his father he couldn't go to him for help (Act 3)", quote: "you're not the kind of father a chap could go to when he's in trouble", themes: ["Age"]),
        QuoteCard(character: "Eric", moment: "Confronting his mother over the death (Act 3)", quote: "you killed them both", themes: ["Responsibility", "Age"]),
        QuoteCard(character: "Gerald", moment: "Realising the girl is really dead (Act 2)", quote: "I've suddenly realised - taken it in properly - that she's dead", themes: ["Responsibility"]),
        QuoteCard(character: "Gerald", moment: "His relief once it might be a hoax (Act 3)", quote: "Everything's all right now, Sheila", themes: ["Age", "Class"]),
        QuoteCard(character: "Inspector", moment: "Final speech: members of one body (Act 3)", quote: "We are members of one body", themes: ["Responsibility", "Socialism"]),
        QuoteCard(character: "Inspector", moment: "Final speech: the warning about fire and blood (Act 3)", quote: "they will be taught it in fire and blood and anguish", themes: ["Context", "Responsibility"]),
        QuoteCard(character: "Inspector", moment: "Final speech: the millions of Eva Smiths (Act 3)", quote: "millions and millions and millions of Eva Smiths and John Smiths", themes: ["Class", "Socialism"])
    ]
}

// MARK: - Hints and marking

enum Hint {
    // Box 0-1: first letters of every word. Box 2-3: first word only. Box 4+: nothing.
    static func text(for card: QuoteCard) -> String? {
        let words = card.quote.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return nil }
        switch card.box {
        case 0...1:
            return words.map { initials($0) }.joined(separator: " ")
        case 2...3:
            if words.count == 1 { return "1 word" }
            return "\(words[0]) ... (\(words.count) words)"
        default:
            return nil
        }
    }

    static func initials(_ word: String) -> String {
        var out = ""
        var shownFirst = false
        for ch in word {
            if ch.isLetter || ch.isNumber {
                if shownFirst {
                    out.append("_")
                } else {
                    out.append(ch)
                    shownFirst = true
                }
            } else {
                out.append(ch)
            }
        }
        return out
    }
}

enum Grade {
    case perfect, close, wrong
}

enum Matcher {
    static func normalise(_ s: String) -> String {
        var out = ""
        for ch in s.lowercased() {
            if ch == "'" || ch == "\u{2019}" || ch == "\u{2018}" || ch == "-" || ch == "\u{2010}" {
                continue
            }
            if ch.isLetter || ch.isNumber {
                out.append(ch)
            } else {
                out.append(" ")
            }
        }
        return out.split(separator: " ").joined(separator: " ")
    }

    static func distance(_ a: String, _ b: String) -> Int {
        let x = Array(a)
        let y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var prev = Array(0...y.count)
        var cur = Array(repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            cur[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &cur)
        }
        return prev[y.count]
    }

    static func grade(answer: String, target: String) -> Grade {
        let a = normalise(answer)
        let t = normalise(target)
        if a == t { return .perfect }
        if a.isEmpty || t.isEmpty { return .wrong }
        let d = distance(a, t)
        let similarity = 1 - Double(d) / Double(max(a.count, t.count))
        return similarity >= 0.85 ? .close : .wrong
    }

    // Returns each word of the real quote, flagged true if you got it.
    static func matchedWords(answer: String, target: String) -> [(String, Bool)] {
        let targetWords = target.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let tNorm = targetWords.map { normalise($0).replacingOccurrences(of: " ", with: "") }
        let aNorm = normalise(answer).split(separator: " ").map(String.init)
        let n = tNorm.count
        let m = aNorm.count
        var matched = Array(repeating: false, count: n)

        if n > 0 && m > 0 {
            var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    if !tNorm[i].isEmpty && tNorm[i] == aNorm[j] {
                        dp[i][j] = dp[i + 1][j + 1] + 1
                    } else {
                        dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                    }
                }
            }
            var i = 0
            var j = 0
            while i < n && j < m {
                if !tNorm[i].isEmpty && tNorm[i] == aNorm[j] {
                    matched[i] = true
                    i += 1
                    j += 1
                } else if dp[i + 1][j] >= dp[i][j + 1] {
                    i += 1
                } else {
                    j += 1
                }
            }
        }
        for k in 0..<n where tNorm[k].isEmpty {
            matched[k] = true
        }
        return Array(zip(targetWords, matched))
    }
}

// MARK: - Practise tab

struct SessionConfig: Identifiable {
    let id = UUID()
    let ids: [UUID]
}

struct PractiseView: View {
    @EnvironmentObject var store: QuoteStore
    @State private var theme = "All"
    @State private var session: SessionConfig?

    private var pool: [QuoteCard] {
        store.filled.filter { theme == "All" || $0.themes.contains(theme) }
    }

    private var due: [QuoteCard] {
        let now = Date()
        return pool.filter { $0.due <= now }
    }

    private var mastered: Int {
        store.filled.filter { $0.box >= 4 }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Quotes added", value: "\(store.filled.count) of \(store.cards.count)")
                    LabeledContent("Due now", value: "\(due.count)")
                    LabeledContent("Mastered", value: "\(mastered)")
                }

                Section("Focus") {
                    Picker("Theme", selection: $theme) {
                        Text("All themes").tag("All")
                        ForEach(store.allThemes, id: \.self) { t in
                            Text(t).tag(t)
                        }
                    }
                }

                Section {
                    Button {
                        session = SessionConfig(ids: due.map { $0.id })
                    } label: {
                        Label("Practise due (\(due.count))", systemImage: "play.fill")
                    }
                    .disabled(due.isEmpty)

                    Button {
                        session = SessionConfig(ids: pool.map { $0.id })
                    } label: {
                        Label("Practise all (\(pool.count))", systemImage: "shuffle")
                    }
                    .disabled(pool.isEmpty)
                } footer: {
                    Text("You type each quote from memory. New quotes show the first letter of every word. Get it right and the hints fade: then just the first word, then nothing. Get it wrong and it comes back later in the same session and drops back to full hints.")
                }

                if store.filled.count < store.cards.count {
                    Section {
                        Text("Some prompts have no quote yet. Add the exact words from your copy of the play in the Quotes tab.")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Quote Recall")
            .fullScreenCover(item: $session) { s in
                SessionView(ids: s.ids)
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - Session

struct SessionView: View {
    @EnvironmentObject var store: QuoteStore
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [UUID]
    @State private var current: QuoteCard?
    @State private var answer = ""
    @State private var result: Grade?
    @State private var attempts = 0
    @State private var right = 0
    @State private var finished = false
    @FocusState private var focused: Bool

    init(ids: [UUID]) {
        _queue = State(initialValue: ids.shuffled())
    }

    var body: some View {
        NavigationStack {
            Group {
                if finished {
                    finishedView
                } else if let card = current {
                    cardView(card)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End") { dismiss() }
                }
            }
        }
        .onAppear {
            if current == nil && !finished { loadNext() }
        }
    }

    private func cardView(_ card: QuoteCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(queue.count + 1) left")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(card.character)
                    .font(.title2.bold())

                Text(card.moment)
                    .font(.body)

                if !card.themes.isEmpty {
                    Text(card.themes.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let hint = Hint.text(for: card) {
                    Text(verbatim: hint)
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                TextField("Type the quote", text: $answer, axis: .vertical)
                    .lineLimit(2...6)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .focused($focused)
                    .disabled(result != nil)

                if let r = result {
                    resultView(r, card: card)
                }

                if result == nil {
                    HStack {
                        Button("Check") { check() }
                            .buttonStyle(.borderedProminent)
                            .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Show answer") {
                            result = .wrong
                            focused = false
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Next") { next(override: false) }
                            .buttonStyle(.borderedProminent)
                        if result == .wrong && !answer.isEmpty {
                            Button("I was right, count it") { next(override: true) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func resultView(_ r: Grade, card: QuoteCard) -> some View {
        let title: String
        let icon: String
        let color: Color
        switch r {
        case .perfect:
            title = "Perfect"
            icon = "checkmark.circle.fill"
            color = .green
        case .close:
            title = "Close enough, check the red words"
            icon = "checkmark.circle"
            color = .orange
        case .wrong:
            title = "Not quite"
            icon = "xmark.circle.fill"
            color = .red
        }
        return VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            highlighted(Matcher.matchedWords(answer: answer, target: card.quote))
                .font(.title3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func highlighted(_ pairs: [(String, Bool)]) -> Text {
        var text = Text("")
        for (index, pair) in pairs.enumerated() {
            let spacer = index < pairs.count - 1 ? " " : ""
            let piece = Text(verbatim: pair.0 + spacer)
            if pair.1 {
                text = text + piece
            } else {
                text = text + piece.foregroundColor(.red).underline()
            }
        }
        return text
    }

    private var finishedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)
            Text("Session done")
                .font(.title.bold())
            Text("\(right) right out of \(attempts) attempts")
                .foregroundColor(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func loadNext() {
        answer = ""
        result = nil
        while !queue.isEmpty {
            let id = queue.removeFirst()
            if let card = store.cards.first(where: { $0.id == id }), card.isFilled {
                current = card
                focused = true
                return
            }
        }
        current = nil
        finished = true
    }

    private func check() {
        guard let card = current else { return }
        result = Matcher.grade(answer: answer, target: card.quote)
        focused = false
    }

    private func next(override: Bool) {
        guard let card = current, let r = result else { return }
        let counted = override || r != .wrong
        attempts += 1
        if counted {
            right += 1
        } else {
            queue.append(card.id)
        }
        store.record(card.id, correct: counted)
        loadNext()
    }
}

// MARK: - Quotes tab

struct QuoteListView: View {
    @EnvironmentObject var store: QuoteStore
    @State private var editing: QuoteCard?
    @State private var message: String?
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.characters, id: \.self) { name in
                    Section(name) {
                        ForEach(store.cards.filter { $0.character == name }) { card in
                            Button {
                                editing = card
                            } label: {
                                CardRow(card: card)
                            }
                        }
                        .onDelete { offsets in
                            let group = store.cards.filter { $0.character == name }
                            store.delete(ids: offsets.map { group[$0].id })
                        }
                    }
                }
            }
            .navigationTitle("Quotes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editing = QuoteCard(character: "", moment: "", quote: "", themes: [])
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            UIPasteboard.general.string = store.exportJSON()
                            message = "Backup copied. Paste it into Notes to keep it safe."
                        } label: {
                            Label("Copy backup", systemImage: "doc.on.doc")
                        }
                        Button {
                            if let text = UIPasteboard.general.string, store.importJSON(text) {
                                message = "Backup imported."
                            } else {
                                message = "The clipboard doesn't contain a valid backup."
                            }
                        } label: {
                            Label("Import backup from clipboard", systemImage: "square.and.arrow.down")
                        }
                        Button(role: .destructive) {
                            confirmReset = true
                        } label: {
                            Label("Reset progress", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $editing) { card in
                EditCardView(card: card)
                    .environmentObject(store)
            }
            .alert(Text(message ?? ""), isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { store.resetProgress() }
            }
        }
    }
}

struct CardRow: View {
    let card: QuoteCard

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.moment.isEmpty ? "No prompt" : card.moment)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            if card.isFilled {
                Text(card.quote)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Text("Level \(card.box) of \(Schedule.maxBox)")
                    .font(.caption)
                    .foregroundColor(card.box >= 4 ? Color.green : Color.secondary)
            } else {
                Text("Tap to add the quote")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

struct EditCardView: View {
    @EnvironmentObject var store: QuoteStore
    @Environment(\.dismiss) private var dismiss
    @State private var card: QuoteCard
    @State private var themesText: String
    private let isNew: Bool

    init(card: QuoteCard) {
        _card = State(initialValue: card)
        _themesText = State(initialValue: card.themes.joined(separator: ", "))
        isNew = card.character.isEmpty && card.moment.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who and when") {
                    TextField("Character", text: $card.character)
                    TextField("Moment (this is your prompt)", text: $card.moment, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section {
                    TextField("Exact words", text: $card.quote, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text("Quote")
                } footer: {
                    Text("Copy it exactly from your copy of the play. Keep it to the key 2 to 8 words.")
                }
                Section {
                    TextField("e.g. Responsibility, Class", text: $themesText)
                } header: {
                    Text("Themes")
                } footer: {
                    Text("Separate themes with commas.")
                }
            }
            .navigationTitle(isNew ? "New quote" : "Edit quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(card.character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        var updated = card
        updated.character = updated.character.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.moment = updated.moment.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.quote = updated.quote.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.themes = themesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let old = store.cards.first(where: { $0.id == updated.id }), old.quote != updated.quote {
            updated.box = 0
            updated.due = Date()
        }
        store.upsert(updated)
        dismiss()
    }
}
