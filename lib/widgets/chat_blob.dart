import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:chat_app/constants/app_constants.dart';
import 'package:chat_app/providers/client_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class ChatBlob extends ConsumerStatefulWidget {
  const ChatBlob({
    super.key,
    required this.message,
    required this.recConversationId,
  });

  final Document message;
  final String recConversationId;

  @override
  ConsumerState<ChatBlob> createState() => _ChatBlobState();
}

class _ChatBlobState extends ConsumerState<ChatBlob> {
  String? imageUrl;
  @override
  void initState() {
    fetchImage();
    markAllAsRead();
    subscribeToRealtimeUpdates();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ChatBlob oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.message.$id != oldWidget.message.$id) {
      fetchImage();
    }
  }

  void subscribeToRealtimeUpdates() {
    final realtime = ref.read(realtimeProvider);

    final subscription = realtime.subscribe([
      'databases.${AppConstants.databaseId}.collections.${AppConstants.messagesCollection}.documents'
    ]);

    subscription.stream.listen((response) async {
      if (response.events
          .contains('databases.*.collections.*.documents.*.create')) {
        final newMessage = Document.fromMap(response.payload);
        final conversationId = newMessage.data['conversationId'];

        if (conversationId == widget.recConversationId) {
          await markMessageAsRead(newMessage.$id);
        }
      }
    });
  }

  Future<void> markMessageAsRead(String messageId) async {
    final databases = ref.read(databasesProvider);
    try {
      await databases.updateDocument(
        databaseId: AppConstants.databaseId,
        collectionId: AppConstants.messagesCollection,
        documentId: messageId,
        data: {'isRead': true},
      );
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  Future<void> fetchImage() async {
    try {
      final client = ref.read(clientProvider);
      // Construct the preview URL with the hardcoded project ID from your constants
      final previewUrl =
          '${client.endPoint}/storage/buckets/${AppConstants.messageImagesBucket}/files/${widget.message.$id}/preview?project=${AppConstants.projectId}';
      setState(() {
        imageUrl = previewUrl;
      });
    } on AppwriteException {
      // return null;
    }
  }

  String formatTimestamp(String timestamp) {
    try {
      final intTimestamp = int.parse(timestamp);
      final dateTime = DateTime.fromMillisecondsSinceEpoch(intTimestamp);
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid time';
    }
  }

  Future<void> markAllAsRead() async {
    final databases = ref.read(databasesProvider);
    if (widget.message.data['isRead'] == false &&
        widget.message.data['conversationId'] == widget.recConversationId) {
      await Future.delayed(const Duration(seconds: 1));
      await databases.updateDocument(
        databaseId: AppConstants.databaseId,
        collectionId: AppConstants.messagesCollection,
        documentId: widget.message.$id,
        data: {'isRead': true},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = widget.message.data['isRead'] == false;
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final formattedTime = formatTimestamp(widget.message.data['timestamp']);

    if (widget.message.data['conversationId'] == widget.recConversationId) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUnread
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatBubble(
              clipper: ChatBubbleClipper1(type: BubbleType.receiverBubble),
              backGroundColor: Theme.of(context).colorScheme.inverseSurface,
              margin: const EdgeInsets.only(top: 20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  child: Column(
                    children: [
                      if (widget.message.data['isImage'])
                        Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Stack(
                            children: [
                              Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey[300],
                                ),
                              ),
                              Image.network(
                                imageUrl!,
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const SizedBox.shrink();
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.broken_image,
                                        size: 50, color: Colors.grey),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      Text(
                        widget.message.data['content'],
                        style: TextStyle(
                          color: isDarkMode
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formattedTime),
                if (isUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    // Sender's message layout remains the same...
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            const Spacer(),
            ChatBubble(
              clipper: ChatBubbleClipper1(type: BubbleType.sendBubble),
              backGroundColor: Theme.of(context).colorScheme.inversePrimary,
              margin: const EdgeInsets.only(top: 20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  child: Column(
                    children: [
                      if (widget.message.data['isImage'])
                        Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Stack(
                            children: [
                              Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey[300],
                                ),
                              ),
                              Image.network(
                                imageUrl!,
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const SizedBox.shrink();
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.broken_image,
                                        size: 50, color: Colors.grey),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      Text(widget.message.data['content']),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Text(formattedTime),
      ],
    );
  }
}
