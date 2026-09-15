import SwiftUI

struct PortraitView: View {
    @State private var viewModel: PortraitViewModel

    init(viewModel: PortraitViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .image(let data):
                if let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    placeholder
                }
            case .loading:
                ProgressView()
            case .placeholder, .failure:
                placeholder
            }
        }
        .background(Color.secondary.opacity(0.12))
        .task { await viewModel.load() }
        .onDisappear { viewModel.cancel() }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.secondary)
            .padding(8)
    }
}
