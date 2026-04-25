import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import '../cache_service.dart';
import 'dashboard_screen.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _regnoController = TextEditingController();
  final _passwdController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _tryAutoLogin();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _regnoController.dispose();
    _passwdController.dispose();
    super.dispose();
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRegno = prefs.getString('regno');
    final savedPasswd = prefs.getString('passwd');
    if (savedRegno == null || savedPasswd == null || savedRegno.isEmpty) return;

    _regnoController.text = savedRegno;
    _passwdController.text = savedPasswd;

    final cached = await CacheService.loadStudentData();
    if (cached != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            studentData: cached,
            regno: savedRegno,
            passwd: savedPasswd,
          ),
        ),
      );
      return;
    }
    _login();
  }

  Future<void> _saveCredentials(String regno, String passwd) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('regno', regno);
    await prefs.setString('passwd', passwd);
  }

  void _login() async {
    final regno = _regnoController.text.trim();
    final passwd = _passwdController.text;
    if (regno.isEmpty || passwd.isEmpty) {
      setState(() => _errorMessage = 'PLEASE ENTER YOUR CREDENTIALS.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ApiService();
      final data = await api.loginAndGetData(regno, passwd);
      await _saveCredentials(regno, passwd);
      await CacheService.saveStudentData(data);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            studentData: data,
            regno: regno,
            passwd: passwd,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '').toUpperCase();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VergeTheme.canvasBlack,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ATTENDA',
                  style: VergeTheme.heroDisplay.copyWith(fontSize: 80),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'SIGN IN TO YOUR STUDENT PORTAL',
                  style: VergeTheme.eyebrowAllCaps.copyWith(color: VergeTheme.secondaryText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: VergeTheme.canvasBlack,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: VergeTheme.hazardWhite, width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        controller: _regnoController,
                        label: 'REGISTER NUMBER / MOBILE',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _passwdController,
                        label: 'PASSWORD',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: VergeTheme.secondaryText,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: VergeTheme.canvasBlack,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(color: VergeTheme.ultraviolet),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: VergeTheme.ultraviolet, size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: VergeTheme.monoTimestamp.copyWith(color: VergeTheme.hazardWhite),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VergeTheme.jellyMint,
                            foregroundColor: VergeTheme.absoluteBlack,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          ),
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: VergeTheme.absoluteBlack,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'SIGN IN',
                                  style: VergeTheme.monoButtonLabel,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: VergeTheme.bodyRelaxed,
      onSubmitted: (_) => _login(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: VergeTheme.eyebrowAllCaps.copyWith(color: VergeTheme.secondaryText),
        prefixIcon: Icon(icon, color: VergeTheme.secondaryText, size: 20),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: VergeTheme.secondaryText),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: VergeTheme.jellyMint),
        ),
        filled: true,
        fillColor: VergeTheme.canvasBlack,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

