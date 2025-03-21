import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:chat_app/providers/client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserNotifier extends StateNotifier<User?> {
  UserNotifier(this.account) : super(null);
  final Account account;

  Future<void> checkExistingSession() async {
    try {
      final user = await account.get();
      state = user;
    } catch (e) {
      state = null;
    }
  }

  Future<void> login(String email, String password) async {
    await account.createEmailPasswordSession(email: email, password: password);
    final user = await account.get();
    state = user;
  }

  Future<void> register(String email, String password, String name) async {
    await account.create(
        userId: ID.unique(), email: email, password: password, name: name);
    await login(email, password);
  }

  Future<void> logout() async {
    await account.deleteSession(sessionId: 'current');
    state = null;
  }
}

final userProvider = StateNotifierProvider<UserNotifier, User?>(
  (ref) {
    final account = ref.watch(accountProvider);
    return UserNotifier(account);
  },
);
