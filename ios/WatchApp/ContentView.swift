import SwiftUI

/// Root view — shows the list of credit cards synced from the iPhone.
struct ContentView: View {

    @StateObject private var connector = PhoneConnector.shared

    var body: some View {
        NavigationView {
            Group {
                if connector.cards.isEmpty {
                    emptyState
                } else {
                    cardList
                }
            }
            .navigationTitle("Add Expense")
        }
    }

    // MARK: - Card list

    private var cardList: some View {
        List(connector.cards) { card in
            NavigationLink(destination: AddExpenseView(card: card)) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: card.color))
                        .frame(width: 10, height: 10)
                    Text(card.name)
                        .font(.body)
                        .lineLimit(1)
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.carousel)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 28))
                .foregroundColor(.gray)
            Text("Open MM on iPhone")
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
