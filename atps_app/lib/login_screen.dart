import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'atps_store.dart';
import 'driver_dashboard.dart';
import 'admin_dashboard.dart';
import 'signup_screen.dart';
import 'admin_signup_screen.dart';

// --- GLOBAL SESSION MANAGER ---
// This keeps track of who is logged in while the app is running
class AppSession {
  static String? loggedInRole;
}

class LoginScreen extends StatefulWidget {
  final String role; 
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final store = AtpsStore(); 
  
  // State for the checkbox
  bool _stayLoggedIn = false; 

  @override
  void initState() {
    super.initState();
    // Auto-login check: If they checked the box earlier, skip the login screen!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppSession.loggedInRole == widget.role) {
        _navigateToDashboard();
      }
    });
  }

  void _navigateToDashboard() {
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => widget.role == "ADMIN" ? const AdminDashboard() : const DriverDashboard())
    );
  }

  void _handleLogin() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showError("Please enter credentials");
      return;
    }

    bool success = await store.login(username, password, widget.role);

    if (success && mounted) {
      // Save session if checkbox is checked
      if (_stayLoggedIn) {
        AppSession.loggedInRole = widget.role;
      }
      _navigateToDashboard();
    } else if (mounted) {
      _showError("Invalid Credentials or Access Denied");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.role == "ADMIN";
    
    // If they are already logged in, show a blank screen while it auto-routes
    if (AppSession.loggedInRole == widget.role) {
      return const Scaffold(backgroundColor: Color(0xFF0B0E14), body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white54),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 400, 
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF151B25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isAdmin ? Icons.security : Icons.medical_services, size: 50, color: isAdmin ? Colors.blueAccent : Colors.redAccent),
                const SizedBox(height: 24),
                Text(
                  isAdmin ? "Admin Login" : "Driver Login",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 32),

                _buildTextField("Username", Icons.person, _usernameController),
                const SizedBox(height: 20),
                _buildTextField("Password", Icons.lock, _passwordController, isPassword: true),
                const SizedBox(height: 10),

                // THE NEW "STAY LOGGED IN" CHECKBOX
                Theme(
                  data: ThemeData(unselectedWidgetColor: Colors.grey),
                  child: CheckboxListTile(
                    title: const Text("Stay Logged In", style: TextStyle(color: Colors.white70)),
                    value: _stayLoggedIn,
                    activeColor: isAdmin ? Colors.blueAccent : Colors.redAccent,
                    checkColor: Colors.white,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool? value) {
                      setState(() {
                        _stayLoggedIn = value ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                Watch((context) {
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: store.isLoading.value ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAdmin ? Colors.blueAccent : Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: store.isLoading.value 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("LOGIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  );
                }),
                const SizedBox(height: 24),

                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => isAdmin ? const AdminSignupScreen() : const SignupScreen()));
                  },
                  child: const Text("Register a new account", style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
        fillColor: const Color(0xFF0B0E14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}