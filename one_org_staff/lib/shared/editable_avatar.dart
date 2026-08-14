import 'package:flutter/material.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

import 'package:one_org_staff/features/Profile/avatar_cropper.dart';

/// A circular avatar that can pick, crop, upload and remove a picture.
///
/// Owner-agnostic: the caller supplies the id and the upload/remove calls, so
/// the same widget backs `/users/:id/picture` and `/persons/:personId/picture`.
class EditableAvatar extends StatefulWidget {
  const EditableAvatar({
    super.key,
    required this.fullName,
    required this.imageUrl,
    required this.ownerId,
    required this.isDarkMode,
    required this.uploadPicture,
    required this.removePicture,
    required this.onChanged,
    required this.onError,
    this.radius = 32,
    this.imagePicker,
    this.skipCropper = false,
  });

  final String fullName;
  final String? imageUrl;

  /// Whose picture this is — a user id or a person id, per the callbacks.
  final int ownerId;
  final bool isDarkMode;
  final double radius;
  final Future<String?> Function({
    required int ownerId,
    required List<int> bytes,
    required String filename,
  })
  uploadPicture;
  final Future<String?> Function({required int ownerId}) removePicture;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onError;

  /// Injectable so widget tests can drive the picker without a platform channel.
  final ImagePicker? imagePicker;

  /// Uploads the picked bytes as-is. Lets tests exercise the upload path
  /// without stepping through the cropper dialog.
  final bool skipCropper;

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  // Bounds the picked image before it reaches the cropper, to keep decoding
  // off a multi-megapixel original. Comfortably above the 512px export even at
  // maximum zoom, where the cropper frames roughly a third of the source.
  static const _maxDimension = 2048.0;
  static const _imageQuality = 90;

  bool _isBusy = false;

  /// Set when the avatar URL cannot be loaded (offline, 404, expired link) so
  /// the circle falls back to the initial instead of rendering empty.
  bool _imageFailed = false;

  @override
  void didUpdateWidget(covariant EditableAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageFailed = false;
    }
  }

  Future<void> _showOptions() async {
    if (_isBusy) {
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (widget.imageUrl != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFDC2626),
                ),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) {
      return;
    }

    switch (action) {
      case 'gallery':
        await _pickAndUpload(ImageSource.gallery);
      case 'camera':
        await _pickAndUpload(ImageSource.camera);
      case 'remove':
        await _remove();
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = widget.imagePicker ?? ImagePicker();

    final XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        maxWidth: _maxDimension,
        maxHeight: _maxDimension,
        imageQuality: _imageQuality,
      );
    } catch (error) {
      if (mounted) {
        widget.onError(_describeError(error, stage: 'choose a photo'));
      }
      return;
    }

    if (picked == null) {
      return;
    }

    final Uint8List pickedBytes;
    try {
      pickedBytes = await picked.readAsBytes();
    } catch (error) {
      if (mounted) {
        widget.onError(_describeError(error, stage: 'read the photo'));
      }
      return;
    }

    if (!mounted) {
      return;
    }

    // Square-crop before upload so the circular avatar never centre-crops a
    // portrait photo for the user.
    final cropped = widget.skipCropper
        ? pickedBytes
        : await showDialog<Uint8List>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AvatarCropper(bytes: pickedBytes),
          );

    if (cropped == null || !mounted) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      final url = await widget.uploadPicture(
        ownerId: widget.ownerId,
        bytes: cropped,
        filename: 'avatar.jpg',
      );
      if (!mounted) {
        return;
      }
      widget.onChanged(_cacheBust(url));
    } catch (error) {
      if (mounted) {
        widget.onError(_describeError(error, stage: 'upload the picture'));
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _isBusy = true);
    try {
      await widget.removePicture(ownerId: widget.ownerId);
      if (!mounted) {
        return;
      }
      widget.onChanged(null);
    } catch (error) {
      if (mounted) {
        widget.onError(_describeError(error, stage: 'remove the picture'));
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  /// The server may hand back the same URL for a replaced image, which
  /// [NetworkImage] would serve from cache. A timestamp forces a refetch.
  static String? _cacheBust(String? url) {
    if (url == null || url.isEmpty) {
      return url;
    }
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Keeps the underlying failure visible. A generic catch-all here hides
  /// whether the picker, the network, or the API rejected the change.
  static String _describeError(Object error, {required String stage}) {
    if (error is AuthFailure) {
      return error.message;
    }

    if (error is MissingPluginException) {
      return 'The photo picker is not in this build. Stop the app and launch '
          'it again \u2014 adding the plugin needs a full rebuild, not a hot '
          'reload.';
    }

    if (error is PlatformException) {
      final detail = error.message?.trim();
      if (error.code == 'camera_access_denied' ||
          error.code == 'photo_access_denied') {
        return 'Access was denied. Allow photo or camera access for this app '
            'in Settings, then try again.';
      }
      return detail == null || detail.isEmpty
          ? 'Could not $stage (${error.code}).'
          : 'Could not $stage: $detail';
    }

    return 'Could not $stage: $error';
  }

  @override
  Widget build(BuildContext context) {
    final rawUrl = widget.imageUrl;
    final imageUrl = _imageFailed || rawUrl == null || rawUrl.isEmpty
        ? null
        : rawUrl;
    final initial = widget.fullName.isNotEmpty
        ? widget.fullName[0].toUpperCase()
        : 'U';
    final badgeBorderColor = appColorsOf(context).card;

    return Semantics(
      button: true,
      label: imageUrl == null
          ? 'Add profile picture'
          : 'Change profile picture',
      child: InkWell(
        onTap: _isBusy ? null : _showOptions,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: widget.radius,
              backgroundColor: appColorsOf(context).softBg,
              backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl),
              onBackgroundImageError: imageUrl == null
                  ? null
                  : (_, _) {
                      // Fired during image resolution, so defer the rebuild.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _imageFailed = true);
                        }
                      });
                    },
              child: imageUrl != null
                  ? null
                  : Text(
                      initial,
                      style: TextStyle(
                        fontSize: widget.radius * 0.8,
                        fontWeight: FontWeight.bold,
                        color: appColorsOf(context).softText,
                      ),
                    ),
            ),
            if (_isBusy)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeBorderColor, width: 2.5),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
