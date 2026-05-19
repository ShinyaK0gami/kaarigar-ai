import 'dart:math';

class Worker {
  final String id;
  final String name;
  final String occupation;
  final String location;
  final String availableTime;
  final double rating;
  final double hourlyRate;
  final double reliabilityScore;
  final String phone;

  Worker({
    required this.id,
    required this.name,
    required this.occupation,
    required this.location,
    required this.availableTime,
    required this.rating,
    required this.hourlyRate,
    required this.reliabilityScore,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'occupation': occupation,
      'location': location,
      'availableTime': availableTime,
      'rating': rating,
      'hourlyRate': hourlyRate,
      'reliabilityScore': reliabilityScore,
      'phone': phone,
    };
  }

  factory Worker.fromMap(Map<String, dynamic> map) {
    return Worker(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      occupation: map['occupation'] ?? '',
      location: map['location'] ?? '',
      availableTime: map['availableTime'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      hourlyRate: (map['hourlyRate'] as num?)?.toDouble() ?? 0.0,
      reliabilityScore: (map['reliabilityScore'] as num?)?.toDouble() ?? 0.0,
      phone: map['phone'] ?? '',
    );
  }

  @override
  String toString() =>
      '$name ($occupation) - $location [Time: $availableTime, Phone: $phone] ★$rating';
}

// ─────────────────────────────────────────────────────────────────────────────
// Comprehensive Karachi location database
// Source: Karachi Towns & Sub-regions (UC-level)
// ─────────────────────────────────────────────────────────────────────────────
List<Worker> _generateMockWorkers() {
  final locations = [
    // ── Karachi Central ──────────────────────────────────────────────────────
    'Liaquatabad',
    'North Nazimabad',
    'Frontier Colony',
    'New Karachi',
    'Banaras Town',
    'Gulberg',
    'Buffer Zone',
    'Husainabad',

    // ── Karachi East ─────────────────────────────────────────────────────────
    'Gulshan-e-Iqbal',
    'Gulistan-e-Johar',
    'Safoora Goth',
    'Shah Faisal Colony',
    'Jamshed Town',
    'Bahadurabad',
    'Soldier Bazaar',
    'Garden',
    'Landhi',
    'Korangi Industrial Area',
    'Malir',
    'Malir Cantonment',

    // ── Karachi South ────────────────────────────────────────────────────────
    'Saddar',
    'Burns Road',
    'Bund Bazaar',
    'Lyari',
    'Ranchhore Lines',
    'Civil Lines',
    'Frere Hall',
    'Clifton',
    'Boat Basin',
    'Sea View',
    'Defence Phase 1',
    'Defence Phase 2',
    'Defence Phase 4',
    'Defence Phase 6',
    'Defence Phase 8',
    'Khayaban-e-Ittehad',

    // ── Karachi West ─────────────────────────────────────────────────────────
    'SITE',
    'Orangi Town',
    'Qasba Colony',
    'Baldia Town',
    'Metroville',
    'Harbour Front',

    // ── Korangi ──────────────────────────────────────────────────────────────
    'Korangi',
    'Landhi Colony',

    // ── Malir / Bin Qasim ────────────────────────────────────────────────────
    'Gulshan-e-Hadeed',
    'Bin Qasim',

    // ── Legacy / Landmark areas ───────────────────────────────────────────────
    'I.I Chundrigar Road',
    'Shahrah-e-Faisal',
    'Mazar-e-Quaid',
    'Port Grand',
    'Hawksbay',
    'Sandspit Beach',
    'North Karachi',
  ];

  final occupations = [
    'Electrician',
    'Plumber',
    'Mechanic',
    'Welder',
    'Tutor',
    'Rider',
    'AC Technician',
    'Beautician',
    'Carpenter',
    'Labourer',
  ];

  final maleNames = [
    'Ali', 'Zain', 'Hassan', 'Kamran', 'Usman', 'Bilal', 'Imran',
    'Tariq', 'Naveed', 'Shahid', 'Kashif', 'Raza', 'Omar', 'Farhan',
    'Saqib', 'Adeel', 'Waqar', 'Junaid', 'Asim', 'Danish',
    'Faisal', 'Hamza', 'Irfan', 'Javed', 'Khalid',
  ];

  final femaleNames = [
    'Fatima', 'Ayesha', 'Sana', 'Nida', 'Sadia', 'Hira', 'Maira',
    'Zara', 'Amna', 'Nadia',
  ];

  final surnames = [
    'Khan', 'Ahmed', 'Ali', 'Sheikh', 'Malik', 'Hussain', 'Ansari',
    'Qureshi', 'Siddiqui', 'Mirza', 'Bhutto', 'Rajput', 'Baig', 'Rana',
  ];

  // Occupation-specific hourly rate ranges (PKR)
  final rateRanges = <String, List<int>>{
    'Electrician':    [500, 1500],
    'Plumber':        [400, 1200],
    'Mechanic':       [600, 2000],
    'Welder':         [700, 1800],
    'Tutor':          [500, 2500],
    'Rider':          [300, 800],
    'AC Technician':  [800, 2500],
    'Beautician':     [600, 2000],
    'Carpenter':      [500, 1600],
    'Labourer':       [300, 700],
  };

  final random = Random(42); // Fixed seed for reproducible data
  final List<Worker> workers = [];
  int idCounter = 1;

  for (final loc in locations) {
    for (final occ in occupations) {
      // 10 workers per occupation per location
      for (int i = 0; i < 10; i++) {
        // Pick name (beauticians are female-leaning; riders/labourers male-leaning)
        final String firstName;
        if (occ == 'Beautician') {
          firstName = random.nextDouble() < 0.8
              ? femaleNames[random.nextInt(femaleNames.length)]
              : maleNames[random.nextInt(maleNames.length)];
        } else {
          firstName = random.nextDouble() < 0.15
              ? femaleNames[random.nextInt(femaleNames.length)]
              : maleNames[random.nextInt(maleNames.length)];
        }
        final surname = surnames[random.nextInt(surnames.length)];
        final name = '$firstName $surname';

        // Realistic stats
        final rating = 3.5 + (random.nextDouble() * 1.5);
        final rel = 0.65 + (random.nextDouble() * 0.35);
        final range = rateRanges[occ]!;
        final rate = (range[0] + random.nextInt(range[1] - range[0])).toDouble();

        // Availability weighted (Anytime is rarer)
        final timeWeights = [0.3, 0.25, 0.3, 0.15]; // M, A, E, Any
        final rv = random.nextDouble();
        final String time;
        if (rv < timeWeights[0]) {
          time = 'Morning';
        } else if (rv < timeWeights[0] + timeWeights[1]) {
          time = 'Afternoon';
        } else if (rv < timeWeights[0] + timeWeights[1] + timeWeights[2]) {
          time = 'Evening';
        } else {
          time = 'Anytime';
        }

        final prefix = ['030', '031', '032', '033', '034'][random.nextInt(5)];
        final phone = '$prefix${1000000 + random.nextInt(8999999)}';

        workers.add(Worker(
          id: 'w$idCounter',
          name: name,
          occupation: occ,
          location: loc,
          availableTime: time,
          rating: double.parse(rating.toStringAsFixed(1)),
          hourlyRate: rate,
          reliabilityScore: double.parse(rel.toStringAsFixed(2)),
          phone: phone,
        ));

        idCounter++;
      }
    }
  }

  return workers;
}

final List<Worker> mockWorkers = _generateMockWorkers();
