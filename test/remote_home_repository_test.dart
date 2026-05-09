import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_media/core/network/api_client.dart';
import 'package:meow_media/core/network/endpoints.dart';
import 'package:meow_media/features/home/data/remote_home_repository.dart';

void main() {
  test('maps membership access fields from public video responses', () async {
    final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
      'results': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 42,
          'title': 'VIP Feature',
          'owner_name': 'VIP Studio',
          'view_count': 120,
          'thumbnail_url': 'https://example.com/thumb.jpg',
          'file_url': 'https://example.com/video.mp4',
          'access_type': 'membership',
          'preview_seconds': 30,
          'can_watch': false,
          'is_locked': true,
          'lock_reason': 'membership_required',
        },
      ],
    });
    final RemoteHomeRepository repository = RemoteHomeRepository(
      apiClient: apiClient,
    );

    final page = await repository.getVideoPage(
      accessType: 'membership',
      pageSize: 4,
    );
    final video = page.items.single;

    expect(apiClient.requestedPath, Endpoints.publicVideos);
    expect(apiClient.requestedQuery?['access_type'], 'membership');
    expect(apiClient.requestedQuery?['page_size'], 4);
    expect(apiClient.requestedAuthenticated, isFalse);
    expect(video.id, '42');
    expect(video.accessType, 'membership');
    expect(video.isMembershipVideo, isTrue);
    expect(video.previewSeconds, 30);
    expect(video.canWatch, isFalse);
    expect(video.isLocked, isTrue);
    expect(video.lockReason, 'membership_required');
    expect(video.videoUrl, 'https://example.com/video.mp4');
  });

  test('passes authenticated flag to home portal video request only', () async {
    final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
      'results': <Map<String, dynamic>>[],
    });
    final RemoteHomeRepository repository = RemoteHomeRepository(
      apiClient: apiClient,
    );

    await repository.getHomePortalData(authenticated: true);

    expect(apiClient.calls, hasLength(3));
    expect(apiClient.calls[0].path, Endpoints.publicVideos);
    expect(apiClient.calls[0].authenticated, isTrue);
    expect(apiClient.calls[1].path, Endpoints.dramas);
    expect(apiClient.calls[1].authenticated, isFalse);
    expect(apiClient.calls[2].path, '/api/live/');
    expect(apiClient.calls[2].authenticated, isFalse);
  });

  test('passes authenticated flag to public video requests', () async {
    final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
      'results': <Map<String, dynamic>>[],
    });
    final RemoteHomeRepository repository = RemoteHomeRepository(
      apiClient: apiClient,
    );

    await repository.getVideoPage(
      accessType: 'membership',
      pageSize: 4,
      authenticated: true,
    );

    expect(apiClient.requestedPath, Endpoints.publicVideos);
    expect(apiClient.requestedQuery?['access_type'], 'membership');
    expect(apiClient.requestedAuthenticated, isTrue);
  });

  test('passes authenticated flag to pageUrl video requests', () async {
    final _FakeApiClient apiClient = _FakeApiClient(<String, dynamic>{
      'results': <Map<String, dynamic>>[],
    });
    final RemoteHomeRepository repository = RemoteHomeRepository(
      apiClient: apiClient,
    );

    await repository.getVideoPage(
      pageUrl: 'https://example.com/api/public/videos/?page=2',
      authenticated: true,
    );

    expect(
      apiClient.requestedPath,
      'https://example.com/api/public/videos/?page=2',
    );
    expect(apiClient.requestedQuery, isNull);
    expect(apiClient.requestedAuthenticated, isTrue);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.data);

  final dynamic data;
  final List<_ApiGetCall> calls = <_ApiGetCall>[];
  String? requestedPath;
  Map<String, dynamic>? requestedQuery;
  bool? requestedAuthenticated;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    requestedPath = path;
    requestedQuery = queryParameters;
    requestedAuthenticated = authenticated;
    calls.add(
      _ApiGetCall(
        path: path,
        queryParameters: queryParameters,
        authenticated: authenticated,
      ),
    );
    return Response<T>(
      data: data as T,
      requestOptions: RequestOptions(path: path),
    );
  }
}

class _ApiGetCall {
  const _ApiGetCall({
    required this.path,
    required this.queryParameters,
    required this.authenticated,
  });

  final String path;
  final Map<String, dynamic>? queryParameters;
  final bool authenticated;
}
