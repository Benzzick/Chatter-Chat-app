import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:chat_app/constants/app_constants.dart';
import 'package:chat_app/providers/client_provider.dart';
import 'package:chat_app/providers/user_provider.dart';
import 'package:chat_app/widgets/chat_blob.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen(
      {super.key, required this.imgUrl, required this.recieverUserId});

  final String imgUrl;
  final Document recieverUserId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final chatController = TextEditingController();
  bool isLoading = false;
  List<Document> messages = [];
  late final RealtimeSubscription subscription;
  io.File? _selectedImage;
  bool isSending = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = io.File(pickedFile.path);
      });
    }
  }

  @override
  void dispose() {
    chatController.dispose();
    subscription.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchData();
    });
    setupRealtimeSubscription();
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
    });
    await getMessages();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> getMessages() async {
    try {
      final databases = ref.read(databasesProvider);
      final mainUserId = ref.watch(userProvider)!.$id;
      final recieverId = widget.recieverUserId.$id;

      final documentList = await databases.listDocuments(
        databaseId: AppConstants.databaseId,
        collectionId: AppConstants.messagesCollection,
        queries: [
          Query.orderDesc('timestamp'),
          Query.or([
            Query.equal('conversationId', '${mainUserId}_$recieverId'),
            Query.equal('conversationId', '${recieverId}_$mainUserId'),
          ]),
        ],
      );

      setState(() {
        messages = documentList.documents;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching messages: ${e.toString()}')),
      );
    }
  }

  void setupRealtimeSubscription() {
    final realtime = ref.read(realtimeProvider);
    final mainUserId = ref.read(userProvider)!.$id;
    final recieverId = widget.recieverUserId.$id;

    subscription = realtime.subscribe([
      'databases.${AppConstants.databaseId}.collections.${AppConstants.messagesCollection}.documents'
    ]);

    subscription.stream.listen((response) async {
      if (response.events
          .contains('databases.*.collections.*.documents.*.create')) {
        final payload = response.payload;
        if (payload['conversationId'] == '${mainUserId}_$recieverId' ||
            payload['conversationId'] == '${recieverId}_$mainUserId') {
          setState(() {
            messages.insert(0, Document.fromMap(payload));
          });
        }
      } else if (response.events
          .contains('databases.*.collections.*.documents.*.update')) {
        final payload = response.payload;
        if (payload['conversationId'] == '${mainUserId}_$recieverId' ||
            payload['conversationId'] == '${recieverId}_$mainUserId') {
          setState(() {
            final index =
                messages.indexWhere((msg) => msg.$id == payload['\$id']);
            if (index != -1) {
              messages[index] = Document.fromMap(payload);
            }
          });
        }
      }
    });
  }

  Future<void> sendMessage() async {
    if (chatController.text.trim().isNotEmpty) {
      try {
        final databases = ref.read(databasesProvider);
        final storage = ref.read(storageProvider);
        final mainUserId = ref.watch(userProvider)!.$id;
        final recieverId = widget.recieverUserId.$id;
        final fileId = ID.unique();

        setState(() {
          isSending = true;
        });

        if (_selectedImage != null) {
          // Upload the file to Appwrite storage
          await storage.createFile(
            bucketId: AppConstants.messageImagesBucket,
            fileId: fileId,
            file: InputFile.fromPath(path: _selectedImage!.path),
          );
        }
        await databases.createDocument(
          databaseId: AppConstants.databaseId,
          collectionId: AppConstants.messagesCollection,
          documentId: fileId,
          data: {
            'senderId': mainUserId,
            'receiverId': recieverId,
            'content': chatController.text,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            'conversationId': '${mainUserId}_$recieverId',
            'isRead': false,
            'isImage': _selectedImage == null ? false : true,
          },
        );
        chatController.clear();
        setState(() {
          _selectedImage = null;
        });
        setState(() {
          isSending = false;
        });
      } catch (e) {
        setState(() {
          isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending message: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainUserId = ref.read(userProvider)!.$id;
    final recieverId = widget.recieverUserId.$id;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Hero(
              tag: widget.recieverUserId.$id,
              child: CircleAvatar(
                backgroundImage: NetworkImage(widget.imgUrl),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.recieverUserId.data['name']),
          ],
        ),
      ),
      body: isLoading
          ? Center(
              child: SpinKitDoubleBounce(
                color: Theme.of(context).primaryColor,
                size: 50.0,
              ),
            )
          : messages.isEmpty
              ? const Center(child: Text('No Messages yet'))
              : Padding(
                  padding:
                      const EdgeInsets.only(left: 40, right: 40, bottom: 100),
                  child: ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return ChatBlob(
                        message: messages[index],
                        recConversationId: '${recieverId}_$mainUserId',
                      );
                    },
                  ),
                ),
      bottomSheet: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImage != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20)),
                      child: Image.file(
                        _selectedImage!,
                        width: 100,
                      ),
                    ),
                    Positioned(
                      left: 60,
                      top: -10,
                      child: IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedImage = null;
                            });
                          },
                          icon: const Icon(Icons.cancel)),
                    ),
                  ],
                ),
              ),
            if (_selectedImage != null)
              const SizedBox(
                height: 10,
              ),
            Container(
              decoration: BoxDecoration(
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 3,
                    offset: Offset(3, 3),
                  ),
                ],
                color: Theme.of(context).colorScheme.surfaceDim,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.link),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: chatController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(30)),
                          ),
                          hintText: 'Send a message.',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: isSending
                          ? null
                          : () async {
                              await sendMessage();
                            },
                      icon: const Icon(Icons.send),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
