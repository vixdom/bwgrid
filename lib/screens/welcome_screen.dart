import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Quick-tweak config
const bool kShowReel = false; // disabled for clean design
const double kGridLineThickness = 2.5; // Increased grid line thickness

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
  debugPrint('[Welcome] build()');
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background photo - full screen
          Positioned.fill(
            child: Image.asset(
              'assets/BollyWord welcome screen gold.png',
              fit: BoxFit.cover,
              alignment: Alignment(0.2, 0.0), // shift image 10% to the right
              width: screenSize.width,
              height: screenSize.height,
              errorBuilder: (context, error, stack) {
                debugPrint('[Welcome] Failed to load background image: $error');
                return const ColoredBox(color: Colors.black);
              },
            ),
          ),

          // Content
          Column(
            children: [
              // Top spacer (where grid used to be)
              SizedBox(
                height: screenSize.height * 0.6,
              ),

              // Buttons area (bottom 40% of screen)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PrimaryButton(
                        label: 'Play',
                        icon: Icons.play_arrow,
                        onTap: () {
                          Navigator.of(context).pushNamed('/game');
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
                      const SizedBox(height: 16),
                      const _AwardsButton(),
                      const SizedBox(height: 24),

                      const Spacer(),
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
  const _PrimaryButton({required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
          backgroundColor: const Color(0xFFF39C12),
          foregroundColor: Colors.black,
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: Color(0xFFF39C12), width: 2),
          foregroundColor: const Color(0xFFF39C12),
          backgroundColor: Colors.black.withOpacity(.25),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}

class _AwardsButton extends StatelessWidget {
  const _AwardsButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          OutlinedButton(
            onPressed: null, // Disabled button
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.5),
              side: BorderSide(color: Colors.white24, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_outlined, size: 20, color: Colors.white54),
                const SizedBox(width: 10),
                Text(
                  'Awards',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 16,
            child: Text(
              'coming soon',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.amber,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}