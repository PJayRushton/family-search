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
            PeopleListView(
                viewModel: peopleListViewModel,
                makePortraitViewModel: container.makePortraitViewModel,
                onSelectPerson: navigate
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .profile(let personID):
                    PersonProfileView(
                        viewModel: container.makePersonProfileViewModel(id: personID),
                        makePortraitViewModel: container.makePortraitViewModel,
                        onSelectRelative: navigate
                    )
                }
            }
        }
    }

    private func navigate(to personID: PersonID) {
        path = AppRoute.path(afterSelecting: personID, from: path)
    }
}
