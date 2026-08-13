import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/shared/editable_avatar.dart';
import 'package:one_org_staff/features/auth/data/http_auth_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

void main() {
  group('HttpAuthRepository picture endpoints', () {
    test('uploads the avatar as multipart field `file`', () async {
      String? contentType;
      List<int>? body;
      final repository = HttpAuthRepository(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/users/11/picture');
          expect(request.headers['Authorization'], 'Bearer test-token');
          contentType = request.headers['content-type'];
          body = request.bodyBytes;

          return http.Response(
            jsonEncode({
              'ok': true,
              'picture_url': 'https://cdn.example.com/users/11/a.jpg',
            }),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz/',
      );

      final url = await repository.uploadProfilePicture(
        'test-token',
        userId: 11,
        bytes: const [1, 2, 3, 4],
        filename: 'avatar.jpg',
      );

      expect(contentType, startsWith('multipart/form-data'));
      // The field must be named `file` and carry the picked filename.
      final decoded = utf8.decode(body!, allowMalformed: true);
      expect(decoded, contains('name="file"'));
      expect(decoded, contains('filename="avatar.jpg"'));
      expect(url, 'https://cdn.example.com/users/11/a.jpg');
    });

    test('removes the avatar and returns a null url', () async {
      final repository = HttpAuthRepository(
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/users/11/picture');
          return http.Response(
            jsonEncode({'ok': true, 'picture_url': null}),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      expect(
        await repository.removeProfilePicture('test-token', userId: 11),
        isNull,
      );
    });

    test('surfaces the API message when upload is forbidden', () async {
      final repository = HttpAuthRepository(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Forbidden resource'}),
            403,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      expect(
        () => repository.uploadProfilePicture(
          'test-token',
          userId: 11,
          bytes: const [1],
          filename: 'a.jpg',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'message',
            'Forbidden resource',
          ),
        ),
      );
    });
  });

  group('AppUserProfile', () {
    test('parses username, status and roles from /users/me', () {
      final profile = AppUserProfile.fromJson(const {
        'id': 11,
        'username': 'bobur',
        'full_name': 'Bobur',
        'email': 'a.khamidullo01@gmail.com',
        'phone_number': '+998906961898',
        'status': 'active',
        'roles': ['admin', 'cashier', 'teacher'],
        'picture_url': null,
      });

      expect(profile.username, 'bobur');
      expect(profile.status, 'active');
      expect(profile.roles, ['admin', 'cashier', 'teacher']);
      expect(profile.phone, '+998906961898');
    });

    test('copyWithProfileImageUrl keeps every other field', () {
      const profile = AppUserProfile(
        id: 11,
        fullName: 'Bobur',
        subtitle: 'Staff member',
        email: 'b@example.com',
        phone: '+1',
        department: 'Maths',
        joinedDate: '01 Jan 2026',
        username: 'bobur',
        status: 'active',
        roles: ['teacher'],
      );

      final updated = profile.copyWithProfileImageUrl('https://x/y.jpg');

      expect(updated.profileImageUrl, 'https://x/y.jpg');
      expect(updated.username, 'bobur');
      expect(updated.roles, ['teacher']);
      expect(updated.status, 'active');
    });
  });

  group('EditableAvatar', () {
    Widget wrap({
      String? imageUrl,
      required Future<String?> Function({required int ownerId}) onRemove,
      ValueChanged<String?>? onChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: EditableAvatar(
            fullName: 'Bobur',
            imageUrl: imageUrl,
            ownerId: 11,
            isDarkMode: false,
            uploadPicture:
                ({
                  required ownerId,
                  required bytes,
                  required filename,
                }) async => null,
            removePicture: onRemove,
            onChanged: onChanged ?? (_) {},
            onError: (_) {},
          ),
        ),
      );
    }

    testWidgets('surfaces the real reason an upload failed', (tester) async {
      final errors = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableAvatar(
              fullName: 'Bobur',
              imageUrl: null,
              ownerId: 11,
              isDarkMode: false,
              uploadPicture:
                  ({required ownerId, required bytes, required filename}) async {
                    throw const AuthFailure('Forbidden resource');
                  },
              removePicture: ({required ownerId}) async {
                throw PlatformException(
                  code: 'network_error',
                  message: 'Host unreachable',
                );
              },
              onChanged: (_) {},
              onError: errors.add,
              imagePicker: _ThrowingImagePicker(),
            ),
          ),
        ),
      );

      // A picker failure must not be reported as a generic message.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();

      expect(errors.single, contains('choose a photo'));
      expect(errors.single, contains('Camera roll unavailable'));
    });

    testWidgets('reports an API rejection verbatim when removing', (
      tester,
    ) async {
      final errors = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditableAvatar(
              fullName: 'Bobur',
              imageUrl: 'https://cdn.example.com/users/11/a.jpg',
              ownerId: 11,
              isDarkMode: false,
              uploadPicture:
                  ({
                    required ownerId,
                    required bytes,
                    required filename,
                  }) async => null,
              removePicture: ({required ownerId}) async {
                throw const AuthFailure('Forbidden resource');
              },
              onChanged: (_) {},
              onError: errors.add,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();

      expect(errors.single, 'Forbidden resource');
    });

    testWidgets('falls back to the name initial with no picture', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(onRemove: ({required ownerId}) async => null),
      );

      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('offers Remove photo only when a picture exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(onRemove: ({required ownerId}) async => null),
      );

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('Choose from library'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Remove photo'), findsNothing);
    });

    testWidgets('removing clears the avatar through onChanged', (tester) async {
      var removedFor = 0;
      String? changedTo = 'unset';

      // The URL cannot resolve under the test binding; ProfileAvatar handles
      // that and falls back to the initial, which is what we want here anyway.
      await tester.pumpWidget(
        wrap(
          imageUrl: 'https://cdn.example.com/users/11/a.jpg',
          onRemove: ({required ownerId}) async {
            removedFor = ownerId;
            return null;
          },
          onChanged: (url) => changedTo = url,
        ),
      );

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();

      expect(removedFor, 11);
      expect(changedTo, isNull);
    });
  });
}

/// Stands in for the platform picker so error handling can be tested without a
/// real photo library.
class _ThrowingImagePicker implements ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    throw PlatformException(
      code: 'unavailable',
      message: 'Camera roll unavailable',
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
