import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/firebase_service.dart';
import '../services/antigravity_engine.dart';
import '../models/worker.dart';
import 'bookings_screen.dart';

enum AppState { idle, confirmingQuote, booked }

enum MessageRole { user, ai, system }

enum MessageType { text, workerCard, quoteCard, timePicker, confirmButtons }

class ChatMessage {
  final MessageRole role;
  final MessageType type;
  final String? text;
  final Worker? worker;
  final Map<String, dynamic>? quote;
  final bool isError;
  final bool isSuccess;

  ChatMessage({
    required this.role,
    this.type = MessageType.text,
    this.text,
    this.worker,
    this.quote,
    this.isError = false,
    this.isSuccess = false,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AntigravityEngine _engine = AntigravityEngine();

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  late AnimationController _bgAnimation;

  final List<ChatMessage> _messages = [
    ChatMessage(
      role: MessageRole.ai,
      text:
          'Assalam o Alaikum! Main Kaarigar AI hoon. Main aapko Karachi mein koi bhi skilled worker dhondhne mein madad kar sakta hoon.\n\nAap konsi service chahte hain?',
    ),
  ];

  bool _isProcessing = false;
  AppState _currentState = AppState.idle;
  Worker? _pendingWorker;
  Map<String, dynamic>? _pendingQuote;
  final Map<String, dynamic> _activeMemory = {};
  List<Worker> _matchedWorkers = [];
  String? _loggedInUser;
  String _detectedLanguage = 'english'; // 'english', 'roman_urdu'

  final FirebaseService _firebaseService = FirebaseService();
  fb.User? _currentUser;
  List<Map<String, dynamic>> _chatSessions = [];
  final List<Map<String, dynamic>> _localBookings = [];

  @override
  void initState() {
    super.initState();
    _bgAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _initSpeech();
    _initAuth();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _initAuth() {
    _firebaseService.authStateChanges.listen((user) {
      setState(() {
        _currentUser = user;
      });
      if (user != null) {
        _loadChatHistory(user.uid);
      }
    });
  }

  void _loadChatHistory(String uid) async {
    setState(() => _isProcessing = true);
    final history = await _firebaseService.fetchChatHistory(uid);
    final profile = await _firebaseService.fetchUserProfile(uid);
    final sessions = await _firebaseService.fetchSessionSummaries(uid);
    setState(() {
      _isProcessing = false;
      if (profile != null) {
        _loggedInUser = profile['name'] ?? profile['email'] ?? 'User';
      }
      _chatSessions = sessions;
      if (history.isNotEmpty) {
        _messages.clear();
        for (var msg in history) {
          final roleStr = msg['role'];
          final role = roleStr == 'user'
              ? MessageRole.user
              : roleStr == 'ai'
              ? MessageRole.ai
              : MessageRole.system;

          final typeStr = msg['type'];
          final type = typeStr == 'workerCard'
              ? MessageType.workerCard
              : typeStr == 'quoteCard'
              ? MessageType.quoteCard
              : MessageType.text;

          Worker? worker;
          if (msg['worker'] != null) {
            worker = Worker.fromMap(Map<String, dynamic>.from(msg['worker']));
          }

          _messages.add(
            ChatMessage(
              role: role,
              type: type,
              text: msg['text'],
              worker: worker,
              quote: msg['quote'] != null
                  ? Map<String, dynamic>.from(msg['quote'])
                  : null,
              isError: msg['isError'] ?? false,
              isSuccess: msg['isSuccess'] ?? false,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _bgAnimation.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addText(
    String text, {
    MessageRole role = MessageRole.system,
    bool isError = false,
    bool isSuccess = false,
  }) {
    setState(() {
      _messages.add(
        ChatMessage(
          role: role,
          text: text,
          isError: isError,
          isSuccess: isSuccess,
        ),
      );
    });
    _scrollToBottom();
    if (_currentUser != null) {
      _firebaseService.saveMessage(
        _currentUser!.uid,
        role: role.name,
        type: MessageType.text.name,
        text: text,
        isError: isError,
        isSuccess: isSuccess,
      );
    }
  }

  void _addWorkerCard(Worker worker) {
    setState(
      () => _messages.add(
        ChatMessage(
          role: MessageRole.ai,
          type: MessageType.workerCard,
          worker: worker,
        ),
      ),
    );
    _scrollToBottom();
    if (_currentUser != null) {
      _firebaseService.saveMessage(
        _currentUser!.uid,
        role: MessageRole.ai.name,
        type: MessageType.workerCard.name,
        worker: worker.toMap(),
      );
    }
  }

  void _addQuoteCard(Map<String, dynamic> quote) {
    setState(
      () => _messages.add(
        ChatMessage(
          role: MessageRole.ai,
          type: MessageType.quoteCard,
          quote: quote,
        ),
      ),
    );
    _scrollToBottom();
    if (_currentUser != null) {
      _firebaseService.saveMessage(
        _currentUser!.uid,
        role: MessageRole.ai.name,
        type: MessageType.quoteCard.name,
        quote: quote,
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _showNextWorker() {
    _pendingWorker = _matchedWorkers.removeAt(0);
    bool isAdjacent =
        _pendingWorker!.location.toLowerCase() !=
        _activeMemory['location']!.toLowerCase();

    if (isAdjacent) {
      _addText(
        "I couldn't find an exact match in ${_activeMemory['location']}, but I found ${_pendingWorker!.name} nearby in ${_pendingWorker!.location}.",
        role: MessageRole.ai,
      );
    } else {
      _addText(
        "I found ${_pendingWorker!.name} available right now in ${_pendingWorker!.location}.",
        role: MessageRole.ai,
      );
    }

    _addWorkerCard(_pendingWorker!);

    final day = _activeMemory['day'] ?? 'Today';
    _pendingQuote = _engine.generateQuote(_pendingWorker!, day);

    _addQuoteCard(_pendingQuote!);

    _addText(
      _ru(
        'Kya aap booking proceed karna chahte hain?',
        'Would you like to proceed and book ${_pendingWorker!.name}?',
      ),
      role: MessageRole.ai,
    );
    setState(() {
      _currentState = AppState.confirmingQuote;
      _messages.add(
        ChatMessage(
          role: MessageRole.ai,
          type: MessageType.confirmButtons,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _processRequest() async {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    _promptController.clear();
    _addText(text, role: MessageRole.user);

    if (_currentState == AppState.confirmingQuote) {
      final t = text.toLowerCase();
      
      // Attempt to extract a Pakistani standard phone number
      final phoneRegex = RegExp(r'(?:\+92|0|92)[3]\d{2}[\s\-]?\d{7}');
      final phoneMatch = phoneRegex.firstMatch(text);
      
      if (phoneMatch != null) {
        _activeMemory['phone'] = phoneMatch.group(0);
      }

      if (_activeMemory['has_accepted'] == true && _activeMemory['phone'] == null) {
        _addText(
          _ru(
            'Yeh phone number sahi nahi lag raha. Barae meharbani Pakistani number darj karein (jaise 03001234567).',
            'This phone number seems invalid. Please enter a standard Pakistani phone number (e.g. 03001234567).',
          ),
          role: MessageRole.ai,
        );
        return;
      }

      final isAccepting = _activeMemory['has_accepted'] == true || [
        'yes', 'y', 'haan', 'ok', 'okay', 'sure', 'theek', 'theek hai', 'done', 'accept', 'ji', 'jee', 'alright',
      ].contains(t);

      if (isAccepting) {
        _activeMemory['has_accepted'] = true;

        if (_activeMemory['phone'] == null) {
          _addText(
            _ru(
              'Aapka booking secure karne ke liye, apna phone number (jaise 03001234567) batayein.',
              'To secure your booking with ${_pendingWorker!.name}, please enter your phone number (e.g. 03001234567).',
            ),
            role: MessageRole.ai,
          );
          return;
        }

        if (phoneMatch != null) {
          _addText(
            _ru('Phone number save ho gaya.', 'Phone number saved.'),
            role: MessageRole.system,
          );
        }

        _addText(
          _ru('Booking secure ho rahi hai...', 'Securing booking...'),
          role: MessageRole.system,
        );
        setState(() => _isProcessing = true);
        await Future.delayed(const Duration(seconds: 1));
        setState(() => _isProcessing = false);

        final bookingId =
            '#KAI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        _addText(
          'Booking Confirmed! $bookingId',
          role: MessageRole.system,
          isSuccess: true,
        );

        final bookingData = {
          'bookingId': bookingId,
          'worker': _pendingWorker!.toMap(),
          'quote': _pendingQuote!,
          'day': _activeMemory['day'] ?? 'Today',
          'time': _activeMemory['time'] ?? 'Anytime',
          'phone': _activeMemory['phone'] ?? '',
          'timestamp': DateTime.now(),
        };
        _localBookings.add(bookingData);
        if (_currentUser != null) {
          _firebaseService.saveBooking(
            _currentUser!.uid,
            bookingId: bookingId,
            worker: _pendingWorker!.toMap(),
            quote: _pendingQuote!,
            day: _activeMemory['day'] ?? 'Today',
            time: _activeMemory['time'] ?? 'Anytime',
            phone: _activeMemory['phone'] ?? '',
          );
        }

        final etaMsg = _calculateEtaMessage();
        _addText(etaMsg, role: MessageRole.ai);

        setState(() {
          _currentState = AppState.idle;
          _pendingWorker = null;
          _pendingQuote = null;
          _activeMemory.clear();
          _matchedWorkers.clear();
        });
      } else if (t.contains('cancel') ||
          t.contains('cancle') ||
          t.contains('stop') ||
          t.contains('khatam') ||
          t.contains('nahi chahiye')) {
        _addText(
          _ru(
            'Theek hai, process cancel kar diya gaya.',
            'Okay, the process has been cancelled.',
          ),
          role: MessageRole.ai,
        );
        setState(() {
          _currentState = AppState.idle;
          _pendingWorker = null;
          _pendingQuote = null;
          _activeMemory.clear();
          _matchedWorkers.clear();
        });
      } else {
        if (_matchedWorkers.isNotEmpty) {
          _addText(
            'No problem. Let me check the next available professional...',
            role: MessageRole.ai,
          );
          _showNextWorker();
        } else {
          _addText(
            'It looks like I\'m out of available workers for this specific request. Let\'s try a different time or date.',
            role: MessageRole.ai,
          );
          setState(() {
            _currentState = AppState.idle;
            _pendingWorker = null;
            _pendingQuote = null;
            // Preserving _activeMemory (including location) so the user doesn't have to type it again!
            _matchedWorkers.clear();
          });
        }
      }
      return;
    }

    if (_currentState == AppState.booked) {
      setState(() => _currentState = AppState.idle);
    }

    setState(() => _isProcessing = true);

    try {
      final intent = await _engine.parseIntent(text);

      if (intent['action'] == 'cancel') {
        _addText(
          _ru(
            'Theek hai, process cancel kar diya gaya.',
            'Okay, the process has been cancelled.',
          ),
          role: MessageRole.ai,
        );
        setState(() {
          _currentState = AppState.idle;
          _pendingWorker = null;
          _pendingQuote = null;
          _activeMemory.clear();
          _matchedWorkers.clear();
        });
        setState(() => _isProcessing = false);
        return;
      }

      if (intent['action'] == 'irrelevant') {
        _addText(
          "Sorry I don't reply to these types of question, My only goal is to provide you the best service which is providing you skilled workers for your problems.",
          role: MessageRole.ai,
        );
        setState(() => _isProcessing = false);
        return;
      }

      // ── Blank-context/Irrelevant fallback check ──────────────────────────────
      final isGreeting = RegExp(r'\b(hi|hello|hey|salaam|assalam|aoa)\b', caseSensitive: false).hasMatch(text);
      if (intent['service'] == null &&
          intent['location'] == null &&
          intent['phone'] == null &&
          _activeMemory['service'] == null &&
          _activeMemory['location'] == null &&
          _activeMemory['phone'] == null &&
          !isGreeting) {
        _addText(
          "Sorry I don't reply to these types of question, My only goal is to provide you the best service which is providing you skilled workers for your problems.",
          role: MessageRole.ai,
        );
        setState(() => _isProcessing = false);
        return;
      }

      // ── Detect language from intent ──────────────────────────────────────────
      if (intent['language'] != null) {
        setState(() => _detectedLanguage = intent['language'] as String);
      }

      if (intent['service'] != null) {
        _activeMemory['service'] = intent['service'];
      }

      if (_activeMemory['service'] == 'Clarify_Technician') {
        _addText(
          _ru(
            'Aapko kis tarah ka Technician chahiye? Jaise ke Mechanic (Car Technician) ya AC Technician?',
            'Which type of technician are you looking for? For example, a Mechanic (Car Technician) or an AC Technician?',
          ),
          role: MessageRole.ai,
        );
        _activeMemory.remove('service');
        setState(() => _isProcessing = false);
        return;
      }

      // ── Smart location resolution (3-tier) ──────────────────────────────────
      if (intent['location'] != null) {
        final rawLoc = intent['location'] as String;
        _addText(
          '🔍 ${_ru('Location: "$rawLoc"', 'Analyzing: "$rawLoc"')}...',
          role: MessageRole.system,
        );
        final resolved = await _engine.resolveLocation(rawLoc);
        if (resolved != null) {
          _activeMemory['location'] = resolved;
          if (resolved.toLowerCase() != rawLoc.toLowerCase()) {
            _addText('📍 "$rawLoc" → "$resolved"', role: MessageRole.system);
          }
        } else {
          _addText(
            _ru(
              '"$rawLoc" samajh nahi aaya. Apna Mohalla (sub-region) ya Taluka (town) batayein — jaise: Gulshan, Saddar, North Karachi, Korangi...',
              'I couldn\'t identify "$rawLoc". Please share your Mohalla (neighborhood) or Taluka (town) — e.g. Gulshan, Saddar, North Karachi, Korangi...',
            ),
            role: MessageRole.ai,
          );
          _activeMemory.remove('location');
        }
      }

      if (intent['day'] == 'Tomorrow' || _activeMemory['day'] == null) {
        _activeMemory['day'] = intent['day'] ?? 'Today';
      }
      if (intent['time'] != null) _activeMemory['time'] = intent['time'];
      if (intent['phone'] != null) _activeMemory['phone'] = intent['phone'];

      final service = _activeMemory['service'];
      final location = _activeMemory['location'];
      final day = _activeMemory['day'];
      final time = _activeMemory['time'];
      final phone = _activeMemory['phone'];

      List<String> missingOther = [];
      if (service == null) {
        missingOther.add(_ru('service ka naam', 'the service you need'));
      }
      if (location == null) {
        missingOther.add(_ru('Mohalla/Taluka', 'your Mohalla or Taluka'));
      }

      if (time == null) {
        if (missingOther.isNotEmpty) {
          _addText(
            _ru(
              'Shukriya! Yeh bhi batayein — ${missingOther.join(' aur ')}?',
              'Got it! Could you also share ${missingOther.join(' and ')}?',
            ),
            role: MessageRole.ai,
          );
        }
        _addText(
          _ru(
            'Kab chahiye service? Neeche se waqt select karein:',
            'When do you need the service? Pick a time slot below:',
          ),
          role: MessageRole.ai,
        );
        setState(
          () => _messages.add(
            ChatMessage(role: MessageRole.ai, type: MessageType.timePicker),
          ),
        );
        _scrollToBottom();
      } else if (missingOther.isNotEmpty) {
        _addText(
          _ru(
            'Theek hai! Bas — ${missingOther.join(' aur ')} bhi batayein?',
            'Got it! Please also share ${missingOther.join(' and ')}.',
          ),
          role: MessageRole.ai,
        );
      } else {
        _matchedWorkers = _engine.findMatches(
          service: service,
          location: location,
          time: time,
        );
        if (_matchedWorkers.isEmpty) {
          _addText(
            _ru(
              'Maafi — $location mein $time ko koi $service nahi mila. Kya alag waqt try karein?',
              'Sorry, no $service found near $location for $day at $time. Should we try another time?',
            ),
            role: MessageRole.ai,
          );
        } else {
          _showNextWorker();
        }
      }
    } catch (e) {
      _addText(
        _ru(
          'Kuch masla ho gaya. Dobara try karein.',
          'An error occurred. Please try again.',
        ),
        role: MessageRole.system,
        isError: true,
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _ru(String romanUrdu, String english) =>
      _detectedLanguage == 'roman_urdu' ? romanUrdu : english;

  void _onTimePicked(String timeStr, String day) {
    // timeStr is e.g. "07:30 PM"
    _activeMemory['time'] = timeStr;
    _activeMemory['exactTime'] = timeStr; // keep exact for ETA calc
    _activeMemory['day'] = day;
    _addText('🕐 $timeStr — $day', role: MessageRole.user);
    final service = _activeMemory['service'];
    final location = _activeMemory['location'];
    List<String> missing = [];
    if (service == null) missing.add(_ru('service ka naam', 'service'));
    if (location == null) missing.add(_ru('Mohalla/Taluka', 'location'));
    if (missing.isNotEmpty) {
      _addText(
        _ru(
          'Waqt mil gaya! Ab batayein — ${missing.join(' aur ')}?',
          'Time noted! Could you also share ${missing.join(' and ')}?',
        ),
        role: MessageRole.ai,
      );
    } else {
      // Map exact time to a slot for worker matching
      final slot = _timeStrToSlot(timeStr);
      _matchedWorkers = _engine.findMatches(
        service: service,
        location: location,
        time: slot,
      );
      if (_matchedWorkers.isEmpty) {
        _addText(
          _ru(
            '$location mein $timeStr ko koi $service nahi. Alag waqt?',
            'No $service near $location at $timeStr. Try another time?',
          ),
          role: MessageRole.ai,
        );
      } else {
        _showNextWorker();
      }
    }
  }

  /// Maps an exact time string like "07:30 PM" to a worker availability slot.
  String _timeStrToSlot(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final hm = parts[0].split(':');
      int hr = int.parse(hm[0]);
      final pm = parts.length > 1 && parts[1] == 'PM';
      if (pm && hr != 12) hr += 12;
      if (!pm && hr == 12) hr = 0;
      if (hr >= 6 && hr < 12) return 'Morning';
      if (hr >= 12 && hr < 17) return 'Afternoon';
      if (hr >= 17 && hr < 22) return 'Evening';
      return 'Anytime';
    } catch (_) {
      return 'Anytime';
    }
  }

  /// Calculates a human-readable ETA based on the booked time slot and current time.
  String _calculateEtaMessage() {
    final now = DateTime.now();
    final day = _activeMemory['day'] ?? 'Today';
    final exactTime = _activeMemory['exactTime'] as String?;
    final workerName = _pendingWorker?.name ?? 'Your provider';

    DateTime target;
    String arrivalWindow;

    if (exactTime != null) {
      // Parse exact "HH:MM AM/PM" → DateTime
      try {
        final parts = exactTime.split(' ');
        final hm = parts[0].split(':');
        int hr = int.parse(hm[0]);
        final min = int.parse(hm[1]);
        final pm = parts.length > 1 && parts[1] == 'PM';
        if (pm && hr != 12) hr += 12;
        if (!pm && hr == 12) hr = 0;
        target = DateTime(now.year, now.month, now.day, hr, min);
        // Format back nicely for display
        final dhr = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr);
        final ampm = hr >= 12 ? 'PM' : 'AM';
        arrivalWindow = '$dhr:${min.toString().padLeft(2, '0')} $ampm';
      } catch (_) {
        target = now.add(const Duration(minutes: 35));
        arrivalWindow = exactTime;
      }
    } else {
      // Fallback to ASAP
      target = now.add(const Duration(minutes: 35));
      final dhr = target.hour > 12 ? target.hour - 12 : target.hour;
      final ampm = target.hour >= 12 ? 'PM' : 'AM';
      arrivalWindow = '$dhr:${target.minute.toString().padLeft(2, '0')} $ampm';
    }

    if (day == 'Tomorrow') {
      target = target.add(const Duration(days: 1));
    } else if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    final diff = target.difference(now);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;

    final String timeLeft;
    if (hours > 0 && mins > 0) {
      timeLeft = _ru(
        '$hours ghanta $mins minute mein',
        'in ${hours}h ${mins}m',
      );
    } else if (hours > 0) {
      timeLeft = _ru('$hours ghante mein', 'in ${hours}h');
    } else {
      timeLeft = _ru('$mins minute mein', 'in ${mins}m');
    }

    final dayLabel = target.day != now.day
        ? _ru('kal', 'tomorrow')
        : _ru('aaj', 'today');

    return _ru(
      '$workerName $dayLabel $arrivalWindow ko pahunchega ($timeLeft). Taiyar rahein! ✅',
      '$workerName arrives $dayLabel at $arrivalWindow ($timeLeft). Please be ready! ✅',
    );
  }

  /// Clears current chat and starts a new conversation.
  void _startNewChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        ChatMessage(
          role: MessageRole.ai,
          text: _ru(
            'Assalam o Alaikum! Kaarigar AI phir hazir hai. Aaj konsi service chahiye?',
            'Hello! Starting a new session. What service do you need today?',
          ),
        ),
      );
      _currentState = AppState.idle;
      _pendingWorker = null;
      _pendingQuote = null;
      _activeMemory.clear();
      _matchedWorkers.clear();
    });
    Navigator.pop(context); // close drawer
    _scrollToBottom();
  }

  void _toggleMicrophone() async {
    if (!_speechEnabled) {
      _speechEnabled = await _speechToText.initialize();
      if (!_speechEnabled) {
        _addText(
          'Speech recognition is not available or permission denied.',
          role: MessageRole.system,
          isError: true,
        );
        return;
      }
    }

    if (_speechToText.isNotListening) {
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _promptController.text = result.recognizedWords;
          });
          if (result.finalResult) {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      setState(() {
        _isListening = true;
      });
    } else {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
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

          // Blur overlay to smooth out the orbs
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageRow(_messages[index]);
                    },
                  ),
                ),
                _buildInputArea(),
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
        color: color.withValues(alpha: 0.15),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white70),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Kaarigar AI',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: _currentUser != null
                ? () async {
                    await _firebaseService.signOut();
                    setState(() {
                      _loggedInUser = null;
                      _messages.clear();
                      _messages.add(
                        ChatMessage(
                          role: MessageRole.ai,
                          text:
                              'Assalam o Alaikum! Main Kaarigar AI hoon. Main aapko Karachi mein koi bhi skilled worker dhondhne mein madad kar sakta hoon.\n\nAap konsi service chahte hain?',
                        ),
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out successfully')),
                    );
                  }
                : _showSignInDialog,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    _currentUser != null ? Icons.logout : Icons.person_outline,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _loggedInUser ?? 'Sign In',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignInDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF16161A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_open,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sign In / Sign Up',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Google Sign-In ──────────────────────────────────
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _isProcessing = true);
                    try {
                      await _firebaseService.signInWithGoogle();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Google sign-in failed: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    } finally {
                      setState(() => _isProcessing = false);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google 'G' logo using colored text
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            children: const [
                              TextSpan(
                                text: 'G',
                                style: TextStyle(color: Color(0xFF4285F4)),
                              ),
                              TextSpan(
                                text: 'o',
                                style: TextStyle(color: Color(0xFFDB4437)),
                              ),
                              TextSpan(
                                text: 'o',
                                style: TextStyle(color: Color(0xFFF4B400)),
                              ),
                              TextSpan(
                                text: 'g',
                                style: TextStyle(color: Color(0xFF4285F4)),
                              ),
                              TextSpan(
                                text: 'l',
                                style: TextStyle(color: Color(0xFF0F9D58)),
                              ),
                              TextSpan(
                                text: 'e',
                                style: TextStyle(color: Color(0xFFDB4437)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Continue with Google',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF16161A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'History',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // ── New Chat button ──────────────────────────────────────────
                  GestureDetector(
                    onTap: _startNewChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'New Chat',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: TextField(
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search history...',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white38,
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingsScreen(
                        userId: _currentUser?.uid,
                        localBookings: _localBookings,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'My Bookings',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white38,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _currentUser == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history,
                            color: Colors.white24,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sign in to see your history',
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _chatSessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white24,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No chat history yet',
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _chatSessions.length,
                      itemBuilder: (context, index) {
                        final session = _chatSessions[index];
                        final date = session['date'] as DateTime;
                        final now = DateTime.now();
                        final diff = now.difference(date).inDays;
                        String label;
                        if (diff == 0) {
                          label = 'Today';
                        } else if (diff == 1)
                          label = 'Yesterday';
                        else if (diff < 7)
                          label = '$diff days ago';
                        else
                          label = '${date.day}/${date.month}/${date.year}';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.chat,
                              color: Colors.white54,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            session['text'] ?? '',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            label,
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          onTap: () => Navigator.pop(context),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kaarigar AI Plus',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upgrade for faster matching and zero platform fees.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCategory(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String subtitle) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      title: Text(
        title,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
      ),
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Loading \$title...')));
        Navigator.pop(context);
      },
    );
  }

  Widget _buildMessageRow(ChatMessage msg) {
    if (msg.type == MessageType.workerCard) {
      return _buildWorkerCard(msg.worker!);
    }
    if (msg.type == MessageType.quoteCard) return _buildQuoteCard(msg.quote!);
    if (msg.type == MessageType.timePicker) return _buildTimePickerCard();
    if (msg.type == MessageType.confirmButtons) return _buildConfirmButtonsCard();

    if (msg.role == MessageRole.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: msg.isError
                  ? Colors.redAccent.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              msg.text ?? '',
              style: GoogleFonts.inter(
                color: msg.isError ? Colors.redAccent : Colors.white60,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    final isUser = msg.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
          Flexible(
            child: isUser
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      msg.text ?? '',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 4, right: 32),
                    child: Text(
                      msg.text ?? '',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        height: 1.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Inline Time & Date Picker Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTimePickerCard() {
    // Wheel data
    final hours = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
    final minutes = List.generate(60, (i) => i.toString().padLeft(2, '0'));
    const periods = ['AM', 'PM'];
    const days = ['Today', 'Tomorrow'];

    final hrCtrl = FixedExtentScrollController(
      initialItem: DateTime.now().hour % 12,
    );
    final minCtrl = FixedExtentScrollController(
      initialItem: DateTime.now().minute,
    );
    final pmCtrl = FixedExtentScrollController(
      initialItem: DateTime.now().hour >= 12 ? 1 : 0,
    );

    int selHr = DateTime.now().hour % 12;
    int selMin = DateTime.now().minute;
    int selPm = DateTime.now().hour >= 12 ? 1 : 0;
    int selDay = 0;

    const itemH = 40.0;
    const wheelH = itemH * 3;

    Widget drum(
      List<String> items,
      FixedExtentScrollController ctrl,
      void Function(int) onChanged,
    ) {
      return SizedBox(
        width: 52,
        height: wheelH,
        child: Stack(
          children: [
            // Selection highlight bar
            Positioned(
              top: itemH,
              left: 0,
              right: 0,
              child: Container(
                height: itemH,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ListWheelScrollView.useDelegate(
              controller: ctrl,
              itemExtent: itemH,
              physics: const FixedExtentScrollPhysics(),
              perspective: 0.004,
              diameterRatio: 1.8,
              onSelectedItemChanged: onChanged,
              childDelegate: ListWheelChildLoopingListDelegate(
                children: items
                    .map(
                      (v) => Center(
                        child: Text(
                          v,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      );
    }

    return StatefulBuilder(
      builder: (ctx, setLocal) {
        String fmt() {
          final h = hours[selHr % 12];
          final m = minutes[selMin % 60];
          final p = periods[selPm % 2];
          final d = days[selDay];
          return '$h:$m $p — $d';
        }

        return Padding(
          padding: const EdgeInsets.only(left: 44, right: 16, bottom: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────────────
                Row(
                  children: [
                    const Text('🕐', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      _ru('Waqt chunein', 'Select Time'),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Day toggle ───────────────────────────────────────────────────
                Row(
                  children: List.generate(days.length, (i) {
                    final sel = selDay == i;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setLocal(() => selDay = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: sel
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFFEC4899),
                                    ],
                                  )
                                : null,
                            color: sel
                                ? null
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            days[i],
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),

                // ── Clock wheels ─────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    drum(hours, hrCtrl, (i) => setLocal(() => selHr = i)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        ':',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    drum(minutes, minCtrl, (i) => setLocal(() => selMin = i)),
                    const SizedBox(width: 12),
                    // AM / PM drum
                    SizedBox(
                      width: 48,
                      height: wheelH,
                      child: Stack(
                        children: [
                          Positioned(
                            top: itemH,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: itemH,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFEC4899,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          ListWheelScrollView(
                            controller: pmCtrl,
                            itemExtent: itemH,
                            physics: const FixedExtentScrollPhysics(),
                            diameterRatio: 1.8,
                            onSelectedItemChanged: (i) =>
                                setLocal(() => selPm = i),
                            children: periods
                                .map(
                                  (p) => Center(
                                    child: Text(
                                      p,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // ── Preview label ────────────────────────────────────────────────
                Text(
                  fmt(),
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Confirm button ───────────────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    final timeStr =
                        '${hours[selHr % 12]}:${minutes[selMin % 60]} ${periods[selPm % 2]}';
                    _onTimePicked(timeStr, days[selDay]);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _ru('Waqt Confirm Karein ✓', 'Confirm Time ✓'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmButtonsCard() {
    return Padding(
      padding: const EdgeInsets.only(left: 44, right: 16, bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _onConfirmPressed(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _ru('Haan (Yes)', 'Yes'),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _onConfirmPressed(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel_outlined, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _ru('Nahi (No)', 'No'),
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onConfirmPressed(bool confirmed) {
    _promptController.text = confirmed ? 'Yes' : 'No';
    _processRequest();
  }

  Widget _buildWorkerCard(Worker worker) {
    return Padding(
      padding: const EdgeInsets.only(left: 44, right: 16, bottom: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      'https://i.pravatar.cc/150?u=${worker.name}${worker.phone}',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        width: 60,
                        height: 60,
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
                          worker.name,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          worker.occupation,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF6366F1),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white38,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              worker.location,
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCol(Icons.star, '${worker.rating}', 'Rating'),
                    _buildStatCol(
                      Icons.verified,
                      '${(worker.reliabilityScore * 100).toInt()}%',
                      'Reliable',
                    ),
                    _buildStatCol(
                      Icons.payments,
                      'Rs.${worker.hourlyRate.toStringAsFixed(0)}',
                      'Per Hr',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCol(IconData icon, String val, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(
              val,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildQuoteCard(Map<String, dynamic> quote) {
    return Padding(
      padding: const EdgeInsets.only(left: 44, right: 16, bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimated Quote',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuoteRow('Base Rate', quote['base']),
            if (quote['surge'] > 0)
              _buildQuoteRow('Surge Pricing', quote['surge']),
            _buildQuoteRow('Platform Fee', quote['platformFee']),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                ),
                Text(
                  'Rs. ${quote['total'].toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(0)}',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(
        16,
      ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D12).withValues(alpha: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic_off : Icons.mic,
                    color: _isListening ? Colors.redAccent : Colors.white70,
                  ),
                  onPressed: _toggleMicrophone,
                ),
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    onSubmitted: (_) => _processRequest(),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Ask Kaarigar AI...',
                      hintStyle: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _processRequest,
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
