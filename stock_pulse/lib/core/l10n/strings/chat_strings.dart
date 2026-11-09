class ChatStrings {
  const ChatStrings();
  String get title => 'AI';
  String get subtitle => 'Simulated';
  String get disclaimer => 'Simulated. Not advice.';
  String get emptyTitle => 'Ask about the market';
  String get emptyMessage =>
      'Prices, option chains, strategies or market terms. '
      'Answers use live simulated prices.';
  String get tryAsking => 'Try asking';
  List<String> get suggestions => const [
    'What does the NIFTY chain say?',
    'Quote RELIANCE',
    'Compare RELIANCE and HDFCBANK',
    'Payoff of a NIFTY straddle',
    'Top movers today',
    'Explain theta',
  ];
  String get hint => 'Ask a question';
  String get send => 'Send';
  String get stop => 'Stop answer';
  String counter(int length, int max) => '$length/$max';
  String get attach => 'Attach image or file';
  String attachLimitReached(int max) => 'Up to $max attachments';
  String attachmentLimit(int megabytes) =>
      'Choose a file between 1 byte and $megabytes MB.';
  String get attachmentError => 'Could not open the file picker. Try again.';
  String get attachmentNote =>
      'Attachments stay on this device. This simulator answers your text only.';
  String get removeAttachment => 'Remove attachment';
  String get previewUnavailable => 'Image preview unavailable';
  String size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  String attachmentLabel(String name, int bytes) => '$name, ${size(bytes)}';
  String get sending => 'Sending…';
  String get thinking => 'Thinking…';
  String get writing => 'Writing the answer';
  String get failed => 'Answer interrupted.';
  String get stopped => 'Answer stopped';
  String get retry => 'Retry';
  String get newChat => 'New chat';
  String get newChatTitle => 'Start a new chat?';
  String get newChatBody =>
      'This deletes the saved conversation from this device.';
  String get cancel => 'Cancel';
  String get delete => 'Delete';
  String get loadingOlder => 'Loading older messages';
  String get newAnswer => 'New answer';
  String get historyFailed => 'Chat history could not be saved on this device.';
  String get loadingFailed => 'Could not load chat. Tap to retry.';
  String asOf(String time) => 'as of $time';
  String get livePriceUnavailable => 'Could not refresh the live price.';
  String cardType(String type) => switch (type) {
    'quote' => 'Quote',
    'chart' => 'Chart',
    'chain' => 'Option chain',
    'payoff' => 'Payoff',
    'table' => 'Screener',
    'fallback' => 'Suggestions',
    _ => 'Explanation',
  };
}
