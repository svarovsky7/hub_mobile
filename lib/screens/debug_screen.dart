import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _debugInfo = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    final buffer = StringBuffer();
    
    // Check Supabase configuration
    buffer.writeln('=== Supabase Configuration ===');
    buffer.writeln('URL: ${dotenv.env['SUPABASE_URL']}');
    buffer.writeln('Has Anon Key: ${dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty ?? false}');
    buffer.writeln('Client initialized: true');
    
    // Test database connection
    buffer.writeln('\n=== Database Connection Test ===');
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, email, name, role')
          .limit(1);
      buffer.writeln('Database connection: SUCCESS');
      buffer.writeln('Sample data: $response');
    } catch (e) {
      buffer.writeln('Database connection: FAILED');
      buffer.writeln('Error: $e');
    }
    
    // Test auth
    buffer.writeln('\n=== Auth Status ===');
    final session = Supabase.instance.client.auth.currentSession;
    buffer.writeln('Current session: ${session != null ? 'Active' : 'None'}');
    if (session != null) {
      buffer.writeln('User ID: ${session.user.id}');
      buffer.writeln('User email: ${session.user.email}');
    }
    
    // Test auth with sample credentials
    buffer.writeln('\n=== Auth Test ===');
    buffer.writeln('Ready for manual auth test');
    
    setState(() {
      _debugInfo = buffer.toString();
    });
  }

  Future<void> _testAuth(String email, String password) async {
    setState(() {
      _debugInfo += '\n\nTesting auth with: $email';
    });
    
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      setState(() {
        _debugInfo += '\nAuth SUCCESS: ${response.user?.id}';
      });
    } catch (e) {
      setState(() {
        _debugInfo += '\nAuth FAILED: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Info'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _debugInfo,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _testAuth('test@example.com', 'password123'),
              child: const Text('Test Auth (test@example.com)'),
            ),
          ],
        ),
      ),
    );
  }
}