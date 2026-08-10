import re

with open('Views/DashboardView.swift', 'r') as f:
    content = f.read()

# Add AppStorage
content = content.replace('@State private var showLogs: Bool = false', '@State private var showLogs: Bool = false\n    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false')

# Add sheet at the end
sheet_code = """        .alert("Erreur de sauvegarde", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: Binding(
            get: { !hasAcceptedDisclaimer },
            set: { _ in }
        )) {
            DisclaimerModalView()
                .interactiveDismissDisabled()
        }"""

content = content.replace("""        .alert("Erreur de sauvegarde", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }""", sheet_code)

with open('Views/DashboardView.swift', 'w') as f:
    f.write(content)
