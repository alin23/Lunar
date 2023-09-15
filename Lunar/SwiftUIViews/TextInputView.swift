import SwiftUI

struct TextInputView: View {
    @State var label: String
    @State var placeholder: String
    @Binding var data: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            TextField(placeholder, text: $data)
                .textFieldStyle(PaddedTextFieldStyle())
        }
    }
}
