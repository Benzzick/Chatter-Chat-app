import 'package:chat_app/screens/image_upload.dart';
import 'package:flutter/material.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() {
    return _SignupState();
  }
}

class _SignupState extends State<Signup> with SingleTickerProviderStateMixin {
  late AnimationController controller;
  final formKey = GlobalKey<FormState>();
  String enteredName = '';
  String enteredEmail = '';
  String enteredPassword = '';

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: Durations.medium1);
    controller.forward();
  }

  void setup() {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ImageUpload(
              name: enteredName,
              email: enteredEmail,
              password: enteredPassword),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0); // Slide in from right
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
                  parent: controller, curve: Curves.easeInBack)),
              child: child,
            );
          },
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
                      style: const TextStyle(
                          color: Color.fromARGB(255, 80, 61, 6)),
                      autocorrect: true,
                      decoration: const InputDecoration(
                          border: InputBorder.none, hintText: 'Username'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Type a username';
                        }
                        return null;
                      },
                      onSaved: (name) {
                        enteredName = name!;
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
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                          color: Color.fromARGB(255, 80, 61, 6)),
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
                      style: const TextStyle(
                          color: Color.fromARGB(255, 80, 61, 6)),
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
                    child: const Text('Signup'),
                  ),
                  
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
