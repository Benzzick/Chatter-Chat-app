import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:chat_app/constants/app_constants.dart';
import 'package:chat_app/providers/client_provider.dart';
import 'package:chat_app/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class ImageUpload extends ConsumerStatefulWidget {
  const ImageUpload(
      {super.key,
      required this.name,
      required this.email,
      required this.password});
  final String name;
  final String email;
  final String password;

  @override
  ConsumerState<ImageUpload> createState() => _ImageUploadState();
}

class _ImageUploadState extends ConsumerState<ImageUpload> {
  File? _selectedImage;
  bool isCreating = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _registerAccount() async {
    if (_selectedImage != null) {
      setState(() {
        isCreating = true;
      });
      try {
        // First register the user and await the result
        await ref
            .read(userProvider.notifier)
            .register(widget.email, widget.password, widget.name);

        // Now read the user after registration is complete
        final user = ref.read(userProvider);
        if (user == null) {
          throw Exception('User registration failed');
        }

        final databases = ref.read(databasesProvider);
        final storage = ref.read(storageProvider);
        final fileId = ID.unique();

        // Upload the file to Appwrite storage
        await storage.createFile(
          bucketId: AppConstants.profileImagesBucket,
          fileId: fileId,
          file: InputFile.fromPath(path: _selectedImage!.path),
        );

        // Save the user data and fileId in the database
        await databases.createDocument(
          databaseId: AppConstants.databaseId,
          collectionId: AppConstants.usersCollection,
          documentId: user.$id,
          data: {
            'id': user.$id,
            'name': user.name,
            'email': user.email,
            'profileImageId': fileId,
          },
        );

        setState(() {
          isCreating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account Created Succesfully'),
        ));
        Navigator.pop(context);
      } catch (e) {
        setState(() {
          isCreating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $e"),
        ));
        // Consider showing an error message to the user
        // Consider handling specific error types differently
        rethrow; // Rethrow so calling code can handle the error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Profile Image')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey,
              radius: 90,
              backgroundImage:
                  _selectedImage == null ? null : FileImage(_selectedImage!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Choose Image'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _registerAccount();
              },
              child: const Text('Create Account'),
            ),
            const SizedBox(height: 20),
            if (isCreating)
              SpinKitFadingCircle(
                color: Theme.of(context).primaryColor,
                size: 50.0,
              ),
          ],
        ),
      ),
    );
  }
}
