import SwiftUI

struct PeopleListView: View {
    @State private var viewModel: PeopleListViewModel
    private let makePortraitViewModel: (PortraitReference?) -> PortraitViewModel
    private let onSelectPerson: (PersonID) -> Void

    init(
        viewModel: PeopleListViewModel,
        makePortraitViewModel: @escaping (PortraitReference?) -> PortraitViewModel,
        onSelectPerson: @escaping (PersonID) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makePortraitViewModel = makePortraitViewModel
        self.onSelectPerson = onSelectPerson
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
            ContentUnavailableView(
                "No People",
                systemImage: "person.2",
                description: Text("There are no records to show.")
            )
        case let .content(rows, isStale, notice):
            List(rows) { row in
                Button {
                    viewModel.selectPerson(id: row.id)
                    onSelectPerson(row.id)
                } label: {
                    HStack(spacing: 12) {
                        PortraitView(viewModel: makePortraitViewModel(row.portrait))
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.name).font(.headline).foregroundStyle(.primary)
                            Text(row.lifespan).foregroundStyle(.secondary)
                            Text(row.birthplace).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .safeAreaInset(edge: .top) {
                if isStale, let notice {
                    Text(notice)
                        .font(.caption)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(.yellow.opacity(0.2))
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

#Preview("Saved people") {
    let container = PreviewContainer.populated()
    PeopleListView(
        viewModel: container.makePeopleListViewModel(),
        makePortraitViewModel: container.makePortraitViewModel
    )
}
