import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'atps_store.dart';

class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({super.key});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cyberIdController = TextEditingController();
  final store = AtpsStore();

  void _handleSignup() async {
    final name = _nameController.text;
    final username = _usernameController.text;
    final password = _passwordController.text;
    final cyberId = _cyberIdController.text;

    if (name.isEmpty || username.isEmpty || password.isEmpty || cyberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required"), backgroundColor: Colors.red)
      );
      return;
    }

    // --- UPDATED LOGIC ---
    // This now waits for the server to reply with either NULL (success) or an ERROR STRING.
    bool success =
    await store.createAdminAccount(name, username, password, cyberId);

if (success && mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Admin Account Created! Please Login."),
      backgroundColor: Colors.green,
    ),
  );
  Navigator.pop(context);
} else if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Admin signup failed"),
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
        title: const Text("Register Cyber Cell Admin"),
        leading: const BackButton(color: Colors.grey),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.security, size: 50, color: Colors.blueAccent),
              ),
              const SizedBox(height: 24),
              
              Text("Cyber Cell Registration", style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text("Authorized Personnel Only", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),

              _buildTextField("Officer Name", Icons.person, _nameController),
              const SizedBox(height: 16),
              _buildTextField("System Username", Icons.alternate_email, _usernameController),
              const SizedBox(height: 16),
              _buildTextField("Secure Password", Icons.lock, _passwordController, isPassword: true),
              const SizedBox(height: 16),
              _buildTextField("Cyber Cell ID (e.g., CYBER-001)", Icons.badge, _cyberIdController),

              const SizedBox(height: 32),

              Watch((context) {
                return SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: store.isLoading.value ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: store.isLoading.value 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("REGISTER ADMIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget must be inside the class
  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isPassword = false}) {
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
      ),
    );
  }
}