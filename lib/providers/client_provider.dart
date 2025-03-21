import 'package:appwrite/appwrite.dart';
import 'package:chat_app/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clientProvider = Provider(
  (ref) {
    return Client()
        .setEndpoint(AppConstants.projectEndPoint)
        .setProject(AppConstants.projectId);
  },
);

final accountProvider = Provider(
  (ref) {
    final client = ref.watch(clientProvider);
    return Account(client);
  },
);

final databasesProvider = Provider(
  (ref) {
    final client = ref.watch(clientProvider);
    return Databases(client);
  },
);

final storageProvider = Provider(
  (ref) {
    final client = ref.watch(clientProvider);
    return Storage(client);
  },
);

final realtimeProvider = Provider(
  (ref) {
    final client = ref.watch(clientProvider);
    return Realtime(client);
  },
);
