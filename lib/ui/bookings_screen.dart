import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import '../services/firebase_service.dart';

class BookingsScreen extends StatefulWidget {
  final String? userId;
  final List<Map<String, dynamic>> localBookings;

  const BookingsScreen({
    super.key,
    this.userId,
    required this.localBookings,
  });

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _allBookings = [];
  late AnimationController _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _loadBookings();
  }

  @override
  void dispose() {
    _bgAnimation.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> remote = [];
    if (widget.userId != null) {
      remote = await _firebaseService.fetchBookings(widget.userId!);
    }

    // Merge remote and local bookings (avoiding duplicates by bookingId)
    final Set<String> ids = {};
    final List<Map<String, dynamic>> merged = [];

    for (var b in widget.localBookings) {
      final id = b['bookingId'] as String;
      if (!ids.contains(id)) {
        ids.add(id);
        merged.add(b);
      }
    }

    for (var b in remote) {
      final id = b['bookingId'] as String;
      if (!ids.contains(id)) {
        ids.add(id);
        merged.add(b);
      }
    }

    // Sort by timestamp (newest first)
    merged.sort((a, b) {
      final aTime = _getDateTime(a['timestamp']);
      final bTime = _getDateTime(b['timestamp']);
      return bTime.compareTo(aTime);
    });

    setState(() {
      _allBookings = merged;
      _isLoading = false;
    });
  }

  DateTime _getDateTime(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Stack(
        children: [
          // Elegant Mesh Gradient Background
          AnimatedBuilder(
            animation: _bgAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -100 + (_bgAnimation.value * 50),
                    left: -50,
                    child: _buildGlowOrb(const Color(0xFF6366F1), 300),
                  ),
                  Positioned(
                    bottom: -50,
                    right: -100 + (_bgAnimation.value * 30),
                    child: _buildGlowOrb(const Color(0xFFEC4899), 350),
                  ),
                  Positioned(
                    top: 200,
                    right: 100 - (_bgAnimation.value * 80),
                    child: _buildGlowOrb(const Color(0xFF8B5CF6), 250),
                  ),
                ],
              );
            },
          ),

          // Blur overlay
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6366F1),
                          ),
                        )
                      : _allBookings.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadBookings,
                              color: const Color(0xFF6366F1),
                              backgroundColor: const Color(0xFF16161A),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: _allBookings.length,
                                itemBuilder: (context, index) {
                                  return _buildBookingCard(_allBookings[index]);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'My Bookings',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              color: Colors.white30,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Bookings Yet',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Your scheduled services will show up here. Go ahead and find a worker to start booking!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final worker = booking['worker'] as Map<String, dynamic>? ?? {};
    final quote = booking['quote'] as Map<String, dynamic>? ?? {};
    final bookingId = booking['bookingId'] as String? ?? 'N/A';
    final day = booking['day'] as String? ?? 'Today';
    final time = booking['time'] as String? ?? 'Anytime';
    final phone = booking['phone'] as String? ?? '';
    final name = worker['name'] as String? ?? 'Worker';
    final occupation = worker['occupation'] as String? ?? 'Professional';
    final location = worker['location'] as String? ?? 'Karachi';
    final rate = worker['hourlyRate'] as num? ?? 0.0;
    final total = quote['total'] as num? ?? 0.0;

    final timestamp = _getDateTime(booking['timestamp']);
    final timeAgo = _formatTimeAgo(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white.withValues(alpha: 0.02),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10B981), // Green dot
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CONFIRMED',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    timeAgo,
                    style: GoogleFonts.inter(
                      color: Colors.white30,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ID and job
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        bookingId,
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Hourly: Rs.${rate.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Worker details
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://i.pravatar.cc/150?u=$name$phone',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.white10,
                            child: const Icon(Icons.person, color: Colors.white38),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              occupation,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF6366F1),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 16),

                  // Appointment Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDetailItem(Icons.calendar_today, 'Date', day),
                      _buildDetailItem(Icons.access_time, 'Slot', time),
                      _buildDetailItem(Icons.location_on, 'Area', location),
                    ],
                  ),

                  const SizedBox(height: 16),
                  if (phone.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.white30, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          'Contact: $phone',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Price
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Est. Amount',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Rs. ${total.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white30, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
