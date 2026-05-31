class MacAddressFormatter {
  static String format(int mac) {
    // Convert to hex string
    String hex = mac.toRadixString(16).toUpperCase();
    
    // If it's not exactly a standard 48-bit MAC address (12 hex digits),
    // just return the raw string representation as requested.
    if (hex.length != 12) {
      return mac.toString();
    }
    
    // Split into pairs and join with colons
    List<String> pairs = [];
    for (int i = 0; i < hex.length; i += 2) {
      pairs.add(hex.substring(i, i + 2));
    }
    
    return pairs.join(':');
  }
}
