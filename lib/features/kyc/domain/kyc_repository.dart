import 'dart:io';

import 'kyc_profile.dart';

abstract class KycRepository {
  Future<KycProfile> getProfile();

  Future<KycProfile> saveProfile({
    required String fullName,
    required String dateOfBirth,
    required String nationality,
    required String idType,
    required String idNumber,
    required String idExpiryDate,
  });

  Future<KycDocument> uploadDocument({
    required String documentType,
    required File image,
  });

  Future<KycProfile> submit();
}
