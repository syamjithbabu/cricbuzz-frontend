import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cricbuzz/Screens/login.dart';

class FakeLoginScreen extends StatefulWidget {
  const FakeLoginScreen({super.key});

  @override
  State<FakeLoginScreen> createState() => _FakeLoginScreenState();
}

class _FakeLoginScreenState extends State<FakeLoginScreen> {
  Timer? _longPressTimer;

  // Starts the 2-second countdown when the user presses down
  void _startLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        print("1-second long press detected! Navigating to real login...");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    });
  }

  // Cancels the timer if the user releases or drags away before 2 seconds
  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel(); // Always clean up timers on widget dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Login Card Container
                Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 40),
                      const TextField(
                        decoration: InputDecoration(
                          hintText: 'User ID',
                          hintStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey, width: 0.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const TextField(
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Enter Password',
                          hintStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey, width: 0.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),

                      // Sign In Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5EB5F7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Footer Links
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              "Forgot Password",
                              style: TextStyle(
                                color: Color(0xFF2E79A6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Text(" | ",
                              style: TextStyle(color: Color(0xFF2E79A6))),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              "Support",
                              style: TextStyle(
                                color: Color(0xFF2E79A6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // Cricbuzz Logo Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "cri",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF008D5B),
                      ),
                    ),

                    // --- DETECTOR ZONE: 2-Second Hold on Green Circle ---
                    GestureDetector(
                      onTapDown: (_) => _startLongPressTimer(),
                      onTapUp: (_) => _cancelLongPressTimer(),
                      onTapCancel: () => _cancelLongPressTimer(),
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: const BoxDecoration(
                          color: Color(0xFF008D5B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    const Text(
                      "uzz",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF008D5B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}