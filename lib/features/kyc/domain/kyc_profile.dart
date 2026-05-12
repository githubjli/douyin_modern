class KycDocument {
  const KycDocument({
    required this.documentType,
    required this.imageUrl,
    required this.uploadedAt,
  });

  final String documentType;
  final String imageUrl;
  final String uploadedAt;

  factory KycDocument.fromMap(Map<String, dynamic> m) => KycDocument(
        documentType: m['document_type'] as String,
        imageUrl: m['image_url'] as String,
        uploadedAt: m['uploaded_at'] as String,
      );
}

class KycProfile {
  const KycProfile({
    required this.status,
    required this.fullName,
    required this.dateOfBirth,
    required this.nationality,
    required this.idType,
    required this.idNumber,
    required this.idExpiryDate,
    required this.submittedAt,
    required this.reviewedAt,
    required this.rejectReason,
    required this.idFront,
    required this.selfie,
  });

  final String status; // not_submitted | pending | approved | rejected
  final String fullName;
  final String? dateOfBirth;
  final String nationality;
  final String idType;
  final String idNumber;
  final String? idExpiryDate;
  final String? submittedAt;
  final String? reviewedAt;
  final String rejectReason;
  final KycDocument? idFront;
  final KycDocument? selfie;

  bool get isNotSubmitted => status == 'not_submitted';
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get canEdit => isNotSubmitted || isRejected;

  factory KycProfile.fromMap(Map<String, dynamic> m) {
    final docs = m['documents'] as Map<String, dynamic>? ?? {};
    return KycProfile(
      status: m['status'] as String? ?? 'not_submitted',
      fullName: m['full_name'] as String? ?? '',
      dateOfBirth: m['date_of_birth'] as String?,
      nationality: m['nationality'] as String? ?? '',
      idType: m['id_type'] as String? ?? '',
      idNumber: m['id_number'] as String? ?? '',
      idExpiryDate: m['id_expiry_date'] as String?,
      submittedAt: m['submitted_at'] as String?,
      reviewedAt: m['reviewed_at'] as String?,
      rejectReason: m['reject_reason'] as String? ?? '',
      idFront: docs['id_front'] != null
          ? KycDocument.fromMap(docs['id_front'] as Map<String, dynamic>)
          : null,
      selfie: docs['selfie'] != null
          ? KycDocument.fromMap(docs['selfie'] as Map<String, dynamic>)
          : null,
    );
  }
}
