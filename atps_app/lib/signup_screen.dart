import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'atps_store.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _unitIdController = TextEditingController();

  final store = AtpsStore();

  void _handleSignup() async {
  final name = _nameController.text.trim();
  final username = _usernameController.text.trim();
  final password = _passwordController.text.trim();
  final unitId = _unitIdController.text.trim();

  if (name.isEmpty ||
      username.isEmpty ||
      password.isEmpty ||
      unitId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("All fields are required"),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  try {
    bool success =
        await store.createAccount(name, username, password, unitId, "DRIVER");

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Driver Account Created!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red,
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E14),
        title: const Text("Create Driver Account"),
        leading: const BackButton(color: Colors.grey),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                "Register Ambulance Unit",
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),

              _buildTextField("Full Name", Icons.person, _nameController),
              const SizedBox(height: 16),

              _buildTextField("Username", Icons.alternate_email, _usernameController),
              const SizedBox(height: 16),

              _buildTextField("Password", Icons.lock, _passwordController, isPassword: true),
              const SizedBox(height: 16),

              _buildTextField("ESP32 Unit ID (e.g., AMB-001)", Icons.qr_code, _unitIdController),

              const SizedBox(height: 32),

              Watch((context) => SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: store.isLoading.value ? null : _handleSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: store.isLoading.value
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "CREATE ACCOUNT",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF151B25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
