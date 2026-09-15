import SwiftUI

struct RootView: View {
    private let container: AppContainer
    @State private var path: [AppRoute] = []
    @State private var peopleListViewModel: PeopleListViewModel

    @MainActor
    init(container: AppContainer) {
        self.container = container
        _peopleListViewModel = State(initialValue: container.makePeopleListViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            PeopleListView(viewModel: peopleListViewModel) { personID in
                path.append(.profile(personID))
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case let .profile(personID):
                    PersonProfileView(
                        viewModel: container.makePersonProfileViewModel(id: personID),
                        onSelectRelative: { path.append(.profile($0)) }
                    )
                }
            }
        }
    }
}
