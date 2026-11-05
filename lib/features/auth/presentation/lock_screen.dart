import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/security_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({Key? key}) : super(key: key);

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final List<String> _enteredPin = [];
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin.add(digit);
        _errorMessage = null;
      });

      if (_enteredPin.length == 4) {
        _verify();
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin.removeLast();
        _errorMessage = null;
      });
    }
  }

  Future<void> _verify() async {
    final pin = _enteredPin.join();
    final isValid = await SecurityService.verifyPin(pin);

    if (isValid) {
      if (mounted) {
        context.go('/dashboard');
      }
    } else {
      setState(() {
        _enteredPin.clear();
        _errorMessage = 'Incorrect PIN. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                AppStrings.appName,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your 4-digit PIN to access property records',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // PIN Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                ),

              const SizedBox(height: 32),

              // Keypad
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  ...List.generate(9, (index) {
                    final digit = '${index + 1}';
                    return _buildKeypadButton(digit, () => _onDigitPressed(digit));
                  }),
                  const SizedBox.shrink(),
                  _buildKeypadButton('0', () => _onDigitPressed('0')),
                  IconButton(
                    onPressed: _onDeletePressed,
                    icon: const Icon(Icons.backspace_outlined, size: 24),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String digit, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Center(
        child: Text(
          digit,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
