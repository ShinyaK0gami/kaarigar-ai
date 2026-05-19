import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/worker.dart';

/// All known database locations (lowercase) — 54 Karachi sub-regions
const List<String> kKnownLocations = [
  // Karachi Central
  'liaquatabad', 'north nazimabad', 'frontier colony', 'new karachi',
  'banaras town', 'gulberg', 'buffer zone', 'husainabad',
  // Karachi East
  'gulshan-e-iqbal', 'gulistan-e-johar', 'safoora goth',
  'shah faisal colony', 'jamshed town', 'bahadurabad', 'soldier bazaar',
  'garden', 'landhi', 'korangi industrial area', 'malir', 'malir cantonment',
  // Karachi South
  'saddar', 'burns road', 'bund bazaar', 'lyari', 'ranchhore lines',
  'civil lines', 'frere hall', 'clifton', 'boat basin', 'sea view',
  'defence phase 1', 'defence phase 2', 'defence phase 4',
  'defence phase 6', 'defence phase 8', 'khayaban-e-ittehad',
  // Karachi West
  'site', 'orangi town', 'qasba colony', 'baldia town', 'metroville',
  'harbour front',
  // Korangi
  'korangi', 'landhi colony',
  // Malir / Bin Qasim
  'gulshan-e-hadeed', 'bin qasim',
  // Legacy / Landmark
  'i.i chundrigar road', 'shahrah-e-faisal', 'mazar-e-quaid',
  'port grand', 'hawksbay', 'sandspit beach', 'north karachi',
];

const Map<String, List<String>> kAdjacencyMap = {
  // ── Karachi Central ────────────────────────────────────────────────────────
  'liaquatabad':      ['north nazimabad', 'gulberg', 'husainabad', 'frontier colony', 'new karachi'],
  'north nazimabad':  ['liaquatabad', 'gulberg', 'buffer zone', 'new karachi'],
  'frontier colony':  ['liaquatabad', 'new karachi', 'north karachi'],
  'new karachi':      ['frontier colony', 'liaquatabad', 'north karachi', 'north nazimabad'],
  'banaras town':     ['new karachi', 'north karachi', 'orangi town'],
  'gulberg':          ['liaquatabad', 'husainabad', 'north nazimabad', 'buffer zone'],
  'buffer zone':      ['gulberg', 'north nazimabad', 'north karachi', 'liaquatabad'],
  'husainabad':       ['gulberg', 'liaquatabad'],
  // ── Karachi East ───────────────────────────────────────────────────────────
  'gulshan-e-iqbal':     ['gulistan-e-johar', 'shah faisal colony', 'safoora goth', 'bahadurabad', 'shahrah-e-faisal'],
  'gulistan-e-johar':    ['gulshan-e-iqbal', 'safoora goth'],
  'safoora goth':        ['gulshan-e-iqbal', 'gulistan-e-johar', 'malir'],
  'shah faisal colony':  ['gulshan-e-iqbal', 'landhi', 'korangi', 'shahrah-e-faisal'],
  'jamshed town':        ['garden', 'bahadurabad', 'soldier bazaar', 'saddar'],
  'bahadurabad':         ['jamshed town', 'garden', 'gulshan-e-iqbal', 'saddar'],
  'soldier bazaar':      ['jamshed town', 'saddar', 'burns road', 'garden'],
  'garden':              ['saddar', 'jamshed town', 'soldier bazaar', 'bahadurabad'],
  'landhi':              ['korangi', 'shah faisal colony', 'malir', 'landhi colony'],
  'korangi industrial area': ['korangi', 'landhi', 'gulshan-e-hadeed'],
  'malir':               ['landhi', 'safoora goth', 'malir cantonment', 'gulshan-e-hadeed'],
  'malir cantonment':    ['malir'],
  // ── Karachi South ──────────────────────────────────────────────────────────
  'saddar':              ['burns road', 'bund bazaar', 'soldier bazaar', 'garden', 'civil lines', 'lyari', 'mazar-e-quaid', 'i.i chundrigar road'],
  'burns road':          ['saddar', 'bund bazaar', 'soldier bazaar'],
  'bund bazaar':         ['saddar', 'burns road'],
  'lyari':               ['saddar', 'ranchhore lines', 'civil lines'],
  'ranchhore lines':     ['lyari', 'saddar', 'civil lines'],
  'civil lines':         ['saddar', 'lyari', 'clifton', 'frere hall', 'mazar-e-quaid', 'i.i chundrigar road', 'harbour front'],
  'frere hall':          ['civil lines', 'clifton', 'saddar'],
  'clifton':             ['civil lines', 'frere hall', 'boat basin', 'defence phase 1', 'sea view', 'shahrah-e-faisal'],
  'boat basin':          ['clifton', 'sea view', 'khayaban-e-ittehad'],
  'sea view':            ['boat basin', 'clifton'],
  'defence phase 1':     ['clifton', 'defence phase 2'],
  'defence phase 2':     ['defence phase 1', 'defence phase 4'],
  'defence phase 4':     ['defence phase 2', 'defence phase 6', 'khayaban-e-ittehad'],
  'defence phase 6':     ['defence phase 4', 'defence phase 8'],
  'defence phase 8':     ['defence phase 6'],
  'khayaban-e-ittehad':  ['boat basin', 'defence phase 4', 'clifton'],
  // ── Karachi West ───────────────────────────────────────────────────────────
  'site':                ['orangi town', 'baldia town', 'i.i chundrigar road'],
  'orangi town':         ['site', 'qasba colony', 'north karachi', 'banaras town'],
  'qasba colony':        ['orangi town'],
  'baldia town':         ['site', 'metroville'],
  'metroville':          ['baldia town'],
  'harbour front':       ['civil lines', 'i.i chundrigar road', 'port grand'],
  // ── Korangi ────────────────────────────────────────────────────────────────
  'korangi':             ['landhi', 'shah faisal colony', 'korangi industrial area', 'landhi colony'],
  'landhi colony':       ['landhi', 'korangi'],
  // ── Malir / Bin Qasim ──────────────────────────────────────────────────────
  'gulshan-e-hadeed':    ['malir', 'bin qasim', 'korangi industrial area'],
  'bin qasim':           ['gulshan-e-hadeed'],
  // ── Legacy / Landmark ──────────────────────────────────────────────────────
  'i.i chundrigar road': ['saddar', 'civil lines', 'harbour front', 'port grand', 'site'],
  'shahrah-e-faisal':    ['saddar', 'gulshan-e-iqbal', 'clifton', 'shah faisal colony'],
  'mazar-e-quaid':       ['saddar', 'civil lines', 'frere hall'],
  'port grand':          ['i.i chundrigar road', 'harbour front'],
  'hawksbay':            ['sandspit beach'],
  'sandspit beach':      ['hawksbay'],
  'north karachi':       ['new karachi', 'buffer zone', 'orangi town', 'banaras town', 'frontier colony'],
};

class AntigravityEngine {
  GenerativeModel? _model;
  bool _llmAvailable = false;

  AntigravityEngine() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-2.5-flash', // ✅ Supported model
        apiKey: apiKey,
      );
      _llmAvailable = true;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // STEP 1: Parse the full user intent via LLM (chunked Roman Urdu analysis)
  // ────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> parseIntent(String input) async {
    final now = DateTime.now();
    final prompt = '''
You are "Antigravity Orchestrator", an AI system for matching informal economy workers with clients in Karachi, Pakistan.
Current date/time: $now (PKT)

TASK: Analyze the user's message carefully. It may be in English, Urdu, or Roman Urdu (a mix). 
Break it into semantic chunks and extract EACH of the following fields:

1. "service": The type of worker needed. Normalize to: Electrician, Plumber, Mechanic, Welder, AC Technician, Carpenter, Tutor, Rider, Beautician, Labourer, Clarify_Technician. Roman Urdu mappings: bijli wala=Electrician, paani wala/nalka=Plumber, gaari wala/mechanic=Mechanic, AC wala=AC Technician, ustaad/teacher=Tutor, delivery boy=Rider, carpenter/barhai=Carpenter. If the user only says "Technician" without specifying AC, Car, etc., return "Clarify_Technician".

2. "location": Any neighborhood, area, sector, or landmark in Karachi mentioned. Return the raw location string mentioned. Do NOT try to match it to any list yet — return exactly what the user said.

3. "day": "Today" or "Tomorrow". Use temporal reasoning — if user says "subha" (morning) but current time is past noon, they likely mean Tomorrow. "kal"=Tomorrow, "aaj"=Today.

4. "time": "Morning", "Afternoon", "Evening", or "Anytime". 
   Mappings: subha/صبح=Morning, dopehar=Afternoon, shaam/raat/night/pm=Evening, abhi/kabhi bhi=Anytime.

5. "phone": Any Pakistani phone number (e.g. 0300-1234567 or 03001234567). Return digits only or null.

6. "action": "cancel" if user wants to cancel/stop/nahi chahiye/band karo. "irrelevant" if the user is asking a general question, programming question, or talking about topics completely unrelated to finding or hiring a skilled worker. Otherwise "search".

7. "language": Detect the primary language of the input. Set to "roman_urdu" if the message uses Roman Urdu words (e.g. chahiye, wala, baje, subha, mujhe, aapko, karo, nahi, etc.). Set to "english" if the message is predominantly English.

Return ONLY a raw JSON object, no markdown, no explanation. Example:
{"service":"Electrician","location":"North Nazimabad Block D","day":"Today","time":"Evening","phone":"03001234567","action":"search","language":"roman_urdu"}

User message: "$input"
''';

    if (_llmAvailable) {
      try {
        final response =
            await _model!.generateContent([Content.text(prompt)]);
        final rawText = response.text?.trim() ?? '{}';
        final cleanJson =
            rawText.replaceAll('```json', '').replaceAll('```', '').trim();
        final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
        print('[Antigravity] LLM parsed intent: $parsed');
        return parsed;
      } catch (e) {
        print('[Antigravity] LLM parseIntent failed, using fallback. Error: $e');
      }
    }

    return _offlineParseIntent(input);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // STEP 2: Smart location resolution (3-tier)
  // Tier 1: Exact DB match
  // Tier 2: LLM normalizes the raw location → re-try exact match
  // Tier 3: LLM picks nearest from known list
  // ────────────────────────────────────────────────────────────────────────────
  Future<String?> resolveLocation(String? rawLocation) async {
    if (rawLocation == null || rawLocation.trim().isEmpty) return null;

    final lower = rawLocation.trim().toLowerCase();

    // ── Tier 1: Exact or substring match against known locations ──────────────
    for (final known in kKnownLocations) {
      if (lower == known || lower.contains(known) || known.contains(lower)) {
        print('[Antigravity] Location exact match: $known');
        return known;
      }
    }

    // ── Tier 2 & 3: Ask LLM ───────────────────────────────────────────────────
    if (_llmAvailable) {
      try {
        final locationList = kKnownLocations.map((l) => '"$l"').join(', ');
        final locationPrompt = '''
You are a geography assistant for Karachi, Pakistan.

A user mentioned this location: "$rawLocation"
This could be a Roman Urdu name, a landmark, a block, a sector, or a colloquial area name.

Here are the ONLY locations available in our database:
[$locationList]

Your task:
1. Try to identify which database location is the SAME as or NEAREST to "$rawLocation" based on your knowledge of Karachi geography.
2. If you can identify a match or a nearby area, return ONLY the exact matching string from the list above.
3. If there is absolutely no reasonable geographic match, return the string "unknown".

Return ONLY the matched location string or "unknown". No explanation.
''';

        final response = await _model!
            .generateContent([Content.text(locationPrompt)]);
        final result = response.text?.trim().toLowerCase() ?? 'unknown';

        if (result != 'unknown') {
          // Verify the LLM returned a valid known location
          for (final known in kKnownLocations) {
            if (result == known || result.contains(known) || known.contains(result)) {
              print('[Antigravity] LLM resolved location "$rawLocation" → "$known"');
              return known;
            }
          }
        }

        print('[Antigravity] LLM could not resolve location: "$rawLocation"');
        return null;
      } catch (e) {
        print('[Antigravity] LLM location resolution failed: $e');
      }
    }

    // ── Offline fallback: fuzzy substring matching ────────────────────────────
    return _offlineResolveLocation(lower);
  }

  String? _offlineResolveLocation(String lower) {
    // Exact match first
    for (final known in kKnownLocations) {
      if (lower == known || lower.contains(known) || known.contains(lower)) {
        return known;
      }
    }

    // Comprehensive Roman Urdu + colloquial alias map
    final aliases = <String, String>{
      // DHA / Clifton
      'dha phase 1': 'defence phase 1', 'dha 1': 'defence phase 1',
      'dha phase 2': 'defence phase 2', 'dha 2': 'defence phase 2',
      'dha phase 4': 'defence phase 4', 'dha 4': 'defence phase 4',
      'dha phase 6': 'defence phase 6', 'dha 6': 'defence phase 6',
      'dha phase 8': 'defence phase 8', 'dha 8': 'defence phase 8',
      'dha': 'defence phase 4', 'defence': 'defence phase 4',
      'clifton': 'clifton', 'boat basin': 'boat basin',
      'khayaban': 'khayaban-e-ittehad', 'khy': 'khayaban-e-ittehad',
      'sea view': 'sea view', 'seaview': 'sea view',
      // Saddar & surrounds
      'saddar': 'saddar', 'sadder': 'saddar', 'sadar': 'saddar',
      'burns road': 'burns road', 'burn road': 'burns road',
      'bund bazaar': 'bund bazaar', 'bundbazaar': 'bund bazaar',
      'soldier bazaar': 'soldier bazaar', 'soldier bazar': 'soldier bazaar',
      // Lyari
      'lyari': 'lyari', 'leari': 'lyari', 'liyari': 'lyari',
      'ranchhore': 'ranchhore lines', 'ranchore': 'ranchhore lines',
      // Gulshan / Johar / East
      'gulshan': 'gulshan-e-iqbal', 'gulshan iqbal': 'gulshan-e-iqbal',
      'gulshan e iqbal': 'gulshan-e-iqbal', 'gulshan-e-iqbal': 'gulshan-e-iqbal',
      'johar': 'gulistan-e-johar', 'gulistan': 'gulistan-e-johar',
      'johar town': 'gulistan-e-johar', 'gulistan johar': 'gulistan-e-johar',
      'safoora': 'safoora goth', 'safoora goth': 'safoora goth',
      'shah faisal': 'shah faisal colony', 'sf colony': 'shah faisal colony',
      'jamshed': 'jamshed town', 'jamshed town': 'jamshed town',
      'bahadurabad': 'bahadurabad', 'bahadrabad': 'bahadurabad',
      'garden': 'garden', 'garden karachi': 'garden',
      // North / Central
      'gulberg': 'gulberg', 'gulberg town': 'gulberg',
      'north naz': 'north nazimabad', 'north nazimabad': 'north nazimabad',
      'nazimabad': 'gulberg', 'n nazimabad': 'north nazimabad',
      'liaquatabad': 'liaquatabad', 'lyaqatabad': 'liaquatabad',
      'new karachi': 'new karachi', 'nk': 'new karachi',
      'banaras': 'banaras town', 'banaras town': 'banaras town',
      'frontier': 'frontier colony', 'frontier colony': 'frontier colony',
      'husainabad': 'husainabad', 'hussainabad': 'husainabad',
      'buffer zone': 'buffer zone', 'buffer': 'buffer zone', 'bufferzone': 'buffer zone',
      'north karachi': 'north karachi', 'n karachi': 'north karachi',
      // West
      'site': 'site', 'site area': 'site', 'site industrial': 'site',
      'orangi': 'orangi town', 'orangi town': 'orangi town',
      'qasba': 'qasba colony', 'qasba colony': 'qasba colony',
      'baldia': 'baldia town', 'baldia town': 'baldia town',
      'metroville': 'metroville', 'metro ville': 'metroville',
      'harbour': 'harbour front', 'harbor front': 'harbour front',
      // Korangi / East
      'korangi': 'korangi', 'korangi town': 'korangi',
      'landhi': 'landhi', 'landhi colony': 'landhi colony',
      'malir': 'malir', 'malir cantonment': 'malir cantonment',
      'malir cantt': 'malir cantonment',
      // Bin Qasim / Hadeed
      'gulshan hadeed': 'gulshan-e-hadeed', 'gulshan e hadeed': 'gulshan-e-hadeed',
      'bin qasim': 'bin qasim', 'bqt': 'bin qasim', 'port qasim': 'bin qasim',
      // Legacy / landmarks
      'chundrigar': 'i.i chundrigar road', 'ii chundrigar': 'i.i chundrigar road',
      'shahrah faisal': 'shahrah-e-faisal', 'shahra e faisal': 'shahrah-e-faisal',
      'mazar': 'mazar-e-quaid', 'mazar quaid': 'mazar-e-quaid',
      'frere hall': 'frere hall', 'frere': 'frere hall',
      'mohatta': 'frere hall', 'mohatta palace': 'frere hall',
      'port grand': 'port grand',
      'hawksbay': 'hawksbay', 'hawks bay': 'hawksbay',
      'sandspit': 'sandspit beach', 'sand spit': 'sandspit beach',
    };

    for (final alias in aliases.entries) {
      if (lower.contains(alias.key)) {
        print('[Antigravity] Offline alias resolved "$lower" → "${alias.value}"');
        return alias.value;
      }
    }
    return null;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // STEP 3: Find matching workers with the resolved location
  // ────────────────────────────────────────────────────────────────────────────
  List<Worker> findMatches({
    required String service,
    required String location,
    required String time,
  }) {
    final targetLoc = location.toLowerCase();
    final targetService = service.toLowerCase();
    final targetTime = time.toLowerCase();

    // 1. Exact match
    List<Worker> matches = mockWorkers.where((w) {
      return w.occupation.toLowerCase() == targetService &&
          w.location.toLowerCase() == targetLoc &&
          (_timeMatches(w.availableTime.toLowerCase(), targetTime));
    }).toList();

    // 2. Adjacent location fallback
    if (matches.isEmpty) {
      final nearby = kAdjacencyMap[targetLoc] ?? [];
      matches = mockWorkers.where((w) {
        return w.occupation.toLowerCase() == targetService &&
            nearby.contains(w.location.toLowerCase()) &&
            (_timeMatches(w.availableTime.toLowerCase(), targetTime));
      }).toList();
    }

    // 3. Sort by combined score
    matches.sort((a, b) {
      return (b.rating * b.reliabilityScore)
          .compareTo(a.rating * a.reliabilityScore);
    });

    return matches;
  }

  bool _timeMatches(String workerTime, String targetTime) {
    return workerTime == targetTime ||
        workerTime == 'anytime' ||
        targetTime == 'anytime';
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Offline Fallback: rich Roman Urdu keyword analysis
  // ────────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _offlineParseIntent(String input) {
    final lower = input.toLowerCase();
    String? service;
    String? location;
    String? time;
    String action = 'search';

    // ── Service Extraction (Roman Urdu + English) ────────────────────────────
    final serviceMap = <String, String>{
      'electrician': 'Electrician', 'bijli wala': 'Electrician',
      'bijli': 'Electrician', 'light wala': 'Electrician',
      'plumber': 'Plumber', 'paani wala': 'Plumber',
      'nalka': 'Plumber', 'pipe': 'Plumber',
      'mechanic': 'Mechanic', 'gaari wala': 'Mechanic',
      'car mechanic': 'Mechanic', 'motor mechanic': 'Mechanic',
      'welder': 'Welder', 'welding': 'Welder',
      'ac technician': 'AC Technician', 'ac wala': 'AC Technician',
      'ac mechanic': 'AC Technician', 'ac': 'AC Technician',
      'technician': 'Clarify_Technician',
      'carpenter': 'Carpenter', 'barhai': 'Carpenter',
      'wood': 'Carpenter', 'furniture': 'Carpenter',
      'tutor': 'Tutor', 'teacher': 'Tutor',
      'ustaad': 'Tutor', 'padhai': 'Tutor',
      'rider': 'Rider', 'delivery': 'Rider',
      'courier': 'Rider', 'biker': 'Rider',
      'beautician': 'Beautician', 'parlour': 'Beautician',
      'makeup': 'Beautician', 'beauty': 'Beautician',
      'labourer': 'Labourer', 'mazdoor': 'Labourer',
      'labour': 'Labourer', 'helper': 'Labourer',
    };

    for (final entry in serviceMap.entries) {
      if (lower.contains(entry.key)) {
        service = entry.value;
        break;
      }
    }

    // ── Location Extraction ──────────────────────────────────────────────────
    location = _offlineResolveLocation(lower);

    // ── Time Extraction ──────────────────────────────────────────────────────
    if (lower.contains('anytime') || lower.contains('kabhi') || lower.contains('abhi')) {
      time = 'Anytime';
    } else if (lower.contains('subha') || lower.contains('subah') || lower.contains('morning') || RegExp(r'\bam\b').hasMatch(lower)) {
      time = 'Morning';
    } else if (lower.contains('dopehar') || lower.contains('afternoon')) {
      time = 'Afternoon';
    } else if (lower.contains('raat') || lower.contains('shaam') || lower.contains('evening') || lower.contains('night') || lower.contains('baje') || RegExp(r'\bpm\b').hasMatch(lower)) {
      time = 'Evening';
    }

    // ── Day Extraction ───────────────────────────────────────────────────────
    String day = 'Today';
    if (lower.contains('kal') || lower.contains('tomorrow')) {
      day = 'Tomorrow';
    } else if (time == 'Morning' && DateTime.now().hour >= 12) {
      day = 'Tomorrow';
    }

    // ── Phone Extraction ─────────────────────────────────────────────────────
    final phoneRegex = RegExp(r'(03\d{2}[\s\-]?\d{7})');
    final phoneMatch = phoneRegex.firstMatch(input);
    final phone = phoneMatch?.group(0);

    // ── Action Extraction ────────────────────────────────────────────────────
    if (lower.contains('cancel') || lower.contains('cancle') ||
        lower.contains('stop') || lower.contains('band karo') ||
        lower.contains('nahi chahiye') || lower.contains('khatam') ||
        lower.contains('mat karo')) {
      action = 'cancel';
    } else {
      final irrelevantKeywords = [
        'joke', 'story', 'song', 'poem', 'write', 'code', 'program', 'python',
        'java', 'react', 'flutter', 'html', 'css', 'script', 'weather', 'news',
        'who is', 'what is', 'how to', 'why ', 'solve', 'math', 'calculator',
        'translate', 'game', 'play', 'movie', 'history', 'science', 'explain',
        'tell me', 'definition', 'meaning of', 'quiz', 'trivia', 'how are you',
        'who are you', 'your name', 'what can you do', 'what do you do'
      ];
      final containsIrrelevant = irrelevantKeywords.any((keyword) => lower.contains(keyword));
      if (containsIrrelevant && service == null) {
        action = 'irrelevant';
      }
    }

    // ── Language Detection ────────────────────────────────────────────────────
    // Roman Urdu markers: common words that appear in Roman Urdu but not English
    final romanUrduMarkers = [
      'chahiye', 'wala', 'wali', 'baje', 'subha', 'subah', 'raat', 'shaam',
      'mujhe', 'aapko', 'mera', 'tera', 'karo', 'nahi', 'hai', 'hain',
      'kal', 'aaj', 'abhi', 'kabhi', 'theek', 'shukriya', 'maafi',
      'dopehar', 'mazdoor', 'bijli', 'paani', 'ustaad', 'gaari',
      'barhai', 'padhai', 'bhi', 'kar', 'kya', 'koi', 'ap',
    ];
    final isRomanUrdu = romanUrduMarkers.any((m) => lower.contains(m));
    final language = isRomanUrdu ? 'roman_urdu' : 'english';

    return {
      'service': service,
      'location': location,
      'day': day,
      'time': time,
      'phone': phone,
      'action': action,
      'language': language,
    };
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Quote Generation
  // ────────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> generateQuote(Worker worker, String day) {
    final base = worker.hourlyRate;
    final surge = (day == 'Today') ? (base * 0.20) : 0.0;
    final platformFee = (base + surge) * 0.05;
    final total = base + surge + platformFee;

    return {
      'base': base,
      'surge': surge,
      'platformFee': platformFee,
      'total': total,
    };
  }
}
