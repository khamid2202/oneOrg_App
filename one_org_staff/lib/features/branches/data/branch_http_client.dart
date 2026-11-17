import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

final Object _acrossBranchesKey = Object();

/// Runs [action] with its requests sent without `X-Branch-Id`, so they reach
/// every branch the teacher works at.
///
/// For a teacher's own lessons: `/timetable/my-lessons` covers all their
/// branches whichever one is selected, so opening a lesson at the other campus
/// must not be limited to the selected one.
Future<T> acrossBranches<T>(Future<T> Function() action) {
  return runZoned(action, zoneValues: {_acrossBranchesKey: true});
}

/// Says which branch every staff request is for. All the repositories share
/// this client, so none of them has to know about branches.
class BranchHttpClient extends http.BaseClient {
  BranchHttpClient(
    this._inner, {
    required int? Function() branchId,
    void Function()? onBranchRejected,
  }) : _branchId = branchId,
       _onBranchRejected = onBranchRejected;

  static const headerName = 'X-Branch-Id';

  /// Calls about the person rather than a branch. They must keep working while
  /// the selection is being resolved or has just been lost.
  static final _branchFreePaths = RegExp(
    r'^/(users/me(/|$)|branches/my$|auth/|notifications(/|$))',
  );

  final http.Client _inner;
  final int? Function() _branchId;
  final void Function()? _onBranchRejected;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final branchId = _branchId();
    final stamped =
        branchId != null &&
        Zone.current[_acrossBranchesKey] != true &&
        !_branchFreePaths.hasMatch(request.url.path);
    if (stamped) {
      request.headers[headerName] = '$branchId';
    }

    final response = await _inner.send(request);
    if (!stamped || response.statusCode != 403) {
      return response;
    }

    // Reading the body consumes it, so the caller gets a fresh copy.
    final bytes = await response.stream.toBytes();
    final lostBranch = utf8
        .decode(bytes, allowMalformed: true)
        .contains('access to this branch');
    if (lostBranch && _branchId() == branchId) {
      _onBranchRejected?.call();
    }
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
