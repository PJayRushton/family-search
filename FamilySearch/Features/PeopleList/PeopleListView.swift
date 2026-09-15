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
        Group {
            switch viewModel.state {
            case .idle, .loading:
                loadingView
            case .empty:
                emptyView
            case .content(let rows, let isStale, let notice):
                peopleView(rows, isStale: isStale, notice: notice)
            case .failure(let message):
                failureView(message: message)
            }
        }
        .navigationTitle("People")
        .task(id: retryID) { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
        .onDisappear { viewModel.cancel() }
    }

    private var loadingView: some View {
        ProgressView("Loading people…")
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No People",
            systemImage: "person.2",
            description: Text("There are no records to show.")
        )
    }

    private func peopleView(
        _ rows: [PeopleListRowModel],
        isStale: Bool,
        notice: String?
    ) -> some View {
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
    }

    private func failureView(message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Load People", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { retryID += 1 }
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
