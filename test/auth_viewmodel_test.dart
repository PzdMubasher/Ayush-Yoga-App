import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoga_day_app/features/auth/model/auth_repository.dart';
import 'package:yoga_day_app/features/auth/viewmodel/login_viewmodel.dart';
import 'package:yoga_day_app/features/auth/viewmodel/register_viewmodel.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoginViewModel Tests', () {
    late AuthRepository repository;
    late LoginViewModel viewModel;

    setUp(() {
      repository = AuthRepository();
      viewModel = LoginViewModel(repository);
    });

    test('Empty email validation', () async {
      await viewModel.login('', 'password123');
      expect(viewModel.errorMessage, 'Please enter your email address');
      expect(viewModel.isSuccess, false);
    });

    test('Invalid email validation', () async {
      await viewModel.login('invalidemail', 'password123');
      expect(viewModel.errorMessage, 'Please enter a valid email address');
      expect(viewModel.isSuccess, false);
    });

    test('Empty password validation', () async {
      await viewModel.login('test@gmail.com', '');
      expect(viewModel.errorMessage, 'Please enter your password');
      expect(viewModel.isSuccess, false);
    });

    test('Short password validation', () async {
      await viewModel.login('test@gmail.com', '12345');
      expect(viewModel.errorMessage, 'Password must be at least 6 characters');
      expect(viewModel.isSuccess, false);
    });

    test('Login succeeds even when user does not exist', () async {
      await viewModel.login('nonexistent@gmail.com', 'password123');
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isSuccess, true);
    });
  });

  group('RegisterViewModel Tests', () {
    late AuthRepository repository;
    late RegisterViewModel viewModel;

    setUp(() {
      repository = AuthRepository();
      viewModel = RegisterViewModel(repository);
    });

    test('Empty name validation', () async {
      await viewModel.register('', 'test@gmail.com', 'password123');
      expect(viewModel.errorMessage, 'Please enter your name');
      expect(viewModel.isSuccess, false);
    });

    test('Empty email validation', () async {
      await viewModel.register('John Doe', '', 'password123');
      expect(viewModel.errorMessage, 'Please enter your email address');
      expect(viewModel.isSuccess, false);
    });

    test('Invalid email validation', () async {
      await viewModel.register('John Doe', 'invalidemail', 'password123');
      expect(viewModel.errorMessage, 'Please enter a valid email address');
      expect(viewModel.isSuccess, false);
    });

    test('Empty password validation', () async {
      await viewModel.register('John Doe', 'test@gmail.com', '');
      expect(viewModel.errorMessage, 'Please choose a password');
      expect(viewModel.isSuccess, false);
    });

    test('Short password validation', () async {
      await viewModel.register('John Doe', 'test@gmail.com', '12345');
      expect(viewModel.errorMessage, 'Password must be at least 6 characters long');
      expect(viewModel.isSuccess, false);
    });

    test('Successful registration and subsequent login', () async {
      final loginViewModel = LoginViewModel(repository);

      // 1. Register new user
      await viewModel.register('John Doe', 'john@gmail.com', 'securepass');
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isSuccess, true);

      // Verify active user is set in repository
      final activeUser = await repository.getActiveUser();
      expect(activeUser, isNotNull);
      expect(activeUser!.name, 'John Doe');
      expect(activeUser.email, 'john@gmail.com');

      // Verify logged in state in repository
      expect(await repository.isLoggedIn(), true);

      // 2. Perform logout to test clean login later
      await repository.logout();
      expect(await repository.isLoggedIn(), false);

      // 3. Login with newly registered user using LoginViewModel
      await loginViewModel.login('john@gmail.com', 'securepass');
      expect(loginViewModel.errorMessage, isNull);
      expect(loginViewModel.isSuccess, true);
    });

    test('Register same email triggers error', () async {
      await viewModel.register('User One', 'same@gmail.com', 'password123');
      expect(viewModel.isSuccess, true);

      final secondViewModel = RegisterViewModel(repository);

      await secondViewModel.register(
        'User Two',
        'same@gmail.com',
        'password123',
      );
      expect(secondViewModel.isSuccess, false);
      expect(secondViewModel.errorMessage, 'Email already registered!');
    });
  });
}
