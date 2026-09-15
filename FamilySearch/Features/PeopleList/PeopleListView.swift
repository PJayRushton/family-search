import SwiftUI

struct PeopleListView: View {
    @State private var viewModel: PeopleListViewModel

    init(viewModel: PeopleListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content.navigationTitle("People")
        }
        .task { await viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading people…")
        case .empty:
            ContentUnavailableView("No People", systemImage: "person.2", description: Text("There are no records to show."))
        case let .content(people, isStale, notice):
            List(people) { person in
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name.fullName).font(.headline)
                    Text(person.lifespan).foregroundStyle(.secondary)
                }
            }
            .safeAreaInset(edge: .top) {
                if isStale, let notice {
                    Text(notice).font(.caption).padding(.vertical, 6).frame(maxWidth: .infinity).background(.yellow.opacity(0.2))
                }
            }
        case let .failure(message):
            ContentUnavailableView {
                Label("Couldn't Load People", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await viewModel.load() } }
            }
        }
    }
}
