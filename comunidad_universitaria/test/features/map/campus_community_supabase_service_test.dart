import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/features/map/services/supabase_campus_community_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseCampusCommunityRepository Tests', () {
    late SupabaseCampusCommunityRepository repository;

    setUp(() {
      repository = SupabaseCampusCommunityRepository();
    });

    test('Registra correctamente los esquemas sanitarios, cafeterias y general', () {
      final sanitarios = repository.getClassification('sanitarios');
      expect(sanitarios.category, equals('sanitarios'));
      expect(sanitarios.tiers.length, equals(5));
      expect(sanitarios.tiers.first.code, equals('templo_dioses'));

      final cafeterias = repository.getClassification('cafeterias');
      expect(cafeterias.category, equals('cafeterias'));
      expect(cafeterias.tiers.length, equals(4));

      final general = repository.getClassification('general');
      expect(general.category, equals('general'));
      expect(general.tiers.length, equals(4));
    });

    test('submitReview actualiza inmediatamente el repositorio local (Optimistic UI)', () {
      final review = repository.submitReview(
        targetId: 'sanitario-test-1',
        targetType: 'poi',
        targetCategory: 'sanitarios',
        rating: 5,
        comment: 'Excelente limpieza y siempre hay agua.',
        tags: const {
          'has_water': true,
          'has_soap': true,
          'is_clean': true,
        },
        authorAlias: 'IngSistemasTester',
      );

      expect(review.targetId, equals('sanitario-test-1'));
      expect(review.rating, equals(5));
      expect(review.classificationTier, equals('templo_dioses'));
      expect(review.authorAlias, equals('IngSistemasTester'));

      final reviews = repository.getReviews('sanitario-test-1');
      expect(reviews, contains(review));

      final aggregate = repository.getAggregate('sanitario-test-1', category: 'sanitarios');
      expect(aggregate.totalReviews, greaterThanOrEqualTo(1));
      expect(aggregate.averageRating, equals(5.0));
      expect(aggregate.classificationCode, equals('templo_dioses'));
    });

    test('submitComment publica comentario y respuestas anidadas', () {
      final parentComment = repository.submitComment(
        targetId: 't-3',
        content: '¿A qué hora cierran la biblioteca hoy?',
        authorAlias: 'Estudiante1',
      );

      expect(parentComment.content, equals('¿A qué hora cierran la biblioteca hoy?'));

      final reply = repository.submitComment(
        targetId: 't-3',
        content: 'Cierran a las 19:00 hrs.',
        parentId: parentComment.id,
        authorAlias: 'Bibliotecario',
      );

      expect(reply.parentId, equals(parentComment.id));

      final comments = repository.getComments('t-3');
      final fetchedParent = comments.firstWhere((c) => c.id == parentComment.id);
      expect(fetchedParent.replies, contains(reply));
    });
  });
}
