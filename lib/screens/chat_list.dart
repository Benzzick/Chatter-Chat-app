import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:chat_app/constants/app_constants.dart';
import 'package:chat_app/providers/client_provider.dart';
import 'package:chat_app/providers/user_provider.dart';
import 'package:chat_app/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatList extends ConsumerStatefulWidget {
  const ChatList({super.key});

  @override
  ConsumerState<ChatList> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<ChatList> {
  List<models.Document> users = [];
  Map<String, String> imageUrls = {};
  models.User? user;
  Map<String, String> lastMessages = {};
  Map<String, int> unreadMessages = {};

  @override
  void initState() {
    super.initState();
    subscribeToRealtimeUpdates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchData();
    });
  }

  void subscribeToRealtimeUpdates() {
  final realtime = ref.read(realtimeProvider);
  final subscription = realtime.subscribe([
    'databases.${AppConstants.databaseId}.collections.${AppConstants.messagesCollection}.documents'
  ]);

  subscription.stream.listen((response) {
    if (response.events
        .contains('databases.*.collections.*.documents.*.create')) {
      final newMessage = models.Document.fromMap(response.payload);
      final senderId = newMessage.data['senderId'];
      final receiverId = newMessage.data['receiverId'];
      final isRead = newMessage.data['isRead'] ?? false;

      if (senderId == user?.$id || receiverId == user?.$id) {
        setState(() {
          final conversationUserId =
              receiverId == user?.$id ? senderId : receiverId;

          // Update last message and timestamp
          lastMessages[conversationUserId] = newMessage.data['content'];
          lastMessages['${conversationUserId}_timestamp'] =
              newMessage.data['timestamp'] ?? '';

          // Update unread message count if the current user is the receiver and the message is unread
          if (receiverId == user?.$id && !isRead) {
            unreadMessages[conversationUserId] =
                (unreadMessages[conversationUserId] ?? 0) + 1;
          }

          // Re-sort users by the latest timestamp
          users.sort((a, b) {
            final aTimestamp = lastMessages['${a.$id}_timestamp'] ?? '0';
            final bTimestamp = lastMessages['${b.$id}_timestamp'] ?? '0';
            return bTimestamp.compareTo(aTimestamp);
          });
        });
      }
    }

    if (response.events
        .contains('databases.*.collections.*.documents.*.update')) {
      final updatedMessage = models.Document.fromMap(response.payload);
      final conversationId = updatedMessage.data['conversationId'];
      final isRead = updatedMessage.data['isRead'] ?? false;

      if (conversationId.contains(user?.$id) && isRead) {
        final otherUserId = conversationId
            .replaceFirst('${user?.$id}_', '')
            .replaceFirst('_${user?.$id}', '');

        // Decrease unread count for the updated message
        setState(() {
          unreadMessages[otherUserId] = (unreadMessages[otherUserId] ?? 0) > 0
              ? unreadMessages[otherUserId]! - 1
              : 0;
        });
      }
    }
  });
}


  void fetchData() async {
    user = ref.read(userProvider);
    await fetchUsers();
    await fetchImages();
    setState(() {});
  }

  Future<void> fetchUsers() async {
    try {
      final databases = ref.read(databasesProvider);
      final documentList = await databases.listDocuments(
        databaseId: AppConstants.databaseId,
        collectionId: AppConstants.usersCollection,
      );
      // Show all users except current user
      users = documentList.documents
          .where((document) => document.$id != user?.$id)
          .toList();
      for (var userDoc in users) {
        await fetchLastMessage(userDoc.$id);
        await fetchUreadMessages(userDoc.$id);
      }
      // debugPrint('Found ${users.length} users');
    } on AppwriteException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching users: ${e.message}')));
    }
  }

  Future<void> fetchUreadMessages(String userId) async {
    try {
      final databases = ref.read(databasesProvider);
      final response = await databases.listDocuments(
        databaseId: AppConstants.databaseId,
        collectionId: AppConstants.messagesCollection,
        queries: [
          Query.and([
            Query.equal('conversationId', '${userId}_${user?.$id}'),
            Query.equal('isRead', false),
          ]),
        ],
      );

      unreadMessages[userId] = response.documents.length;
    } catch (e) {
      //
    }
  }

  Future<void> fetchLastMessage(String userId) async {
    try {
      final databases = ref.read(databasesProvider);
      final response = await databases.listDocuments(
        databaseId: AppConstants.databaseId,
        collectionId: AppConstants.messagesCollection,
        queries: [
          Query.or([
            Query.equal('conversationId', '${user?.$id}_$userId'),
            Query.equal('conversationId', '${userId}_${user?.$id}'),
          ]),
          Query.orderDesc('timestamp'), // Sort by timestamp descending
          Query.limit(1), // Get the latest message
        ],
      );

      if (response.documents.isNotEmpty) {
        final lastMessageDoc = response.documents.first;
        setState(() {
          lastMessages[userId] = lastMessageDoc.data['content'];
          // Store the timestamp as well
          lastMessages['${userId}_timestamp'] =
              lastMessageDoc.data['timestamp'] ?? '';
        });

        // Re-sort users by the latest timestamp
        users.sort((a, b) {
          final aTimestamp =
              lastMessages['${a.$id}_timestamp'] ?? '0'; // Default to 0
          final bTimestamp =
              lastMessages['${b.$id}_timestamp'] ?? '0'; // Default to 0
          return bTimestamp.compareTo(aTimestamp); // Descending order
        });
      }
    } catch (e) {
      debugPrint('Error fetching last message for user $userId: $e');
    }
  }

  Future<void> fetchImages() async {
    try {
      final client = ref.read(clientProvider);

      for (var userDoc in users) {
        try {
          // Construct the preview URL with the hardcoded project ID from your constants
          final previewUrl =
              '${client.endPoint}/storage/buckets/${AppConstants.profileImagesBucket}/files/${userDoc.data['profileImageId']}/preview?project=${AppConstants.projectId}';
          debugPrint('Generated URL for user ${userDoc.$id}: $previewUrl');
          imageUrls[userDoc.$id] = previewUrl;
        } catch (e) {
          debugPrint(
              'Error generating preview URL for user ${userDoc.$id}: $e');
        }
      }
      debugPrint('Generated URLs for ${imageUrls.length} users');
    } on AppwriteException catch (e) {
      debugPrint('Error fetching images: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton.filled(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(
              onPressed: () {
                ref.read(userProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout))
        ],
      ),
      body: users.isEmpty
          ? const Center(child: Text('No users found'))
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final imageUrl = imageUrls[user.$id];

                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListTile(
                      splashColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      leading: imageUrl != null
                          ? Hero(
                              tag: user.$id,
                              child: CircleAvatar(
                                backgroundImage: NetworkImage(imageUrl),
                                radius: 30,
                              ),
                            )
                          : const CircleAvatar(
                              radius: 20,
                              child: Icon(Icons.person),
                            ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.data['name'] ?? 'Unknown User',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        lastMessages[user.$id] ??
                            'Send a Message to ${user.data['name']}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      trailing: unreadMessages[user.$id] == null ||
                              unreadMessages[user.$id] == 0
                          ? null
                          : AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  unreadMessages[user.$id].toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) {
                            return ChatScreen(
                                imgUrl: imageUrl!, recieverUserId: user);
                          },
                        ));
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
