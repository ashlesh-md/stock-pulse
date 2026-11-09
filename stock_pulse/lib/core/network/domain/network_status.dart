/// App-level connectivity, shown by the stale banner and used by the order
/// ticket to explain a timeout.
enum NetworkStatus { live, delayed, reconnecting, offline }
