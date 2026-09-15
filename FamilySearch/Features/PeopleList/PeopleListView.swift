import SwiftUI

struct PeopleListView: View {
    @State private var viewModel: PeopleListViewModel
    @State private var retryID = 0
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
        content.navigationTitle("People")
            .task(id: retryID) { await viewModel.load() }
            .refreshable { await viewModel.refresh() }
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
        case .content(let rows, let isStale, let notice):
            List(rows) { row in
                Button {
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
        case .failure(let message):
            ContentUnavailableView {
                Label("Couldn't Load People", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { retryID += 1 }
            }
        }
    }
}

#Preview("Saved people") {
    let repository = PreviewData.makePeopleRepository()
    PeopleListView(
        viewModel: PeopleListViewModel(repository: repository),
        makePortraitViewModel: PreviewData.makePortraitViewModel
    )
}
