import SwiftUI

struct RootView: View {
    var body: some View {
        GenerateView()
            .dynamicTypeSize(.small ... .large)
    }
}
