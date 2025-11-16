import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:glassmorphism/glassmorphism.dart';

import 'game_screen.dart' as game;
import '../services/cheat_service.dart';

// Quick-tweak config
const bool kShowReel = false; // disabled for clean design
const double kGridLineThickness = 2.5; // Increased grid line thickness

const _shareMessage = '''Hey! You've got to try this game - BollyWord Grid! 🎬
It's a super fun Bollywood word search where you find hidden stars, movies, and songs in the grid. I'm hooked already - see if you can beat my score 😏

👉 https://onelink.to/xxmddz''';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('[Welcome] build()');
    final screenSize = MediaQuery.of(context).size;
    final topSpacing = (screenSize.height * 0.6) - 140;
    final adjustedTopSpacing = topSpacing > 0 ? topSpacing : 0.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/BollyWord welcome screen gold.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.2, 0.0),
              width: screenSize.width,
              height: screenSize.height,
              errorBuilder: (context, error, stack) {
                debugPrint('[Welcome] Failed to load background image: $error');
                return const ColoredBox(color: Colors.black);
              },
            ),
          ),
          Column(
            children: [
              SizedBox(height: adjustedTopSpacing),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PrimaryButton(
                        label: 'Play now',
                        icon: Icons.play_arrow,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const game.GameScreen(
                                forceShowProgressPath: true,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _SecondaryButton(
                        label: 'Daily Challenge',
                        icon: Icons.flash_on,
                        showComingSoon: true,
                        onDisabledTap: () {
                          // Register a tap towards the cheat sequence
                          CheatService.instance.registerDailyTap(context);
                        },
                      ),
                      const SizedBox(height: 16),
                      _SecondaryButton(
                        label: 'Options',
                        icon: Icons.settings,
                        onTap: () {
                          Navigator.of(context).pushNamed('/options');
                        },
                      ),
                      const SizedBox(height: 28),
                      const _AwardsShareRow(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFD700),
                Color(0xFFDAA520),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.black,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.showComingSoon = false,
    this.onDisabledTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool showComingSoon;
  final VoidCallback? onDisabledTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);
    final bool isDisabled = onTap == null;

    return SizedBox(
      width: double.infinity,
      height: showComingSoon ? 62 : 62,
      child: Material(
        borderRadius: borderRadius,
        color: Colors.transparent,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap ?? onDisabledTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2E2010).withValues(alpha: 0.7),
                  const Color(0xFF1A1207).withValues(alpha: 0.7),
                ],
              ),
              border: Border.all(
                color: isDisabled
                    ? const Color(0x66F3C768)
                    : const Color(0xFFF3C768),
                width: 1.8,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x55FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                        stops: [0.0, 0.65],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            color: isDisabled
                                ? const Color(0x66F8E6B0)
                                : const Color(0xFFF8E6B0),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            label,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isDisabled
                                  ? const Color(0x66F8E6B0)
                                  : const Color(0xFFF8E6B0),
                            ),
                          ),
                        ],
                      ),
                      if (showComingSoon)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'coming soon',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFFF3C768).withValues(alpha: 0.6),
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
}

class _AwardsShareRow extends StatelessWidget {
  const _AwardsShareRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _IconLabelButton(
          icon: Icons.emoji_events_outlined,
          label: 'Awards',
          showComingSoon: true,
        ),
        SizedBox(width: 16),
        _IconLabelButton(
          icon: Icons.share,
          label: 'Share with friends',
          onTapShare: true,
        ),
      ],
    );
  }
}

class _IconLabelButton extends StatelessWidget {
  const _IconLabelButton({
    required this.icon,
    required this.label,
    this.onTapShare = false,
    this.showComingSoon = false,
  });

  final IconData icon;
  final String label;
  final bool onTapShare;
  final bool showComingSoon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapShare ? () => Share.share(_shareMessage.trim()) : null,
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GlassmorphicContainer(
              width: 70,
              height: 70,
              borderRadius: 35,
              blur: 12,
              alignment: Alignment.center,
              border: 1.2,
              linearGradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF3D2A11).withValues(alpha: 0.5),
                  const Color(0xFF1F1408).withValues(alpha: 0.7),
                ],
              ),
              borderGradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (showComingSoon) ...[
              const SizedBox(height: 2),
              Text(
                'coming soon',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFFF3C768),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
