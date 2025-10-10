// lib/stats_display_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_state.dart';
import 'local_auth_service.dart'; // Ensure this is imported for UserData type

class StatsDisplayButton extends StatelessWidget {
  const StatsDisplayButton({super.key});

  void _showStatsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        // Displays the content which listens to UserState changes
        return const StatsModalContent();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the UserState to determine if the button should be visible
    final userState = Provider.of<UserState>(context);

    // Only show the button if a user is logged in
    if (!userState.isLoggedIn || userState.currentUser == null) {
      return Container();
    }

    return FloatingActionButton(
      heroTag: 'statsButton', 
      onPressed: () => _showStatsModal(context),
      backgroundColor: Colors.blueAccent,
      child: const Icon(Icons.person),
    );
  }
}

// -----------------------------------------------------------
// UPDATED WIDGET: StatsModalContent
// -----------------------------------------------------------
class StatsModalContent extends StatelessWidget {
  const StatsModalContent({super.key});

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  // 🚨 NEW WIDGET: A dedicated, stylized stamina bar with depth
  Widget _buildStaminaBar(BuildContext context, int currentStamina) {
    final progress = currentStamina / 100;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('STAMINA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 5),
        
        // Use a Stack to overlay the text on the bar, adding "depth"
        Stack(
          children: [
            // 1. Background Bar (The full 100 capacity look)
            LinearProgressIndicator(
              value: 1.0, 
              backgroundColor: Colors.grey[800],
              minHeight: 20,
              color: Colors.grey[600], // Background color
            ),
            
            // 2. Current Stamina Fill
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              color: currentStamina > 25 ? Colors.greenAccent[400] : Colors.redAccent,
              minHeight: 20,
            ),
            
            // 3. Overlay Text
            Positioned.fill(
              child: Center(
                child: Text(
                  '$currentStamina / 100',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 5),
        // Regeneration Info
        const Text(
          'Regenerates +10 every 10 seconds.',
          style: TextStyle(fontSize: 10, color: Colors.greenAccent),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to listen to UserState and rebuild ONLY this part
    return Consumer<UserState>(
      builder: (context, userState, child) {
        final user = userState.currentUser;
        
        if (user == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Player Stats',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(),
              
              _buildStatRow('Username:', user.username),
              _buildStatRow('Gender:', user.gender),
              // Money Stat
              _buildStatRow('Money:', '\$${user.money}'), 
              
              const SizedBox(height: 20),
              
              // 🚨 NEW: Use the dedicated, detailed stamina bar
              _buildStaminaBar(context, user.stamina),
              
              const SizedBox(height: 20),
              
              // 🚨 REMOVED: Simulate Stamina Use Button is gone
              
            ],
          ),
        );
      },
    );
  }
}