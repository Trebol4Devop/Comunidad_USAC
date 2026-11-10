class SeccionReview {
  final String id;
  final String cursoCodigo;
  final String seccion;
  final bool recomienda;
  final String? catedraticoNombre;
  final int? dificultad;
  final int? cargaTareas;
  final String? comentario;
  final String semestre;
  final int upvotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isMine;
  final String? userId;

  const SeccionReview({
    required this.id,
    required this.cursoCodigo,
    required this.seccion,
    required this.recomienda,
    this.catedraticoNombre,
    this.dificultad,
    this.cargaTareas,
    this.comentario,
    this.semestre = '1S-2026',
    this.upvotes = 0,
    required this.createdAt,
    this.updatedAt,
    this.isMine = false,
    this.userId,
  });

  factory SeccionReview.fromMap(Map<String, dynamic> map) {
    int? parseOptionalInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    final rawUpvotes = map['upvotes'];
    final upvotes = (rawUpvotes is int)
        ? rawUpvotes
        : int.tryParse(rawUpvotes?.toString() ?? '0') ?? 0;

    final createdAt = map['created_at'] != null
        ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
        : DateTime.now();

    final updatedAt = map['updated_at'] != null
        ? DateTime.tryParse(map['updated_at'].toString())
        : null;

    final bool isMine = map['is_mine'] == true;

    // Directiva de privacidad: fromMap NO lee user_id de datos públicos.
    return SeccionReview(
      id: map['id']?.toString() ?? '',
      cursoCodigo: map['curso_codigo']?.toString() ?? '',
      seccion: map['seccion']?.toString() ?? '',
      recomienda: map['recomienda'] == true,
      catedraticoNombre: map['catedratico_nombre']?.toString(),
      dificultad: parseOptionalInt(map['dificultad']),
      cargaTareas: parseOptionalInt(map['carga_tareas']),
      comentario: map['comentario']?.toString(),
      semestre: map['semestre']?.toString() ?? '1S-2026',
      upvotes: upvotes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isMine: isMine,
      userId: null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'curso_codigo': cursoCodigo,
      'seccion': seccion,
      'recomienda': recomienda,
      if (catedraticoNombre != null) 'catedratico_nombre': catedraticoNombre,
      if (dificultad != null) 'dificultad': dificultad,
      if (cargaTareas != null) 'carga_tareas': cargaTareas,
      if (comentario != null) 'comentario': comentario,
      'semestre': semestre,
      'upvotes': upvotes,
      if (userId != null) 'user_id': userId,
    };
  }

  SeccionReview copyWith({
    String? id,
    String? cursoCodigo,
    String? seccion,
    bool? recomienda,
    String? catedraticoNombre,
    int? dificultad,
    int? cargaTareas,
    String? comentario,
    String? semestre,
    int? upvotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isMine,
    String? userId,
  }) {
    return SeccionReview(
      id: id ?? this.id,
      cursoCodigo: cursoCodigo ?? this.cursoCodigo,
      seccion: seccion ?? this.seccion,
      recomienda: recomienda ?? this.recomienda,
      catedraticoNombre: catedraticoNombre ?? this.catedraticoNombre,
      dificultad: dificultad ?? this.dificultad,
      cargaTareas: cargaTareas ?? this.cargaTareas,
      comentario: comentario ?? this.comentario,
      semestre: semestre ?? this.semestre,
      upvotes: upvotes ?? this.upvotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isMine: isMine ?? this.isMine,
      userId: userId ?? this.userId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeccionReview &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          cursoCodigo == other.cursoCodigo &&
          seccion == other.seccion &&
          recomienda == other.recomienda &&
          catedraticoNombre == other.catedraticoNombre &&
          dificultad == other.dificultad &&
          cargaTareas == other.cargaTareas &&
          comentario == other.comentario &&
          semestre == other.semestre &&
          upvotes == other.upvotes &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          isMine == other.isMine &&
          userId == other.userId;

  @override
  int get hashCode => Object.hash(
    id,
    cursoCodigo,
    seccion,
    recomienda,
    catedraticoNombre,
    dificultad,
    cargaTareas,
    comentario,
    semestre,
    upvotes,
    createdAt,
    updatedAt,
    isMine,
    userId,
  );

  @override
  String toString() {
    return 'SeccionReview(id: $id, cursoCodigo: $cursoCodigo, seccion: $seccion, recomienda: $recomienda, upvotes: $upvotes, isMine: $isMine)';
  }
}
