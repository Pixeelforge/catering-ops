import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.asset('assets/splash.mp4');

    try {
      await _controller.initialize();
      await _controller.setVolume(0.0); // Required for web autoplay
      if (mounted) {
        setState(() {});
        _controller.play();
      }
    } catch (e) {
      debugPrint("Video initialization error: $e");
      setState(() => _error = true);
      // If video fails, wait 2 seconds then navigate
      Future.delayed(const Duration(seconds: 2), _handleNavigation);
      return;
    }

    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (_controller.value.isInitialized &&
        _controller.value.duration > Duration.zero &&
        _controller.value.position >= _controller.value.duration) {
      _controller.removeListener(_videoListener);
      _handleNavigation();
    }
  }

  Future<void> _handleNavigation() async {
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Match login theme
      body: Center(
        child: _error
            ? const Icon(
                Icons.restaurant_menu,
                size: 100,
                color: Colors.orangeAccent,
              )
            : _controller.value.isInitialized
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            : const CircularProgressIndicator(color: Colors.orangeAccent),
      ),
    );
  }
}
