import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../models/user_profile_model.dart';
import '../services/profile_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isSavingPassword = false;
  bool _isPasswordVisible = false;
  
  // App Lock settings state
  bool _isPinEnabled = false;
  bool _isBiometricEnabled = false;
  String? _savedPin;

  final Color _primaryColor = const Color(0xFFFF4D85);

  @override
  void initState() {
    super.initState();
    _loadAppLockSettings();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAppLockSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPinEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _isBiometricEnabled = prefs.getBool('biometric_lock_enabled') ?? false;
      _savedPin = prefs.getString('app_lock_pin');
    });
  }

  Future<void> _togglePinLock(bool value) async {
    if (value) {
      // User is enabling PIN Lock
      _showPinSetupDialog();
    } else {
      // User is disabling PIN Lock -> require verification first
      _showPinVerificationDialog(onSuccess: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_lock_enabled', false);
        await prefs.remove('app_lock_pin');
        setState(() {
          _isPinEnabled = false;
          _savedPin = null;
        });
        _showSnack('PIN Lock disabled successfully.', isSuccess: true);
      });
    }
  }

  Future<void> _toggleBiometricLock(bool value) async {
    if (value && !_isPinEnabled) {
      _showSnack('Please set a PIN code first before enabling biometrics.', isError: true);
      return;
    }

    if (value) {
      final LocalAuthentication auth = LocalAuthentication();
      try {
        final bool isSupported = await auth.isDeviceSupported();
        final bool canCheckBiometrics = await auth.canCheckBiometrics;
        if (!isSupported || !canCheckBiometrics) {
          _showSnack('Biometric hardware is not supported or configured on this device.', isError: true);
          return;
        }

        final List<BiometricType> availableBiometrics = await auth.getAvailableBiometrics();
        if (availableBiometrics.isEmpty) {
          _showSnack('No fingerprints or Face ID enrolled on this device.', isError: true);
          return;
        }

        // Verify biometrics before enabling
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Verify your biometric signature to enable biometric lock',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );

        if (!didAuthenticate) {
          _showSnack('Biometric authentication failed. Could not enable biometric lock.', isError: true);
          return;
        }
      } catch (e) {
        _showSnack('Biometric error: $e', isError: true);
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_lock_enabled', value);
    setState(() {
      _isBiometricEnabled = value;
    });
    _showSnack(
      value ? 'Biometric verification enabled.' : 'Biometric verification disabled.',
      isSuccess: value,
    );
  }

  // Set up PIN flow
  void _showPinSetupDialog() {
    final List<String> enteredPin = [];
    final List<String> confirmPin = [];
    bool isConfirming = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final title = isConfirming ? 'Confirm your 4-digit PIN' : 'Create a 4-digit PIN';
            final currentLength = isConfirming ? confirmPin.length : enteredPin.length;
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This PIN will secure your access to DateDash.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 40),
                  
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isActive = index < currentLength;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? _primaryColor : Colors.transparent,
                          border: Border.all(
                            color: isActive ? _primaryColor : Theme.of(context).dividerColor,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 48),
                  
                  // PIN Pad Grid
                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        if (index == 9) {
                          // Clear
                          return IconButton(
                            icon: const Icon(Icons.clear_all_rounded, size: 24),
                            onPressed: () {
                              setModalState(() {
                                if (isConfirming) {
                                  confirmPin.clear();
                                } else {
                                  enteredPin.clear();
                                }
                              });
                            },
                          );
                        }
                        if (index == 11) {
                          // Delete
                          return IconButton(
                            icon: const Icon(Icons.backspace_outlined, size: 20),
                            onPressed: () {
                              setModalState(() {
                                if (isConfirming) {
                                  if (confirmPin.isNotEmpty) confirmPin.removeLast();
                                } else {
                                  if (enteredPin.isNotEmpty) enteredPin.removeLast();
                                }
                              });
                            },
                          );
                        }
                        
                        final number = index == 10 ? 0 : index + 1;
                        return InkWell(
                          onTap: () async {
                            setModalState(() {
                              if (isConfirming) {
                                if (confirmPin.length < 4) confirmPin.add(number.toString());
                              } else {
                                if (enteredPin.length < 4) enteredPin.add(number.toString());
                              }
                            });
                            
                            // Check if 4 digits completed
                            if (!isConfirming && enteredPin.length == 4) {
                              // Transition to confirmation state
                              await Future.delayed(const Duration(milliseconds: 250));
                              setModalState(() {
                                isConfirming = true;
                              });
                            } else if (isConfirming && confirmPin.length == 4) {
                              final p1 = enteredPin.join();
                              final p2 = confirmPin.join();
                              
                              if (p1 == p2) {
                                final navigator = Navigator.of(context);
                                // Match! Save it
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('app_lock_enabled', true);
                                await prefs.setString('app_lock_pin', p1);
                                
                                if (!mounted) return;
                                
                                setState(() {
                                  _isPinEnabled = true;
                                  _savedPin = p1;
                                });
                                
                                navigator.pop();
                                _showSnack('App Lock PIN setup successful!', isSuccess: true);
                              } else {
                                // Mismatch
                                isConfirming = false;
                                enteredPin.clear();
                                confirmPin.clear();
                                setModalState(() {});
                                _showSnack('PIN codes do not match. Please try again.', isError: true);
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(50),
                          child: Center(
                            child: Text(
                              number.toString(),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Verify Current PIN
  void _showPinVerificationDialog({required VoidCallback onSuccess}) {
    final List<String> verificationPin = [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Enter current App PIN',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please verify your identity to perform this action.',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 40),
                  
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isActive = index < verificationPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? _primaryColor : Colors.transparent,
                          border: Border.all(
                            color: isActive ? _primaryColor : Theme.of(context).dividerColor,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 48),
                  
                  // Numeric pad
                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        if (index == 9) {
                          return IconButton(
                            icon: const Icon(Icons.clear_all_rounded, size: 24),
                            onPressed: () => setModalState(() => verificationPin.clear()),
                          );
                        }
                        if (index == 11) {
                          return IconButton(
                            icon: const Icon(Icons.backspace_outlined, size: 20),
                            onPressed: () {
                              setModalState(() {
                                if (verificationPin.isNotEmpty) verificationPin.removeLast();
                              });
                            },
                          );
                        }
                        
                        final number = index == 10 ? 0 : index + 1;
                        return InkWell(
                          onTap: () async {
                            setModalState(() {
                              if (verificationPin.length < 4) verificationPin.add(number.toString());
                            });
                            
                            if (verificationPin.length == 4) {
                              final pEntered = verificationPin.join();
                              if (pEntered == _savedPin) {
                                Navigator.pop(context);
                                onSuccess();
                              } else {
                                verificationPin.clear();
                                setModalState(() {});
                                _showSnack('Incorrect PIN code. Please try again.', isError: true);
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(50),
                          child: Center(
                            child: Text(
                              number.toString(),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Update password in Firebase
  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    
    setState(() => _isSavingPassword = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate user for safety
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text.trim(),
        );
        
        await user.reauthenticateWithCredential(cred);
        await user.updatePassword(_newPasswordController.text.trim());
        
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        
        _showSnack('Password updated successfully!', isSuccess: true);
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Failed to update password.', isError: true);
    } catch (e) {
      _showSnack('An unexpected error occurred: $e', isError: true);
    } finally {
      setState(() => _isSavingPassword = false);
    }
  }

  // Blocked Users Drawer/Screen trigger
  void _openBlockedUsersList(ProfileProvider profileProvider, LanguageProvider lp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final blockedList = profileProvider.userProfile?.blockedUsers ?? [];
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lp.getString('blocked_users'),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 	0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${blockedList.length} Blocked',
                          style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Users in this list cannot swipe, message, or view your profile card.',
                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                  ),
                  const Divider(height: 32),
                  
                  // List
                  Expanded(
                    child: blockedList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.shield_cross5, size: 64, color: Theme.of(context).dividerColor),
                                const SizedBox(height: 16),
                                const Text(
                                  'Clean Slate!',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No blocked users. Swipe with safety and fun.',
                                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: blockedList.length,
                            itemBuilder: (context, index) {
                              final blockedUid = blockedList[index];
                              
                              return FutureBuilder<UserProfile?>(
                                future: ProfileService().getUserProfile(blockedUid),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: LinearProgressIndicator(),
                                    );
                                  }
                                  
                                  final user = snapshot.data;
                                  final name = user?.firstName ?? 'Datedash User';
                                  final photo = user?.photos.isNotEmpty == true ? user!.photos.first : '';
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: Colors.grey.shade200,
                                          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                          child: photo.isEmpty ? const Icon(Icons.person) : null,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'ID: ...${blockedUid.substring(blockedUid.length - 6)}',
                                                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            // Unblock user
                                            final currentProfile = profileProvider.userProfile;
                                            if (currentProfile != null && profileProvider.currentUser != null) {
                                              currentProfile.blockedUsers.remove(blockedUid);
                                              await profileProvider.saveUserProfile(
                                                profileProvider.currentUser!.uid,
                                                currentProfile,
                                              );
                                              
                                              setModalState(() {});
                                              _showSnack('Unblocked $name successfully.', isSuccess: true);
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primaryColor.withValues(alpha: 	0.1),
                                            foregroundColor: _primaryColor,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: const Text(
                                            'Unblock',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : (isSuccess ? Icons.check_circle_outline : Icons.info_outline),
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : (isSuccess ? Colors.green : Colors.black87),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.getString('security'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // 🛡️ Passcode & Biometrics App Lock Section
          _buildSectionHeader('App Lock Security'),
          
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _isPinEnabled,
                  onChanged: _togglePinLock,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 	0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.key5, color: Colors.blue, size: 20),
                  ),
                  title: const Text('Lock App with PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Require a 4-digit PIN code on launch', style: TextStyle(fontSize: 11)),
                  activeThumbColor: _primaryColor,
                ),
                if (_isPinEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 	0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Iconsax.edit5, color: Colors.purple, size: 20),
                    ),
                    title: const Text('Change Access PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: const Icon(Iconsax.arrow_right_3, size: 16),
                    onTap: () {
                      _showPinVerificationDialog(onSuccess: () {
                        _showPinSetupDialog();
                      });
                    },
                  ),
                ],
                const Divider(height: 1),
                SwitchListTile(
                  value: _isBiometricEnabled,
                  onChanged: _toggleBiometricLock,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 	0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.finger_scan5, color: Colors.green, size: 20),
                  ),
                  title: const Text('Lock App with Biometrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Use fingerprint or face recognition', style: TextStyle(fontSize: 11)),
                  activeThumbColor: _primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 🚫 Blocked Users Section
          _buildSectionHeader('Social Boundaries'),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 	0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.shield_cross5, color: Colors.orange, size: 20),
              ),
              title: Text(languageProvider.getString('blocked_users'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Manage your limits and blocked profiles', style: TextStyle(fontSize: 11)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 	0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${profileProvider.userProfile?.blockedUsers.length ?? 0} total',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              onTap: () => _openBlockedUsersList(profileProvider, languageProvider),
            ),
          ),
          const SizedBox(height: 24),

          // 🔑 Password Management Form
          _buildSectionHeader('Update Security Credentials'),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Change Password',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ensure your account uses a secure password to prevent unauthorized login.',
                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11, height: 1.4),
                  ),
                  const Divider(height: 24),
                  
                  // Current Password
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: !_isPasswordVisible,
                    validator: (val) => val == null || val.isEmpty ? 'Please enter current password' : null,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Iconsax.lock, size: 18),
                      labelText: 'Current Password',
                      labelStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // New Password
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: !_isPasswordVisible,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Please enter new password';
                      if (val.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Iconsax.key, size: 18),
                      labelText: 'New Password',
                      labelStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Confirm Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isPasswordVisible,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Please confirm new password';
                      if (val != _newPasswordController.text) return 'Passwords do not match';
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Iconsax.verify, size: 18),
                      labelText: 'Confirm New Password',
                      labelStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                        icon: Icon(_isPasswordVisible ? Iconsax.eye_slash : Iconsax.eye, size: 16, color: _primaryColor),
                        label: Text(_isPasswordVisible ? 'Hide' : 'Show', style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      
                      ElevatedButton(
                        onPressed: _isSavingPassword ? null : _updatePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isSavingPassword
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  
                  const Divider(height: 32),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final email = FirebaseAuth.instance.currentUser?.email;
                        if (email != null) {
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                          _showSnack('Password reset email sent to $email.', isSuccess: true);
                        } else {
                          _showSnack('No registered email address found.', isError: true);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _primaryColor),
                        foregroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Iconsax.direct_send, size: 16),
                      label: const Text('Send Password Reset Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFF4D85),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
