import 'package:flutter/material.dart';
import '../../../core/constants/avatar_presets.dart';
import '../../../core/services/local_storage_service.dart';

/// Avatar circular de usuario que respeta los índices elegidos en perfil
/// o deriva de forma determinista el avatar del autor según su hash/alias.
class UserAvatarCircle extends StatefulWidget {
  final String authorAlias;
  final String? authorHash;
  final int? avatarColorIndex;
  final int? avatarIconIndex;
  final bool isMine;
  final double size;
  final double iconSize;

  const UserAvatarCircle({
    super.key,
    required this.authorAlias,
    this.authorHash,
    this.avatarColorIndex,
    this.avatarIconIndex,
    this.isMine = false,
    this.size = 34,
    this.iconSize = 17,
  });

  @override
  State<UserAvatarCircle> createState() => _UserAvatarCircleState();
}

class _UserAvatarCircleState extends State<UserAvatarCircle> {
  int? _myColorIndex;
  int? _myIconIndex;

  @override
  void initState() {
    super.initState();
    _loadMyAvatarIfNeeded();
  }

  @override
  void didUpdateWidget(covariant UserAvatarCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMine &&
        (widget.avatarColorIndex == null || widget.avatarIconIndex == null) &&
        (!oldWidget.isMine || _myColorIndex == null)) {
      _loadMyAvatarIfNeeded();
    }
  }

  Future<void> _loadMyAvatarIfNeeded() async {
    if (!widget.isMine ||
        (widget.avatarColorIndex != null && widget.avatarIconIndex != null)) {
      return;
    }
    try {
      final profile = await LocalStorageService.getUserProfile();
      if (!mounted) return;
      setState(() {
        _myColorIndex = profile.avatarColorIndex;
        _myIconIndex = profile.avatarIconIndex;
      });
    } catch (_) {
      // Fallback determinista si no hay almacenamiento local disponible en tests.
    }
  }

  @override
  Widget build(BuildContext context) {
    final seed = (widget.authorHash != null && widget.authorHash!.trim().isNotEmpty)
        ? widget.authorHash!.trim()
        : widget.authorAlias;

    final int colorIdx = widget.avatarColorIndex ??
        (widget.isMine ? _myColorIndex : null) ??
        AvatarPresets.deterministicColorIndex(seed);
    final int iconIdx = widget.avatarIconIndex ??
        (widget.isMine ? _myIconIndex : null) ??
        AvatarPresets.deterministicIconIndex(seed);

    final bgColor = AvatarPresets.colorAt(colorIdx);
    final iconData = AvatarPresets.iconAt(iconIdx);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          size: widget.iconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
