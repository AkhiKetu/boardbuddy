import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/board_invitation_service.dart';

class BoardInvitationsScreen extends StatefulWidget {
  const BoardInvitationsScreen({super.key});

  @override
  State<BoardInvitationsScreen> createState() => _BoardInvitationsScreenState();
}

class _BoardInvitationsScreenState extends State<BoardInvitationsScreen> {
  final BoardInvitationService _service = BoardInvitationService();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<BoardInvitation>>? _invitationsStream;

  bool _emailVerified = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _emailVerified = _auth.currentUser?.emailVerified ?? false;

    if (_emailVerified) {
      _invitationsStream = _service.watchInvitations();
    }
  }

  // Show a message to the user.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // =====================================
  // SEND VERIFICATION EMAIL
  // =====================================

  Future<void> _sendVerificationEmail() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await _service.sendVerificationEmail();

      _showMessage('Verification email sent. Check your inbox.');
    } catch (error) {
      debugPrint('Email verification error: $error');

      _showMessage('Unable to send verification email. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // =====================================
  // CHECK EMAIL VERIFICATION
  // =====================================

  Future<void> _checkVerification() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final verified = await _service.refreshEmailVerification();

      if (!mounted) return;

      setState(() {
        _emailVerified = verified;

        if (verified) {
          _invitationsStream = _service.watchInvitations();
        }
      });

      _showMessage(
        verified
            ? 'Email verified successfully.'
            : 'Email not verified yet. Check your inbox.',
      );
    } catch (error) {
      debugPrint('Verification check error: $error');

      _showMessage('Unable to check verification.');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // =====================================
  // ACCEPT INVITATION
  // =====================================

  Future<void> _acceptInvitation(BoardInvitation invitation) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await _service.acceptInvitation(invitation);

      _showMessage('You joined "${invitation.boardTitle}"!');
    } catch (error) {
      debugPrint('Accept invitation error: $error');

      _showMessage(
        'Unable to accept invitation. '
        'It may no longer be available.',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // =====================================
  // DECLINE INVITATION
  // =====================================

  Future<void> _declineInvitation(BoardInvitation invitation) async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Decline Invitation?'),
          content: Text(
            'Decline the invitation to '
            '"${invitation.boardTitle}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || _isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _service.declineInvitation(invitation);

      _showMessage('Invitation declined.');
    } catch (error) {
      debugPrint('Decline invitation error: $error');

      _showMessage('Unable to decline invitation.');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // =====================================
  // EMAIL VERIFICATION UI
  // =====================================

  Widget _buildVerificationScreen() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 30),

        Icon(
          Icons.mark_email_unread_outlined,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),

        const SizedBox(height: 24),

        const Text(
          'Verify Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        const Text(
          'Verify your email address before accepting '
          'board invitations.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 16),

        Text(
          _auth.currentUser?.email ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 30),

        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _sendVerificationEmail,
          icon: const Icon(Icons.email_outlined),
          label: const Text('Send Verification Email'),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: _isProcessing ? null : _checkVerification,
          icon: const Icon(Icons.refresh),
          label: const Text("I've Verified My Email"),
        ),

        const SizedBox(height: 16),

        const Text(
          'Check your inbox and spam folder for the '
          'verification link.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  // =====================================
  // INVITATION CARD
  // =====================================

  Widget _buildInvitationCard(BoardInvitation invitation) {
    final createdAt = invitation.createdAt;

    final dateText = createdAt == null
        ? 'Just now'
        : MaterialLocalizations.of(context)
              .formatMediumDate(createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 14),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,

                  child: const Icon(Icons.dashboard_outlined),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.boardTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Text(
                        'Board Invitation',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Text(
              'You have been invited to collaborate '
              'on this board.',
            ),

            const SizedBox(height: 8),

            Text(
              'Received: $dateText',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _declineInvitation(invitation),
                    child: const Text('Decline'),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _acceptInvitation(invitation),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =====================================
  // INVITATIONS LIST
  // =====================================

  Widget _buildInvitations() {
    return StreamBuilder<List<BoardInvitation>>(
      stream: _invitationsStream,

      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Unable to load invitations. '
                'Check your connection and permissions.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final invitations = snapshot.data ?? [];

        if (invitations.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),

                SizedBox(height: 16),

                Text(
                  'No Invitations',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                SizedBox(height: 8),

                Text(
                  'Your board invitations will appear here.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${invitations.length} Pending Invitation(s)',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            ...invitations.map(_buildInvitationCard),
          ],
        );
      },
    );
  }

  // =====================================
  // MAIN SCREEN
  // =====================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Board Invitations')),

      body: Column(
        children: [
          if (_isProcessing) const LinearProgressIndicator(),

          Expanded(
            child: _emailVerified
                ? _buildInvitations()
                : _buildVerificationScreen(),
          ),
        ],
      ),
    );
  }
}
