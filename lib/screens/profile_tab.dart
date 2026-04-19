import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _location;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _location = TextEditingController();
    _name.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final s = AppStateScope.of(context);
    _name.text = s.profileName;
    _email.text = s.profileEmail;
    _phone.text = s.profilePhone;
    _location.text = s.profileLocation;
    _loaded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = AppStateScope.of(context);

    final isDark = state.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l.profile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(
                      (_name.text.trim().isEmpty ? 'U' : _name.text.trim()[0]).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name.text.trim().isEmpty ? l.name : _name.text.trim(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.personalDetails,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.personalDetails, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(labelText: l.name),
                    textInputAction: TextInputAction.next,
                    onChanged: (v) => state.updateProfile(name: v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    decoration: InputDecoration(labelText: l.email),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onChanged: (v) => state.updateProfile(email: v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phone,
                    decoration: InputDecoration(labelText: l.phone),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    onChanged: (v) => state.updateProfile(phone: v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _location,
                    decoration: InputDecoration(labelText: l.location),
                    textInputAction: TextInputAction.done,
                    onChanged: (v) => state.updateProfile(location: v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l.darkTheme),
                  value: isDark,
                  onChanged: (v) => state.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l.language),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.locale.languageCode,
                      items: [
                        DropdownMenuItem(value: 'en', child: Text(l.english)),
                        DropdownMenuItem(value: 'hi', child: Text(l.hindi)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        state.setLocale(Locale(v));
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: Text(l.rebuildIndex),
                  subtitle: Text(l.rebuildIndexHint),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: Text(l.rebuildTitle),
                          content: Text(l.rebuildBody),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(l.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(l.rebuild),
                            ),
                          ],
                        );
                      },
                    );

                    if (ok != true) return;
                    await state.rebuildIndex();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.indexRebuilt)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
