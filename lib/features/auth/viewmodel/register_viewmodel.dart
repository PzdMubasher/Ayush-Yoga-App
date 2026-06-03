import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/auth_repository.dart';

class RegisterViewModel extends ChangeNotifier {
  final AuthRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  RegisterViewModel(this._repository);

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

  Future<void> register(String name, String email, String password) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    _errorMessage = null;
    _isSuccess = false;

    if (cleanName.isEmpty) {
      _errorMessage = "Please enter your name";
      notifyListeners();
      return;
    }

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
      _errorMessage = "Please choose a password";
      notifyListeners();
      return;
    }

    if (cleanPassword.length < 6) {
      _errorMessage = "Password must be at least 6 characters long";
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final success = await _repository.register(
        cleanName,
        cleanEmail,
        cleanPassword,
      );
      if (success) {
        _isSuccess = true;
      } else {
        _errorMessage = "Registration failed. Please try again.";
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        _errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        _errorMessage = 'The account already exists for that email.';
      } else {
        _errorMessage = e.message ?? "An error occurred during registration.";
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
