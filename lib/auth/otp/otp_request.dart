class OtpRequest {
  final String contact; // Changed from email to contact

  OtpRequest({required this.contact});

  Map<String, dynamic> toJson() => {
    'contact': contact, // API expects 'contact' field
  };

  @override
  String toString() => 'OtpRequest(contact: $contact)';
}
