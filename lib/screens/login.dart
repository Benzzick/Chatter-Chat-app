import 'package:chat_app/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_spinkit/flutter_spinkit.dart';

class Login extends ConsumerStatefulWidget {
  const Login({super.key});

  @override
  ConsumerState<Login> createState() {
    return _LoginState();
  }
}

class _LoginState extends ConsumerState<Login> {
  final formKey = GlobalKey<FormState>();
  String enteredEmail = '';
  String enteredPassword = '';
  bool isLoggingIn = false;

  void setup() async {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();

      try {
        setState(() {
          isLoggingIn = true;
        });
        await ref
            .read(userProvider.notifier)
            .login(enteredEmail, enteredPassword);
        setState(() {
          isLoggingIn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Loggedin Succesfully'),
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $e"),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                  child: TextFormField(
                    keyboardType: TextInputType.emailAddress,
                    style:
                        const TextStyle(color: Color.fromARGB(255, 80, 61, 6)),
                    decoration: const InputDecoration(
                        border: InputBorder.none, hintText: 'Email'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Type a valid email';
                      }
                      return null;
                    },
                    onSaved: (email) {
                      enteredEmail = email!;
                    },
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                  child: TextFormField(
                    obscureText: true,
                    style:
                        const TextStyle(color: Color.fromARGB(255, 80, 61, 6)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Password',
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty ||
                          value.trim().length < 4) {
                        return 'Type stronger password';
                      }
                      return null;
                    },
                    onSaved: (password) {
                      enteredPassword = password!;
                    },
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: setup,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                      fixedSize: const Size(100, 50)),
                  child: const Text('Login'),
                ),
                const SizedBox(
                  height: 20,
                ),
                if (isLoggingIn)
                  SpinKitDoubleBounce(
                    color: Theme.of(context).primaryColor,
                    size: 50.0,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
