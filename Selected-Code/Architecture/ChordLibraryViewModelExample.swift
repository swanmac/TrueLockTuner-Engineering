import Foundation
import Combine

/// Curated example derived from True Lock Tuner's production chord library.
///
/// Demonstrates:
/// - ObservableObject state management
/// - dependency injection
/// - Combine subscriptions
/// - debounced search
/// - derived/filterable presentation state
/// - loading and error handling
final class ChordLibraryViewModelExample: ObservableObject {

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case open = "Open"
        case barre = "Barre"
        case beginner = "Beginner"
        case seventh = "7th"

        var id: String { rawValue }
    }

    // MARK: - UI State

    @Published var searchText = ""
    @Published var selectedFilter: Filter = .all

    @Published private(set) var allChords: [ChordSummary] = []
    @Published private(set) var filteredChords: [ChordSummary] = []

    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?

    // MARK: - Dependencies

    private let libraryService: ChordLibraryProviding
    private let searchService: ChordSearching

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        libraryService: ChordLibraryProviding,
        searchService: ChordSearching
    ) {
        self.libraryService = libraryService
        self.searchService = searchService

        bindLibrary()
        bindSearchAndFilters()
    }

    // MARK: - Public API

    func load() {
        isLoading = true
        loadError = nil
        libraryService.loadChords()
    }

    // MARK: - Bindings

    private func bindLibrary() {
        libraryService.chordsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chords in
                guard let self else { return }

                self.allChords = chords
                self.applyFilters()
                self.isLoading = false
            }
            .store(in: &cancellables)

        libraryService.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.loadError = error
            }
            .store(in: &cancellables)
    }

    private func bindSearchAndFilters() {
        $searchText
            .debounce(
                for: .milliseconds(150),
                scheduler: DispatchQueue.main
            )
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)

        $selectedFilter
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }

    // MARK: - Filtering

    private func applyFilters() {
        var results = searchService.search(
            query: searchText,
            in: allChords
        )

        switch selectedFilter {

        case .all:
            break

        case .open:
            results = results.filter {
                $0.tags.contains(.open)
            }

        case .barre:
            results = results.filter {
                $0.tags.contains(.barre)
            }

        case .beginner:
            results = results.filter {
                $0.difficulty == .beginner
            }

        case .seventh:
            results = results.filter {
                $0.quality == .dominant7 ||
                $0.quality == .major7 ||
                $0.quality == .minor7
            }
        }

        filteredChords = results.sorted {
            $0.displayName < $1.displayName
        }
    }
}


// MARK: - Showcase Abstractions

protocol ChordLibraryProviding {
    var chordsPublisher: AnyPublisher<[ChordSummary], Never> { get }
    var errorPublisher: AnyPublisher<String?, Never> { get }

    func loadChords()
}

protocol ChordSearching {
    func search(
        query: String,
        in chords: [ChordSummary]
    ) -> [ChordSummary]
}


/// Simplified public model used only for this engineering example.
struct ChordSummary {
    let displayName: String
    let quality: ChordQuality
    let difficulty: ChordDifficulty
    let tags: Set<ChordTag>
}

enum ChordQuality {
    case major
    case minor
    case dominant7
    case major7
    case minor7
}

enum ChordDifficulty {
    case beginner
    case intermediate
    case advanced
}

enum ChordTag: Hashable {
    case open
    case barre
}
