import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_model.dart';

class AuthRepository {
  static const String _keyUsers = 'auth_users_db';
  static const String _keyActiveUser = 'auth_active_user';
  static const String _keyIsLoggedIn = 'auth_is_logged_in';

  // Perform login mock
  Future<bool> login(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();

    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 1200));

    final usersJson = prefs.getStringList(_keyUsers) ?? [];
    final cleanEmail = email.trim().toLowerCase();

    // 1. If user already exists in database, use their name
    for (var userStr in usersJson) {
      final userData = jsonDecode(userStr);
      if (userData['email'].toString().toLowerCase() == cleanEmail) {
        final user = UserModel(
          name: userData['name'],
          email: userData['email'],
        );
        await prefs.setString(_keyActiveUser, jsonEncode(user.toJson()));
        await prefs.setBool(_keyIsLoggedIn, true);
        return true;
      }
    }

    // 2. If user does not exist, allow login and generate a name from the email prefix
    String generatedName = cleanEmail.split('@').first;
    if (generatedName.isNotEmpty) {
      generatedName =
          generatedName[0].toUpperCase() + generatedName.substring(1);
    } else {
      generatedName = 'User';
    }

    final user = UserModel(name: generatedName, email: email.trim());
    await prefs.setString(_keyActiveUser, jsonEncode(user.toJson()));
    await prefs.setBool(_keyIsLoggedIn, true);
    return true;
  }

  // Perform register mock
  Future<bool> register(String name, String email, String password) async {
    final prefs = await SharedPreferences.getInstance();

    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 1200));

    final usersJson = prefs.getStringList(_keyUsers) ?? [];

    // Check if email already exists
    for (var userStr in usersJson) {
      final userData = jsonDecode(userStr);
      if (userData['email'].toString().toLowerCase() ==
          email.trim().toLowerCase()) {
        throw Exception("Email already registered!");
      }
    }

    // Save to users DB list
    final newUserMap = {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    };
    usersJson.add(jsonEncode(newUserMap));
    await prefs.setStringList(_keyUsers, usersJson);

    // Auto-login after registration
    final user = UserModel(
      name: name.trim(),
      email: email.trim().toLowerCase(),
    );
    await prefs.setString(_keyActiveUser, jsonEncode(user.toJson()));
    await prefs.setBool(_keyIsLoggedIn, true);

    return true;
  }

  // Check login state
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Fetch current active user details
  Future<UserModel?> getActiveUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_keyActiveUser);
    if (userStr == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(userStr));
    } catch (_) {
      return null;
    }
  }

  // Perform logout mock
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActiveUser);
    await prefs.setBool(_keyIsLoggedIn, false);
  }
}
