import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:komarigoto_app/domain/entities/inventory_item.dart';
import 'package:komarigoto_app/domain/repositories/inventory_repository.dart';
import 'package:komarigoto_app/domain/usecases/add_ingredient_to_inventory_use_case.dart';

// Mock InventoryRepository
class MockInventoryRepository extends Mock implements InventoryRepository {}

void main() {
  late AddIngredientToInventoryUseCaseImpl useCase;
  late MockInventoryRepository mockInventoryRepository;

  setUp(() {
    mockInventoryRepository = MockInventoryRepository();
    useCase = AddIngredientToInventoryUseCaseImpl(mockInventoryRepository);
  });

  final tUserId = 'testUser';
  final tInventoryItem = InventoryItem(
    ingredientId: 'testIngredient',
    status: 'in_stock',
    quantity: 1,
  );

  test('should call upsertInventoryItem on the repository with correct parameters', () async {
    // Arrange    when(mockInventoryRepository.upsertInventoryItem(any, any))
      when(mockInventoryRepository.upsertInventoryItem(tUserId, tInventoryItem))
        .thenAnswer((_) async => await Future.value()); // Mock a successful void future

    // Act
    await useCase.call(tUserId, tInventoryItem);

    // Assert
    verify(mockInventoryRepository.upsertInventoryItem(tUserId, tInventoryItem));
    verifyNoMoreInteractions(mockInventoryRepository);
  });
}
