import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_themes.dart';
import '../services/settings_repository.dart';
import '../models/feedback_settings.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  final _repo = SettingsRepository();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _repo.load();
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  void _saveSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved'),
        duration: Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FeedbackSettings>();
    final isDark = settings.theme == AppTheme.kashyap;
    return Scaffold(
      appBar: AppBar(title: const Text('Options')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Themed background
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Image.asset(
                        isDark ? 'assets/Options_Dark.png' : 'assets/Options_Light.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                  // Sound section
                  BwSectionCard(
                    title: 'Sound',
                    child: Column(
                      children: [
                        _SettingTile(
                          key: const Key('soundSwitch'),
                          title: 'Sound effects',
                          value: _repo.soundEnabled,
                          onChanged: (v) {
                            setState(() => _repo.setSound(v));
                            // propagate to app-wide settings
                            context.read<FeedbackSettings>().setSoundEnabled(v);
                            _saveSnack();
                          },
                          iconOn: Icons.volume_up,
                          iconOff: Icons.volume_off_outlined,
                        ),
                        const Divider(height: 0),
                        _SettingTile(
                          key: const Key('hapticsSwitch'),
                          title: 'Haptics',
                          value: _repo.hapticsEnabled,
                          onChanged: (v) {
                            setState(() => _repo.setHaptics(v));
                            // propagate to app-wide settings
                            context.read<FeedbackSettings>().setHapticsEnabled(v);
                            _saveSnack();
                          },
                          iconOn: Icons.vibration,
                          iconOff: Icons.vibration_outlined,
                        ),
                        const Divider(height: 0),
                        _SettingTile.disabled(
                          key: const Key('musicSwitch'),
                          title: 'Music',
                          subtitle: 'Background music',
                          trailingPill: 'Coming soon',
                          iconOn: Icons.music_note,
                          iconOff: Icons.music_off,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Themes section
                  BwSectionCard(
                    title: 'Themes',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ThemeSwatch(
                          key: const Key('swatch_Kashyap'),
                          theme: AppTheme.kashyap,
                          selected: _repo.theme == AppTheme.kashyap,
                          title: 'Kashyap',
                          subtitle: 'Dark and moody',
                          onTap: () {
                            setState(() => _repo.setTheme(AppTheme.kashyap));
                            context.read<FeedbackSettings>().setTheme(AppTheme.kashyap);
                            _saveSnack();
                          },
                        ),
                        const SizedBox(height: 12),
                        _ThemeSwatch(
                          key: const Key('swatch_Hirani'),
                          theme: AppTheme.hirani,
                          selected: _repo.theme == AppTheme.hirani,
                          title: 'Hirani',
                          subtitle: 'Clean light',
                          onTap: () {
                            setState(() => _repo.setTheme(AppTheme.hirani));
                            context.read<FeedbackSettings>().setTheme(AppTheme.hirani);
                            _saveSnack();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Gameplay section
                  BwSectionCard(
                    title: 'Game play',
                    child: Column(
                      children: [
                        _SettingTile(
                          key: const Key('hintsSwitch'),
                          title: 'Hints',
                          subtitle: _repo.hintsEnabled ? 'Each hint costs 15 tickets' : null,
                          value: _repo.hintsEnabled,
                          onChanged: (v) {
                            setState(() => _repo.setHints(v));
                            // propagate to app-wide settings
                            context.read<FeedbackSettings>().setHintsEnabled(v);
                            _saveSnack();
                          },
                          iconOn: Icons.tips_and_updates,
                          iconOff: Icons.tips_and_updates_outlined,
                        ),
                        const Divider(height: 0),
                        _SettingTile.disabled(
                          key: const Key('selectIndustriesDisabled'),
                          title: 'Select movie industries',
                          trailingPill: 'Coming soon',
                          iconOn: Icons.local_movies,
                          iconOff: Icons.local_movies_outlined,
                        ),
                      ],
                    ),
                  ),

                          // Bottom helper text removed per request
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'v1.0 • Copyright 4spire.in',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class BwSectionCard extends StatelessWidget {
  const BwSectionCard({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // ~6% black
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    required this.iconOn,
    required this.iconOff,
  })  : _disabled = false,
        trailingPill = null;

  const _SettingTile.disabled({
    super.key,
    required this.title,
    this.subtitle,
    this.trailingPill,
    required this.iconOn,
    required this.iconOff,
  })  : value = false,
        onChanged = null,
        _disabled = true;

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData iconOn;
  final IconData iconOff;
  final String? trailingPill;
  final bool _disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = Row(
      children: [
        Icon(value ? iconOn : iconOff),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: 0.8,
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        if (_disabled)
          _ComingSoonPill(text: trailingPill ?? 'Coming soon')
        else
          Semantics(
            container: true,
            label: '$title toggle',
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
          ),
      ],
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _disabled ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56, minWidth: 44),
          child: base,
        ),
      ),
    );
  }
}

class _ComingSoonPill extends StatelessWidget {
  const _ComingSoonPill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    super.key,
    required this.theme,
    required this.selected,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  final AppTheme theme;
  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final td = AppThemes.themeData(theme);
    final primary = td.colorScheme.primary; // ignore: unused_local_variable
    final secondary = td.colorScheme.secondary; // ignore: unused_local_variable
    final surface = Theme.of(context).colorScheme.surface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
  child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (subtitle != null)
                          Opacity(
                            opacity: 0.8,
                            child: Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                          ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: selected ? 1 : 0,
                    child: const Icon(Icons.check_circle, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

