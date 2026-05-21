import 'package:flutter/foundation.dart';
import '../model/auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  LoginViewModel(this._repository);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSuccess => _isSuccess;

  // Resets error and success states so they don't trigger repeatedly in the View
  void clearState() {
    _isLoading = false;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    _errorMessage = null;
    _isSuccess = false;

    if (cleanEmail.isEmpty) {
      _errorMessage = "Please enter your email address";
      notifyListeners();
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(cleanEmail)) {
      _errorMessage = "Please enter a valid email address";
      notifyListeners();
      return;
    }

    if (cleanPassword.isEmpty) {
      _errorMessage = "Please enter your password";
      notifyListeners();
      return;
    }

    if (cleanPassword.length < 6) {
      _errorMessage = "Password must be at least 6 characters";
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final success = await _repository.login(cleanEmail, cleanPassword);
      if (success) {
        _isSuccess = true;
      } else {
        _errorMessage = "Invalid email or password. Please try again.";
      }
    } catch (e) {
      _errorMessage = "An unexpected error occurred: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
