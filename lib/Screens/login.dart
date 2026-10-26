import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

import 'package:cricbuzz/Screens/session.dart';
import 'package:cricbuzz/Screens/config.dart';

import 'package:cricbuzz/Admin/select_time.dart' as admin;
import 'package:cricbuzz/Stockist/select_time.dart' as stockist;
import 'package:cricbuzz/Sub Stockist/select_time.dart' as substockist;
import 'package:cricbuzz/Result Admin/select_time.dart' as resultadmin;
import 'package:cricbuzz/Dealer/select_time.dart' as dealer;
import 'package:cricbuzz/Agent/select_time.dart' as agent;
import 'package:cricbuzz/Manager/select_time.dart' as manager;
import 'package:cricbuzz/services/schedule_manager.dart'; // Adjust path if needed
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final url = Uri.parse('${AppConfig.baseUrl}/api/login/');

    final body = jsonEncode({
      'username': _usernameController.text.trim(),
      'password': _passwordController.text.trim(),
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        MySession.token = data['access'];
        MySession.refreshToken = data['refresh'];
        MySession.username = data['user'];

        // Save to secure storage for background tasks
        const storage = FlutterSecureStorage();
        await storage.write(key: 'jwt_access_token', value: data['access']);
        await storage.write(key: 'jwt_refresh_token', value: data['refresh']);

        Widget nextPage;

        switch (data['role']) {
          case 'admin':
            // 3. 👈 ADD THIS LINE HERE TO TRIGGER THE REQUEST TO DJANGO:
            await AutoDownloadScheduler.syncSchedulesWithBackend();
            nextPage = const admin.SelectTimePage();
            break;

          case 'stockist':
            nextPage = const stockist.SelectTimePage();
            break;

          case 'substockist':
            nextPage = const substockist.SelectTimePage();
            break;

          case 'resultadmin':
            nextPage = const resultadmin.SelectTimePage();
            break;

          case 'dealer':
            nextPage = const dealer.SelectTimePage();
            break;

          case 'agent':
            nextPage = const agent.SelectTimePage();
            break;

          case 'manager':
            nextPage = const manager.SelectTimePage();
            break;

          default:
            _showSnackBar("Role not recognized");
            return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => nextPage),
        );
      } else {
        final data = jsonDecode(response.body);

        _showSnackBar(data['error'] ?? "Login failed");
      }
    } catch (e) {
      setState(() => isLoading = false);

      _showSnackBar("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBurgundy = Color(0xFF6B0F0F);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                const Text(
                  'LOGIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.5,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'USERNAME',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),

                TextFormField(
                  controller: _usernameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Enter username";
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Your username',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey, width: 1),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 1.5),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'PASSWORD',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Enter password";
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Your password',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey, width: 1),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 1.5),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBurgundy,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text(
                    'REGISTER NEW ACCOUNT',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text(
                    'FORGOT PASSWORD',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
