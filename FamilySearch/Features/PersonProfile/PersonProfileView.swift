import SwiftUI

struct PersonProfileView: View {
    @State private var viewModel: PersonProfileViewModel
    @State private var retryID = 0
    private let makePortraitViewModel: (PortraitReference?) -> PortraitViewModel
    private let onSelectRelative: (PersonID) -> Void

    init(
        viewModel: PersonProfileViewModel,
        makePortraitViewModel: @escaping (PortraitReference?) -> PortraitViewModel,
        onSelectRelative: @escaping (PersonID) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makePortraitViewModel = makePortraitViewModel
        self.onSelectRelative = onSelectRelative
    }

    var body: some View {
        content
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: retryID) { await viewModel.load() }
            .onDisappear { viewModel.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading profile…")
        case let .content(profile, isStale, notice):
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(profile)
                    lifeDetails(profile)
                    if let occupation = profile.occupation, !occupation.isEmpty {
                        labeledText("Occupation", occupation)
                    }
                    labeledText("Biography", profile.biography)
                    relatives(profile.relatives)
                }
                .padding()
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
                Label("Couldn't Load Profile", systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { retryID += 1 }
            }
        }
    }

    private func header(_ profile: PersonProfilePresentationModel) -> some View {
        VStack(spacing: 12) {
            PortraitView(viewModel: makePortraitViewModel(profile.portrait))
            .frame(width: 150, height: 150)
            .clipShape(Circle())
            .accessibilityLabel("Portrait of \(profile.name)")

            Text(profile.name).font(.largeTitle.bold()).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func lifeDetails(_ profile: PersonProfilePresentationModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Life events").font(.headline)
            lifeEvent("Born", profile.birth)
            if let death = profile.death { lifeEvent("Died", death) }
        }
    }

    private func lifeEvent(_ label: String, _ event: LifeEventPresentationModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.subheadline.weight(.semibold))
            Text(event.date)
            Text(event.place).foregroundStyle(.secondary)
        }
    }

    private func labeledText(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.headline)
            Text(value)
        }
    }

    @ViewBuilder
    private func relatives(_ rows: [RelativeRowPresentationModel]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Relatives").font(.headline)
                ForEach(rows) { row in
                    Button { onSelectRelative(row.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.relationship).font(.caption).foregroundStyle(.secondary)
                                Text(row.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                Text(row.lifespan).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }
}

#Preview("Cached profile") {
    let container = PreviewContainer.populated()
    NavigationStack {
        PersonProfileView(
            viewModel: container.makePersonProfileViewModel(id: PreviewContainer.profileID),
            makePortraitViewModel: container.makePortraitViewModel,
            onSelectRelative: { _ in }
        )
    }
}

#Preview("Living, no occupation") {
    let container = PreviewContainer.populated()
    NavigationStack {
        PersonProfileView(
            viewModel: container.makePersonProfileViewModel(id: PreviewContainer.livingProfileID),
            makePortraitViewModel: container.makePortraitViewModel,
            onSelectRelative: { _ in }
        )
    }
}
