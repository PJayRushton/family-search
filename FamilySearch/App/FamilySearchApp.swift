import SwiftUI

@main
struct FamilySearchApp: App {
    private let container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            PeopleListView(viewModel: container.makePeopleListViewModel())
        }
    }
}
