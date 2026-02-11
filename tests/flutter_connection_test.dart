// ============================================================================
// DeConnect — Flutter Connection Smoke Test
// ============================================================================
// Copy this into a test file or your main.dart temporarily to verify
// the connection between Flutter and local Supabase works.
//
// Prerequisites:
//   1. supabase start (running)
//   2. supabase db reset (migrations applied)
//   3. Flutter app configured with local URL + anon key
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> testConnection() async {
  final supabase = Supabase.instance.client;

  print('--- DeConnect Connection Test ---\n');

  // Test 1: Can we reach the API?
  try {
    final response = await supabase.from('profiles').select('id').limit(1);
    print('✅ Test 1: API connection OK');
  } catch (e) {
    print('❌ Test 1: API connection failed: $e');
  }

  // Test 2: Can we call an RPC function?
  try {
    final result = await supabase.rpc('generate_invite_code');
    print('✅ Test 2: RPC works, got invite code: $result');
  } catch (e) {
    print('❌ Test 2: RPC failed: $e');
  }

  // Test 3: Auth signup test
  try {
    final auth = await supabase.auth.signUp(
      email: 'test_${DateTime.now().millisecondsSinceEpoch}@test.com',
      password: 'testpassword123',
    );
    if (auth.user != null) {
      print('✅ Test 3: Auth signup OK, user ID: ${auth.user!.id}');

      // Test 4: Profile auto-created by trigger?
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', auth.user!.id)
          .maybeSingle();

      if (profile != null) {
        print('✅ Test 4: Profile auto-created by trigger');
      } else {
        print('❌ Test 4: Profile NOT auto-created (check handle_new_user trigger)');
      }

      // Test 5: Create a group chat
      try {
        final group = await supabase.rpc('create_group_chat', params: {
          'p_name': 'Test Group ${DateTime.now().millisecondsSinceEpoch}',
          'p_description': 'Smoke test group',
        });
        print('✅ Test 5: Group created: $group');
      } catch (e) {
        print('❌ Test 5: Group creation failed: $e');
      }

      // Cleanup: sign out
      await supabase.auth.signOut();
    }
  } catch (e) {
    print('❌ Test 3: Auth signup failed: $e');
  }

  print('\n--- Tests Complete ---');
}
