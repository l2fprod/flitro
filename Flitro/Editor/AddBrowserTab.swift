import SwiftUI

class AddBrowserTabDialogViewModel: ObservableObject {
    @Published var tabTitle: String = ""
    @Published var tabURL: String = ""
    @Published var selectedBrowser: String = "Default"
    let availableBrowsers = ["Safari", "Chrome", /*"Firefox",*/ "Default"]
    
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
        VStack(alignment: .leading, spacing: 28) {
            // URL input section
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.accentColor)
                        Text("Website URL")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Enter the URL of the website you want to open")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                TextField("https://example.com", text: $viewModel.tabURL)
                    .textFieldStyle(.roundedBorder)
                    .placeholder(when: viewModel.tabURL.isEmpty) {
                        Text("https://example.com")
                            .foregroundColor(.secondary)
                    }
            }
            
            // Tab title input section
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "textformat")
                            .foregroundColor(.accentColor)
                        Text("Tab Title (Optional)")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Custom title for the browser tab. If left empty, the website title will be used.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                TextField("e.g., My Project Dashboard", text: $viewModel.tabTitle)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Browser selection section
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.accentColor)
                        Text("Browser")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Choose which browser to use for this tab")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Picker(selection: $viewModel.selectedBrowser) {
                    ForEach(viewModel.availableBrowsers, id: \.self) { browser in
                        Text(browser).tag(browser)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 0.1), value: true)
            }
            
            Spacer()
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
            icon: "globe",
            subtitle: "Add a browser tab to your context",
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
