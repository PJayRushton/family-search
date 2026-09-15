import SwiftUI

struct RootView: View {
    private let peopleRepository: any PeopleRepository
    private let portraitRepository: any PortraitRepository
    @State private var path: [AppRoute] = []
    @State private var peopleListViewModel: PeopleListViewModel

    @MainActor
    init(
        peopleRepository: any PeopleRepository,
        portraitRepository: any PortraitRepository
    ) {
        self.peopleRepository = peopleRepository
        self.portraitRepository = portraitRepository
        _peopleListViewModel = State(
            initialValue: PeopleListViewModel(repository: peopleRepository)
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            PeopleListView(
                viewModel: peopleListViewModel,
                makePortraitViewModel: makePortraitViewModel,
                onSelectPerson: navigate
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .profile(let personID):
                    PersonProfileView(
                        viewModel: PersonProfileViewModel(
                            personID: personID,
                            repository: peopleRepository
                        ),
                        makePortraitViewModel: makePortraitViewModel,
                        onSelectRelative: navigate
                    )
                }
            }
        }
    }

    private func navigate(to personID: PersonID) {
        path = AppRoute.path(afterSelecting: personID, from: path)
    }

    private func makePortraitViewModel(portrait: PortraitReference?) -> PortraitViewModel {
        PortraitViewModel(portrait: portrait, repository: portraitRepository)
    }
}
