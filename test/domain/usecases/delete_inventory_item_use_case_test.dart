import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:komarigoto_app/domain/repositories/inventory_repository.dart';
import 'package:komarigoto_app/domain/usecases/delete_inventory_item_use_case.dart';

// Mock InventoryRepository
class MockInventoryRepository extends Mock implements InventoryRepository {}

void main() {
  late DeleteInventoryItemUseCaseImpl useCase;
  late MockInventoryRepository mockInventoryRepository;

  setUp(() {
    mockInventoryRepository = MockInventoryRepository();
    useCase = DeleteInventoryItemUseCaseImpl(mockInventoryRepository);
  });

  final tUserId = 'testUser';
  final tInventoryItemId = 'itemId1';

  test('should call deleteInventoryItem on the repository with correct parameters', () async {
    // Arrange
    when(mockInventoryRepository.deleteInventoryItem(any, any))
        .thenAnswer((_) async => Future.value()); // Mock a successful void future

    // Act
    await useCase.call(tUserId, tInventoryItemId);

    // Assert
    verify(mockInventoryRepository.deleteInventoryItem(tUserId, tInventoryItemId));
    verifyNoMoreInteractions(mockInventoryRepository);
  });
}
