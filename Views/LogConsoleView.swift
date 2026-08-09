import SwiftUI

struct LogConsoleView: View {
    var logs: [LogEntry]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Journal d'exécution")
                .font(.headline)
                .padding(.bottom, 4)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logs) { log in
                            HStack(alignment: .top) {
                                Text("[\(log.formattedTime)]")
                                    .foregroundColor(.secondary)
                                
                                Text(log.message)
                                    .foregroundColor(color(for: log.type))
                                
                                Spacer()
                            }
                            .font(.system(.footnote, design: .monospaced))
                            .id(log.id)
                        }
                    }
                    .padding(8)
                }
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .onChange(of: logs) { _, newLogs in
                    if let last = newLogs.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private func color(for type: LogEntry.LogType) -> Color {
        switch type {
        case .info: return .white
        case .success: return .green
        case .warning: return .yellow
        case .error: return .red
        }
    }
}
