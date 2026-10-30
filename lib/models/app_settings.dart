class AppSettings {
  final String companyName; // ex: Laboratoire Métallurgie & CND
  final String uniteName; // ex: Département Contrôle Qualité
  final String labName; // ex: LABORATOIRE D'ESSAIS MÉCANIQUES & MACROGRAPHIE
  final String labAddress; // ex: Zone Industrielle - Laboratoire Central
  final String labLieu; // ex: Laboratoire Central (lieu d'exécution des essais)
  // Prestation doc version
  final String docRef; // ex: E10-P.LAB.02
  final String docVersion; // ex: 01
  final String docDate; // ex: 03/04/2024
  // Commande Interne doc version (séparé)
  final String docRefInterne;
  final String docVersionInterne;
  final String docDateInterne;
  final String footNote1;
  final String footNote2;
  final String defaultObservation;
  final String? logoPath; // chemin local du logo importé par l'utilisateur
  // 3 Cachets optionnels pour différents ingénieurs / responsables
  final String? cachet1Path;
  final String cachet1Name;
  final String? cachet2Path;
  final String cachet2Name;
  final String? cachet3Path;
  final String cachet3Name;

  // Rétrocompatibilité
  String? get cachetPath => cachet1Path;

  const AppSettings({
    this.companyName = 'LABORATOIRE DE MÉTALLURGIE & CND',
    this.uniteName = 'DÉPARTEMENT CONTRÔLE QUALITÉ',
    this.labName = "LABORATOIRE D'ESSAIS MÉCANIQUES & MACROGRAPHIE",
    this.labAddress = "Zone Industrielle - Laboratoire Central",
    this.labLieu = 'Laboratoire Central',
    this.docRef = 'PV-MACRO-01',
    this.docVersion = '01',
    this.docDate = '01/01/2026',
    this.docRefInterne = 'PV-MACRO-01',
    this.docVersionInterne = '01',
    this.docDateInterne = '01/01/2026',
    this.footNote1 =
        '1- Le responsable du laboratoire +le client ou représentant (tierce partie)  pour les essais de la production.',
    this.footNote2 =
        '2- le responsable du laboratoire +le client ou représentant (tierce partie) + les autorités  pour les essais de la qualification.',
    this.defaultObservation =
        "L'examen macrographique a relevé une fusion complète et une bonne interpénétration des passes de soudure.",
    this.logoPath,
    this.cachet1Path,
    this.cachet1Name = 'Ingénieur 1',
    this.cachet2Path,
    this.cachet2Name = 'Ingénieur 2',
    this.cachet3Path,
    this.cachet3Name = 'Ingénieur 3',
  });

  AppSettings copyWith({
    String? companyName,
    String? uniteName,
    String? labName,
    String? labAddress,
    String? labLieu,
    String? docRef,
    String? docVersion,
    String? docDate,
    String? docRefInterne,
    String? docVersionInterne,
    String? docDateInterne,
    String? footNote1,
    String? footNote2,
    String? defaultObservation,
    String? logoPath,
    String? cachet1Path,
    String? cachet1Name,
    String? cachet2Path,
    String? cachet2Name,
    String? cachet3Path,
    String? cachet3Name,
    bool clearLogo = false,
    bool clearCachet1 = false,
    bool clearCachet2 = false,
    bool clearCachet3 = false,
  }) {
    return AppSettings(
      companyName: companyName ?? this.companyName,
      uniteName: uniteName ?? this.uniteName,
      labName: labName ?? this.labName,
      labAddress: labAddress ?? this.labAddress,
      labLieu: labLieu ?? this.labLieu,
      docRef: docRef ?? this.docRef,
      docVersion: docVersion ?? this.docVersion,
      docDate: docDate ?? this.docDate,
      docRefInterne: docRefInterne ?? this.docRefInterne,
      docVersionInterne: docVersionInterne ?? this.docVersionInterne,
      docDateInterne: docDateInterne ?? this.docDateInterne,
      footNote1: footNote1 ?? this.footNote1,
      footNote2: footNote2 ?? this.footNote2,
      defaultObservation: defaultObservation ?? this.defaultObservation,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      cachet1Path: clearCachet1 ? null : (cachet1Path ?? this.cachet1Path),
      cachet1Name: cachet1Name ?? this.cachet1Name,
      cachet2Path: clearCachet2 ? null : (cachet2Path ?? this.cachet2Path),
      cachet2Name: cachet2Name ?? this.cachet2Name,
      cachet3Path: clearCachet3 ? null : (cachet3Path ?? this.cachet3Path),
      cachet3Name: cachet3Name ?? this.cachet3Name,
    );
  }

  Map<String, String> toMap() {
    return {
      'companyName': companyName,
      'uniteName': uniteName,
      'labName': labName,
      'labAddress': labAddress,
      'labLieu': labLieu,
      'docRef': docRef,
      'docVersion': docVersion,
      'docDate': docDate,
      'docRefInterne': docRefInterne,
      'docVersionInterne': docVersionInterne,
      'docDateInterne': docDateInterne,
      'footNote1': footNote1,
      'footNote2': footNote2,
      'defaultObservation': defaultObservation,
      'logoPath': logoPath ?? '',
      'cachet1Path': cachet1Path ?? '',
      'cachet1Name': cachet1Name,
      'cachet2Path': cachet2Path ?? '',
      'cachet2Name': cachet2Name,
      'cachet3Path': cachet3Path ?? '',
      'cachet3Name': cachet3Name,
      // Retrocompat
      'cachetPath': cachet1Path ?? '',
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    const d = AppSettings();
    final c1 = (map['cachet1Path']?.isNotEmpty ?? false)
        ? map['cachet1Path']
        : ((map['cachetPath']?.isNotEmpty ?? false) ? map['cachetPath'] : null);

    return AppSettings(
      companyName: (map['companyName']?.isNotEmpty ?? false) ? map['companyName']! : d.companyName,
      uniteName: (map['uniteName']?.isNotEmpty ?? false) ? map['uniteName']! : d.uniteName,
      labName: (map['labName']?.isNotEmpty ?? false) ? map['labName']! : d.labName,
      labAddress: (map['labAddress']?.isNotEmpty ?? false) ? map['labAddress']! : d.labAddress,
      labLieu: (map['labLieu']?.isNotEmpty ?? false) ? map['labLieu']! : d.labLieu,
      docRef: (map['docRef']?.isNotEmpty ?? false) ? map['docRef']! : d.docRef,
      docVersion: (map['docVersion']?.isNotEmpty ?? false) ? map['docVersion']! : d.docVersion,
      docDate: (map['docDate']?.isNotEmpty ?? false) ? map['docDate']! : d.docDate,
      docRefInterne: (map['docRefInterne']?.isNotEmpty ?? false) ? map['docRefInterne']! : d.docRefInterne,
      docVersionInterne: (map['docVersionInterne']?.isNotEmpty ?? false) ? map['docVersionInterne']! : d.docVersionInterne,
      docDateInterne: (map['docDateInterne']?.isNotEmpty ?? false) ? map['docDateInterne']! : d.docDateInterne,
      footNote1: (map['footNote1']?.isNotEmpty ?? false) ? map['footNote1']! : d.footNote1,
      footNote2: (map['footNote2']?.isNotEmpty ?? false) ? map['footNote2']! : d.footNote2,
      defaultObservation: (map['defaultObservation']?.isNotEmpty ?? false)
          ? map['defaultObservation']!
          : d.defaultObservation,
      logoPath: (map['logoPath']?.isNotEmpty ?? false) ? map['logoPath'] : null,
      cachet1Path: c1,
      cachet1Name: (map['cachet1Name']?.isNotEmpty ?? false) ? map['cachet1Name']! : d.cachet1Name,
      cachet2Path: (map['cachet2Path']?.isNotEmpty ?? false) ? map['cachet2Path'] : null,
      cachet2Name: (map['cachet2Name']?.isNotEmpty ?? false) ? map['cachet2Name']! : d.cachet2Name,
      cachet3Path: (map['cachet3Path']?.isNotEmpty ?? false) ? map['cachet3Path'] : null,
      cachet3Name: (map['cachet3Name']?.isNotEmpty ?? false) ? map['cachet3Name']! : d.cachet3Name,
    );
  }
}
