import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/mongodb_service.dart';
import '../utils/logger.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _userData = {};
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch user data from MongoDB
      final userData = await MongoDBService.getUserProfile(context);
      if (userData != null) {
        setState(() {
          _userData = userData;
          _nameController.text = userData['name'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _bioController.text = userData['bio'] ?? '';
        });
      }
    } catch (e) {
      AppLogger.info('Error loading user profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile data')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?["_id"];

      if (userId != null) {
        final updatedData = {
          'name': _nameController.text,
          'email': _emailController.text,
          'bio': _bioController.text,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        await MongoDBService.updateUserProfile(userId.toHexString(), updatedData);

        setState(() {
          _userData = {..._userData, ...updatedData};
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      AppLogger.info('Error updating user profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed('/detect');
    } catch (e) {
      AppLogger.info('Error signing out: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to sign out')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _updateUserProfile(); // Wait for the update to finish
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.green,
              child: Text(
                _userData['name']?.isNotEmpty == true
                    ? _userData['name'][0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 48, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileField(
              'Name',
              _nameController,
              Icons.person,
              enabled: _isEditing,
            ),
            const SizedBox(height: 16),
            _buildProfileField(
              'Email',
              _emailController,
              Icons.email,
              enabled: _isEditing,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildProfileField(
              'Bio',
              _bioController,
              Icons.description,
              enabled: _isEditing,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _buildStatisticsSection(),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Sign Out', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(
      String label,
      TextEditingController controller,
      IconData icon, {
        bool enabled = false,
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
      }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.green),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green, width: 2),
        ),
        disabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        filled: true,
        fillColor: Colors.black87,
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildStatisticsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Learning Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatisticRow(
            'Completed Lessons',
            _userData['stats']?['completedLessons']?.toString() ?? '0',
            Icons.check_circle,
          ),
          _buildStatisticRow(
            'Practice Minutes',
            _userData['stats']?['practiceMinutes']?.toString() ?? '0',
            Icons.timer,
          ),
          _buildStatisticRow(
            'Signs Learned',
            _userData['stats']?['signsLearned']?.toString() ?? '0',
            Icons.front_hand,
          ),
          _buildStatisticRow(
            'Accuracy',
            _userData['stats']?['accuracy'] != null
                ? '${_userData['stats']['accuracy']}%'
                : 'N/A',
            Icons.analytics,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}