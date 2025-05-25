import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:komarigoto_app/domain/entities/inventory_item.dart';
import 'package:komarigoto_app/domain/repositories/inventory_repository.dart';
import 'package:komarigoto_app/domain/usecases/update_inventory_item_use_case.dart';

// Mock InventoryRepository
class MockInventoryRepository extends Mock implements InventoryRepository {}

void main() {
  late UpdateInventoryItemUseCaseImpl useCase;
  late MockInventoryRepository mockInventoryRepository;

  setUp(() {
    mockInventoryRepository = MockInventoryRepository();
    useCase = UpdateInventoryItemUseCaseImpl(mockInventoryRepository);
  });

  final tUserId = 'testUser';
  final tInventoryItem = InventoryItem(
    id: 'itemId1', // Assuming InventoryItem has an id for updates
    ingredientId: 'testIngredient',
    status: 'in_stock',
    quantity: 2,
  );

  test('should call updateInventoryItem on the repository with correct parameters', () async {
    // Arrange
    when(mockInventoryRepository.updateInventoryItem(any, any))
        .thenAnswer((_) async => Future.value()); // Mock a successful void future

    // Act
    await useCase.call(tUserId, tInventoryItem);

    // Assert
    verify(mockInventoryRepository.updateInventoryItem(tUserId, tInventoryItem));
    verifyNoMoreInteractions(mockInventoryRepository);
  });
}
