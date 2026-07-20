import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _masterEnabled = true;
  bool _soundEnabled = true;
  bool _vibrateEnabled = true;
  bool _matchesEnabled = true;
  bool _messagesEnabled = true;
  bool _likesEnabled = true;
  bool _callsEnabled = true;
  bool _liveInvitesEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _masterEnabled = prefs.getBool('notif_master') ?? true;
      _soundEnabled = prefs.getBool('notif_sound') ?? true;
      _vibrateEnabled = prefs.getBool('notif_vibrate') ?? true;
      _matchesEnabled = prefs.getBool('notif_matches') ?? true;
      _messagesEnabled = prefs.getBool('notif_messages') ?? true;
      _likesEnabled = prefs.getBool('notif_likes') ?? true;
      _callsEnabled = prefs.getBool('notif_calls') ?? true;
      _liveInvitesEnabled = prefs.getBool('notif_live_invites') ?? true;
      _loading = false;
    });
  }

  Future<void> _updatePref(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    
    const Color primaryPink = Color(0xFFFF4D85);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.getString('notifications'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryPink))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _buildSectionHeader(languageProvider.currentLanguageCode == 'sw' ? 'MKUU' : 'MASTER CONTROL'),
                _buildSwitchTile(
                  icon: Iconsax.notification_status,
                  title: languageProvider.currentLanguageCode == 'sw' ? 'Ruhusu Arifa' : 'Allow Notifications',
                  subtitle: languageProvider.currentLanguageCode == 'sw' ? 'Washa au zima arifa zote' : 'Enable or disable all notifications',
                  value: _masterEnabled,
                  onChanged: (val) {
                    setState(() => _masterEnabled = val);
                    _updatePref('notif_master', val);
                  },
                  activeThumbColor: primaryPink,
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: _masterEnabled ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: AbsorbPointer(
                    absorbing: !_masterEnabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(languageProvider.currentLanguageCode == 'sw' ? 'ARIZAJI' : 'ALERT PREFERENCES'),
                        _buildSwitchTile(
                          icon: Iconsax.volume_high,
                          title: languageProvider.currentLanguageCode == 'sw' ? 'Sauti ya Arifa' : 'Notification Sound',
                          subtitle: languageProvider.currentLanguageCode == 'sw' ? 'Cheza sauti ya arifa zinazoingia' : 'Play a sound for incoming alerts',
                          value: _soundEnabled,
                          onChanged: (val) {
                            setState(() => _soundEnabled = val);
                            _updatePref('notif_sound', val);
                          },
                          activeThumbColor: primaryPink,
                        ),
                        _buildSwitchTile(
                          icon: Iconsax.repeate_one,
                          title: languageProvider.currentLanguageCode == 'sw' ? 'Tetemeko' : 'Vibrate',
                          subtitle: languageProvider.currentLanguageCode == 'sw' ? 'Tetemeka arifa zinapoingia' : 'Vibrate on notifications',
                          value: _vibrateEnabled,
                          onChanged: (val) {
                            setState(() => _vibrateEnabled = val);
                            _updatePref('notif_vibrate', val);
                          },
                          activeThumbColor: primaryPink,
                        ),
                        const SizedBox(height: 10),
                        _buildSectionHeader(languageProvider.currentLanguageCode == 'sw' ? 'AINA ZA ARIFA' : 'NOTIFICATION TYPES'),
                        _buildSwitchTile(
                          icon: Iconsax.heart,
                          title: languageProvider.currentLanguageCode == 'sw' ? 'Mechi Mpya' : 'New Matches',
                          subtitle: languageProvider.currentLanguageCode == 'sw' ? 'Arifiwa unapopata mechi mpya' : 'Get notified when you get a new match',
                          value: _matchesEnabled,
                          onChanged: (val) {
                            setState(() => _matchesEnabled = val);
                            _updatePref('notif_matches', val);
                          },
                          activeThumbColor: primaryPink,
                        ),
                        _buildSwitchTile(
                          icon: Iconsax.message,
                          title: languageProvider.currentLanguageCode == 'sw' ? 'Ujumbe' : 'Messages',
                          subtitle: languageProvider.currentLanguageCode == 'sw' ? 'Arifiwa unapopokea ujumbe mpya' : 'Get notified for new chat messages',
                          value: _messagesEnabled,
                          onChanged: (val) {
                            setState(() => _messagesEnabled = val);
                            _updatePref('notif_messages', val);
                          },
                          activeThumbColor: primaryPink,
                        ),
                        _buildSwitchTile(
                          icon: Iconsax.like_1,
                          title: languageProvider.currentLanguageCode == 'sw' ? 'Likes' : 'Likes',
                          subtitle: languageProvider.currentLanguageCode == 'sw' ? 'Arifiwa mtu anapopenda wasifu wako' : 'Get notified when someone likes your profile',
                          value: _likesEnabled,
                          onChanged: (val) {
                            setState(() => _likesEnabled = val);
                            _updatePref('notif_likes', val);
                          },
                          activeThumbColor: primaryPink,
                        ),
                        _buildSwitchTile(
                          icon: Iconsax.call,
                          title: languageProvider.currentLanguageCode == 'sw' ? 'Simu' : 'Calls',
                          subtitle: languageProvider.currentLanguageCode == 'sw' ? 'Arifiwa kwa simu za sauti na video' : 'Get notified for voice and video calls',
                          value: _callsEnabled,
                          onChanged: (val) {
                            setState(() => _callsEnabled = val);
                            _updatePref('notif_calls', val);
                          },
                          activeThumbColor: primaryPink,
                        ),
                        _buildSwitchTile(
                          icon: Iconsax.video_play,
                          title: languageProvider.currentLanguageCode == 'sw' ? 'Alika Mubashara' : 'Live Stream Invites',
                          subtitle: languageProvider.currentLanguageCode == 'sw' ? 'Arifiwa unapoalikwa kwenye video ya mubashara' : 'Get notified when invited to co-host live streams',
                          value: _liveInvitesEnabled,
                          onChanged: (val) {
                            setState(() => _liveInvitesEnabled = val);
                            _updatePref('notif_live_invites', val);
                          },
                          activeThumbColor: primaryPink,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12, top: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFF4D85),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeThumbColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:
                Theme.of(context).brightness == Brightness.light ? 0.03 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: activeThumbColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: activeThumbColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 12,
          ),
        ),
        value: value,
        activeThumbColor: activeThumbColor,
        onChanged: onChanged,
      ),
    );
  }
}
