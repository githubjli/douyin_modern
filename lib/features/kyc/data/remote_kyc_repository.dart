import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/kyc_profile.dart';
import '../domain/kyc_repository.dart';

class RemoteKycRepository implements KycRepository {
  const RemoteKycRepository(this._api);

  final ApiClient _api;

  @override
  Future<KycProfile> getProfile() async {
    final response = await _api.get<Map<String, dynamic>>(
      Endpoints.kycMe,
      authenticated: true,
    );
    return KycProfile.fromMap(response.data ?? <String, dynamic>{});
  }

  @override
  Future<KycProfile> saveProfile({
    required String fullName,
    required String dateOfBirth,
    required String nationality,
    required String idType,
    required String idNumber,
    required String idExpiryDate,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'full_name': fullName,
      'date_of_birth': dateOfBirth,
      'nationality': nationality,
      'id_type': idType,
      'id_number': idNumber,
      'id_expiry_date': idExpiryDate,
    };
    // POST for first submission, PATCH for updates; backend accepts both
    final response = await _api.post<Map<String, dynamic>>(
      Endpoints.kycMe,
      data: body,
      authenticated: true,
    );
    return KycProfile.fromMap(response.data ?? <String, dynamic>{});
  }

  @override
  Future<KycDocument> uploadDocument({
    required String documentType,
    required File image,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'document_type': documentType,
      'image': await MultipartFile.fromFile(image.path),
    });
    final response = await _api.post<Map<String, dynamic>>(
      Endpoints.kycDocuments,
      data: formData,
      authenticated: true,
    );
    return KycDocument.fromMap(response.data ?? <String, dynamic>{});
  }

  @override
  Future<KycProfile> submit() async {
    final response = await _api.post<Map<String, dynamic>>(
      Endpoints.kycSubmit,
      authenticated: true,
    );
    // /submit/ returns {status: "pending"} — re-fetch full profile
    final statusData = response.data;
    if (statusData != null && statusData['status'] != null) {
      return getProfile();
    }
    return KycProfile.fromMap(statusData ?? <String, dynamic>{});
  }
}
