# Changelog
## [0.1.1]

- **Cleanup** Cleanup tests folder structure, expose them to be used by concrete implementations.

## [0.1.0]

### Enhanced ✨
- **Comprehensive Test Coverage**: Expanded test suite from 69 to 87 tests with enhanced serialization coverage
- **Complete `enqueuePayload()` Testing**: Added missing tests for `enqueuePayload()` method in queue test suite
- **Method Equivalence Validation**: Tests now verify both `enqueue()` and `enqueuePayload()` produce identical results
- **Serialization Test Suite**: New dedicated test suite (`serialization_test.dart`) with 18 comprehensive tests
  - Unit tests for all serializer types (JSON String, JSON Map, Binary)
  - Queue integration tests with different serializers
  - Serialization call tracking and verification
  - Comprehensive error handling (SerializationError, DeserializationError)
  - Performance validation (no overhead when T == S)

### Added 📦
- **Serialization Examples**: New `example/serialization_example.dart` demonstrating:
  - JSON String and Binary serialization
  - Both enqueue methods with serializers
  - Direct storage (no serialization)
  - Method equivalence testing
  - Error handling scenarios

### Improved 📚
- **Documentation**: Enhanced README and test documentation with:
  - Comprehensive serialization guide
  - Updated API examples showing both enqueue methods
  - Test coverage breakdown (87 tests total)
  - Serialization patterns and examples
- **Test Organization**: Better organized tests into logical groups for improved maintainability

### Fixed 🐛
- **Test Coverage Gaps**: Eliminated missing coverage for `enqueuePayload()` in main queue tests
- **Test Redundancy**: Consolidated duplicate serialization tests while maintaining comprehensive coverage

---

## [0.0.1] - Initial Release

### Features
- Backend-agnostic queue interface
- Production-ready reliability features
- Comprehensive test suite
- In-memory implementation
