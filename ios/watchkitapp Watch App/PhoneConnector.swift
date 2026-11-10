import WatchConnectivity
import Combine

/// Singleton that manages WatchConnectivity with the paired iPhone.
/// - Receives cards + people list from the iPhone app (via applicationContext).
/// - Sends new expense transactions to the iPhone app (via sendMessage).
class PhoneConnector: NSObject, ObservableObject {

    static let shared = PhoneConnector()

    @Published var cards: [WatchCard] = []
    @Published var people: [String] = []
    @Published var sendState: SendState = .idle

    enum SendState: Equatable {
        case idle
        case sending
        case success
        case failure(String)
    }

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send transaction to iPhone

    func sendTransaction(cardId: String, spentFor: String, spentBy: String, amount: Double) {
        guard WCSession.default.isReachable else {
            sendState = .failure("iPhone not reachable. Open MM app on your phone.")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        sendState = .sending

        WCSession.default.sendMessage(
            [
                "action":   "addTxn",
                "cardId":   cardId,
                "spentFor": spentFor,
                "spentBy":  spentBy,
                "amount":   amount,
                "date":     today,
            ],
            replyHandler: { [weak self] _ in
                DispatchQueue.main.async { self?.sendState = .success }
            },
            errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.sendState = .failure(error.localizedDescription)
                }
            }
        )
    }

    // MARK: - Parse incoming data

    private func apply(_ context: [String: Any]) {
        if let raw = context["cards"] as? [[String: Any]] {
            let parsed = raw.compactMap { d -> WatchCard? in
                guard let id    = d["id"]    as? String,
                      let name  = d["name"]  as? String,
                      let color = d["color"] as? String else { return nil }
                return WatchCard(id: id, name: name, color: color)
            }
            DispatchQueue.main.async { self.cards = parsed }
        }
        if let raw = context["people"] as? [String] {
            DispatchQueue.main.async { self.people = raw }
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnector: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        // Pull latest context immediately after activation
        let ctx = session.receivedApplicationContext
        if !ctx.isEmpty { apply(ctx) }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        apply(message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        apply(message)
        replyHandler([:])
    }
}
