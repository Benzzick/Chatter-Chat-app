import 'package:chat_app/providers/user_provider.dart';
import 'package:chat_app/screens/chat_list.dart';
import 'package:chat_app/screens/login.dart';
import 'package:chat_app/screens/signup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatApp extends ConsumerStatefulWidget {
  const ChatApp({super.key});

  @override
  ConsumerState<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends ConsumerState<ChatApp> {
  @override
  void initState() {
    super.initState();
    ref.read(userProvider.notifier).checkExistingSession();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    return user == null
        ? DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Chatter'),
              ),
              body: const Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(
                        icon: Icon(Icons.create),
                      ),
                      Tab(
                        icon: Icon(Icons.login),
                      )
                    ],
                  ),
                  Expanded(
                    child: TabBarView(children: [Signup(), Login()]),
                  )
                ],
              ),
            ),
          )
        : const ChatList();
  }
}
