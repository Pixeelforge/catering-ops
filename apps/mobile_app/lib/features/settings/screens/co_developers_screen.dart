import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CoDevelopersScreen extends StatefulWidget {
  const CoDevelopersScreen({super.key});

  @override
  State<CoDevelopersScreen> createState() => _CoDevelopersScreenState();
}

class _CoDevelopersScreenState extends State<CoDevelopersScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // Slate 900
              Color(0xFF1E1B4B), // Indigo 950
              Color(0xFF312E81), // Indigo 900
            ],
          ),
        ),
        child: Stack(
          children: [
            // Top Accent Glow
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withOpacity(0.05),
                ),
              ),
            ),
            
            SafeArea(
              child: Column(
                children: [
                  // Custom AppBar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Co-developers',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Column(
                        children: [
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                const Text(
                                  'THE TEAM BEHIND THE SCENES',
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Meet Our Partners',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: 40,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 80),
                          
                          // Side-by-Side Layout
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Vivek Sani
                                Expanded(
                                  child: _ColDevProfile(
                                    name: 'Vivek Sani',
                                    imagePath: 'assets/images/vivek.png',
                                    role: 'Dev Intern',
                                    slogan: 'Professional bug bounty hunter (for our own bugs).',
                                    githubUrl: 'https://github.com/viveksani',
                                    glowColor: Colors.blueAccent,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // Santosh
                                Expanded(
                                  child: _ColDevProfile(
                                    name: 'Santosh',
                                    imagePath: 'assets/images/santosh.png',
                                    role: 'Junior Dev',
                                    slogan: 'I write code that my future self hates. But I will fix it later.',
                                    githubUrl: 'https://github.com/Yyywhhehhshh',
                                    glowColor: Colors.indigoAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
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

class _ColDevProfile extends StatelessWidget {
  final String name;
  final String imagePath;
  final String role;
  final String slogan;
  final String githubUrl;
  final Color glowColor;

  const _ColDevProfile({
    required this.name,
    required this.imagePath,
    required this.role,
    required this.slogan,
    required this.githubUrl,
    required this.glowColor,
  });

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(githubUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Image at the Top
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.3),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.white.withOpacity(0.05),
                child: const Icon(Icons.person, color: Colors.white24, size: 40),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Name Under Image
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          role.toUpperCase(),
          style: TextStyle(
            color: glowColor.withOpacity(0.8),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        // Slogan
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            slogan,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // GitHub Link
        IconButton(
          onPressed: _launchUrl,
          icon: Icon(
            Icons.link,
            color: Colors.blueAccent.shade100,
            size: 20,
          ),
          tooltip: 'GitHub',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
