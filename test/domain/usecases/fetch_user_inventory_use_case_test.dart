import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:komarigoto_app/domain/entities/inventory_item.dart';
import 'package:komarigoto_app/domain/repositories/inventory_repository.dart';
import 'package:komarigoto_app/domain/usecases/fetch_user_inventory_use_case.dart';

// Mock InventoryRepository
class MockInventoryRepository extends Mock implements InventoryRepository {}

void main() {
  late FetchUserInventoryUseCaseImpl useCase;
  late MockInventoryRepository mockInventoryRepository;

  setUp(() {
    mockInventoryRepository = MockInventoryRepository();
    useCase = FetchUserInventoryUseCaseImpl(mockInventoryRepository);
  });

  final tUserId = 'testUser';
  final tInventoryList = [
    InventoryItem(ingredientId: 'ing1', status: 'in_stock', quantity: 1),
    InventoryItem(ingredientId: 'ing2', status: 'outof_stock', quantity: 0),
  ];

  test('should get inventory list from the repository for a given user ID', () async {
    // Arrange
    when(mockInventoryRepository.fetchUserInventory(tUserId))
        .thenAnswer((_) async => tInventoryList);
    // Act
    final result = await useCase.call(tUserId);
    // Assert
    expect(result, tInventoryList);
    verify(mockInventoryRepository.fetchUserInventory(tUserId));
    verifyNoMoreInteractions(mockInventoryRepository);
  });

  test('should throw an exception when the repository throws an exception', () async {
    // Arrange
    when(mockInventoryRepository.fetchUserInventory(tUserId))
        .thenThrow(Exception('Failed to fetch inventory'));
    // Act & Assert
    expect(() => useCase.call(tUserId), throwsException);
    verify(mockInventoryRepository.fetchUserInventory(tUserId));
    verifyNoMoreInteractions(mockInventoryRepository);
  });
}
