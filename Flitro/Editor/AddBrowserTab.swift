import SwiftUI

class AddBrowserTabDialogViewModel: ObservableObject {
    @Published var tabTitle: String = ""
    @Published var tabURL: String = ""
    @Published var selectedBrowser: String = "Default"
    let availableBrowsers = ["Safari", "Chrome", "Firefox", "Default"]
    
    func createBrowserTab() -> BrowserTab {
        let browser = selectedBrowser == "Default" ? "default" : selectedBrowser
        return BrowserTab(
            title: tabTitle.isEmpty ? tabURL : tabTitle,
            url: tabURL,
            browser: browser
        )
    }
    
    var isConfirmDisabled: Bool {
        tabURL.isEmpty
    }
}

struct AddBrowserTabDialogContent: View {
    @ObservedObject var viewModel: AddBrowserTabDialogViewModel
    var onAdd: (BrowserTab) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Tab Title", text: $viewModel.tabTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("URL", text: $viewModel.tabURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .placeholder(when: viewModel.tabURL.isEmpty) {
                    Text("https://example.com")
                        .foregroundColor(.secondary)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Browser")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Browser", selection: $viewModel.selectedBrowser) {
                    ForEach(viewModel.availableBrowsers, id: \.self) { browser in
                        Text(browser).tag(browser)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
}

struct AddBrowserTabDialog: View {
    @StateObject private var viewModel = AddBrowserTabDialogViewModel()
    var onAdd: (BrowserTab) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        GenericDialog(
            title: "Add Browser Tab",
            isConfirmDisabled: viewModel.isConfirmDisabled,
            onCancel: onCancel,
            onConfirm: { _ in
                let tab = viewModel.createBrowserTab()
                onAdd(tab)
            }
        ) {
            AddBrowserTabDialogContent(viewModel: viewModel, onAdd: onAdd)
        }
    }
}
