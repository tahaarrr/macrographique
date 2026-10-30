import 'echantillon.dart';

class Rapport {
  final int? id;

  // En-tête document
  final String pvNumero; // PV N°
  final String dateReception; // Date de Réception d'échantillon
  final String dateEmission; // Date d'émission du Rapport
  final String dateEssai; // Date d'essai

  // Type de rapport : 'prestation' | 'commande_interne'
  final String typeRapport;

  // Informations client / essai (PRESTATION)
  final String nomClient;
  final String coordonneesClient;
  final String dimensions;
  final String nuance;
  final String nWps;
  final String nPqr;
  final String methodeEssai;
  final int nbEchantillons;
  final String methodeEchantillonnage;
  final String specificationEssai;
  final String projet;

  // Constat macrographique
  final String observation;

  // Tableau de signatures (colonnes dynamiques - PRESTATION)
  final String dateSignature;
  final String laboratoire; // ex: LABORATOIRE EEM / EM
  final String sigCol1Value; // Nom du signataire laboratoire
  // Colonne 2 (ex: Nom Client / Représentant client)
  final String sigCol2Header;
  final String sigCol2Value;
  // Colonne 3 (ex: COSIDER / Inspecteur)
  final String sigCol3Header;
  final String sigCol3Value;
  // Colonne 4 (ex: ARH / Tierce Partie)
  final String sigCol4Header;
  final String sigCol4Value;

  // ──────────────────────────────────────────────────────────────
  // COMMANDE INTERNE — Champs spécifiques
  // ──────────────────────────────────────────────────────────────

  // Identification CMD INTERNE
  final String demandeur;          // ex: Client / Service Demandeur
  final String nCommandeInterne;   // ex: 23/164/SIG
  final String designationSoudure; // ex: Angle bout à bout
  final String dateSoudage;        // ex: 12/03/2024
  // Soudage & Assemblage
  final String procedeSoudage;     // ex: SAWH, 141 (TIG)...
  final String metalApport;        // ex: E 8018 -G H4, ER70S-6...
  final String positionSoudage;    // ex: 5G, 6G, PA (1G)...
  final String nJoint;             // ex: Joint W-01...
  final String traitementThermique; // ex: Brut de soudage, PWHT 620°C ± 10°C (1h)...
  final String soudeurCode;        // ex: S001

  // Paramètres de soudage — format "passe;procede;diametre;courant;tension;vitesse;polarite;nuance"
  final String paramPenetration;
  final String paramRemplissage;
  final String paramFinition;

  // Examen macrographique CMD INTERNE
  final String attaqueChimique;  // ex: Nital 5%
  final String materielUtilise;  // ex: Tronçonneuse, polisseuse

  // Signatures CMD INTERNE (3 colonnes)
  final String sigInterneOperateur;    // Opérateur — Nom & Prénom
  final String sigInterneVerificateur; // Vérifié par (L.N.C) — Nom & Prénom
  final String sigInterneChef;         // Chef de Laboratoire — Nom & Prénom

  final int photosPerRow;        // 2 or 4 photos per row (prestation only)
  final int photoHeightPdf;      // Photo height in PDF (px), default 140
  final String customFieldsJson; // JSON of custom fields added dynamically per section

  final String createdAt;

  final List<Echantillon> echantillons;

  bool get isCommandeInterne => typeRapport == 'commande_interne';

  /// Nom de fichier par défaut pour l'export et téléchargement PDF
  /// Format commande interne : PV {pv} Lot {lot} Tube N {tube} {dimensions} {nuance} {client}
  /// Exemple : PV 1 Lot 01 Tube N 2005 711.2x9.50mm X70M Sonelgaz
  String get defaultPdfFileName {
    final parts = <String>[];

    // 1. PV N° (ex: "PV 1" ou "PV 01")
    if (pvNumero.trim().isNotEmpty) {
      final pv = pvNumero.trim().replaceAll('/', '-');
      if (pv.toUpperCase().startsWith('PV')) {
        parts.add(pv);
      } else {
        parts.add('PV $pv');
      }
    }

    if (isCommandeInterne) {
      // 2. Num Lot (ex: "Lot 01")
      final lotList = echantillons
          .map((e) => e.typeLot.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      if (lotList.isNotEmpty) {
        final formattedLots = lotList.map((lot) {
          final upper = lot.toUpperCase();
          if (upper.startsWith('LOT')) {
            return lot;
          }
          return 'Lot $lot';
        }).join('-');
        parts.add(formattedLots);
      }

      // 3. Num Tube (ex: "Tube N 2005")
      final tubeList = echantillons
          .map((e) => e.nTube.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      if (tubeList.isNotEmpty) {
        final formattedTubes = tubeList.map((tube) {
          final upper = tube.toUpperCase();
          if (upper.startsWith('TUBE N ') || upper.startsWith('TUBE N°') || upper.startsWith('TUBE N.')) {
            return tube;
          } else if (upper.startsWith('TUBE ')) {
            final remainder = tube.substring(5).trim();
            if (remainder.toUpperCase().startsWith('N ') || remainder.toUpperCase().startsWith('N°') || remainder.toUpperCase().startsWith('N.')) {
              return tube;
            }
            return 'Tube N $remainder';
          } else if (upper.startsWith('N°') || upper.startsWith('N ') || upper.startsWith('N.')) {
            return 'Tube $tube';
          } else {
            return 'Tube N $tube';
          }
        }).join('-');
        parts.add(formattedTubes);
      }

      // 4. Dimension (ex: "711.2x9.50mm")
      String dim = dimensions.trim();
      if (dim.isEmpty && echantillons.isNotEmpty) {
        final ech = echantillons.first;
        if (ech.diametreTube.isNotEmpty && ech.epNominale.isNotEmpty) {
          dim = '${ech.diametreTube}x${ech.epNominale}mm';
        } else if (ech.diametreTube.isNotEmpty) {
          dim = ech.diametreTube;
        }
      }
      if (dim.isNotEmpty) {
        parts.add(dim);
      }

      // 5. Nuance (ex: "X70M")
      String nua = nuance.trim();
      if (nua.isEmpty && echantillons.isNotEmpty) {
        final ech = echantillons.first;
        if (ech.metalNuance.isNotEmpty) {
          nua = ech.metalNuance.trim();
        }
      }
      if (nua.isNotEmpty) {
        parts.add(nua);
      }

      // 6. Client (ex: "Sonelgaz")
      final client = nomClient.trim().isNotEmpty ? nomClient.trim() : demandeur.trim();
      if (client.isNotEmpty) {
        parts.add(client);
      }
    } else {
      // Prestation mode
      if (dimensions.trim().isNotEmpty) {
        parts.add(dimensions.trim());
      }
      if (nuance.trim().isNotEmpty) {
        parts.add(nuance.trim());
      }
      if (nomClient.trim().isNotEmpty) {
        parts.add(nomClient.trim());
      }
    }

    if (parts.isNotEmpty) {
      final name = parts.join(' ');
      return name
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    return 'Rapport_${pvNumero.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')}'.trim();
  }

  Rapport({
    this.id,
    required this.pvNumero,
    required this.dateReception,
    required this.dateEmission,
    required this.dateEssai,
    this.typeRapport = 'prestation',
    required this.nomClient,
    required this.coordonneesClient,
    required this.dimensions,
    required this.nuance,
    required this.nWps,
    required this.nPqr,
    required this.methodeEssai,
    required this.nbEchantillons,
    required this.methodeEchantillonnage,
    required this.specificationEssai,
    required this.projet,
    this.observation =
        "L'examen macrographique a relevé une fusion complète et une bonne interpénétration des passes de soudure.",
    required this.dateSignature,
    this.laboratoire = '',
    this.sigCol1Value = '',
    this.sigCol2Header = 'Nom Client / Représentant',
    this.sigCol2Value = '',
    this.sigCol3Header = 'Représentant Cosider',
    this.sigCol3Value = '',
    this.sigCol4Header = 'Tierce Partie / Autorités',
    this.sigCol4Value = '/',
    // CMD INTERNE fields
    this.demandeur = '',
    this.nCommandeInterne = '',
    this.designationSoudure = '',
    this.dateSoudage = '',
    this.procedeSoudage = '',
    this.metalApport = '',
    this.positionSoudage = '',
    this.nJoint = '',
    this.traitementThermique = '',
    this.soudeurCode = '',
    this.paramPenetration = ';;;;;;;',
    this.paramRemplissage = ';;;;;;;',
    this.paramFinition = ';;;;;;;',
    this.attaqueChimique = '',
    this.materielUtilise = '',
    this.sigInterneOperateur = '',
    this.sigInterneVerificateur = '',
    this.sigInterneChef = '',
    this.photosPerRow = 2,
    this.photoHeightPdf = 140,
    this.customFieldsJson = '{}',
    required this.createdAt,
    this.echantillons = const [],
  });

  Rapport copyWith({
    int? id,
    String? pvNumero,
    String? dateReception,
    String? dateEmission,
    String? dateEssai,
    String? typeRapport,
    String? nomClient,
    String? coordonneesClient,
    String? dimensions,
    String? nuance,
    String? nWps,
    String? nPqr,
    String? methodeEssai,
    int? nbEchantillons,
    String? methodeEchantillonnage,
    String? specificationEssai,
    String? projet,
    String? observation,
    String? dateSignature,
    String? laboratoire,
    String? sigCol1Value,
    String? sigCol2Header,
    String? sigCol2Value,
    String? sigCol3Header,
    String? sigCol3Value,
    String? sigCol4Header,
    String? sigCol4Value,
    String? demandeur,
    String? nCommandeInterne,
    String? designationSoudure,
    String? dateSoudage,
    String? procedeSoudage,
    String? metalApport,
    String? positionSoudage,
    String? nJoint,
    String? traitementThermique,
    String? soudeurCode,
    String? paramPenetration,
    String? paramRemplissage,
    String? paramFinition,
    String? attaqueChimique,
    String? materielUtilise,
    String? sigInterneOperateur,
    String? sigInterneVerificateur,
    String? sigInterneChef,
    int? photosPerRow,
    int? photoHeightPdf,
    String? customFieldsJson,
    String? createdAt,
    List<Echantillon>? echantillons,
  }) {
    return Rapport(
      id: id ?? this.id,
      pvNumero: pvNumero ?? this.pvNumero,
      dateReception: dateReception ?? this.dateReception,
      dateEmission: dateEmission ?? this.dateEmission,
      dateEssai: dateEssai ?? this.dateEssai,
      typeRapport: typeRapport ?? this.typeRapport,
      nomClient: nomClient ?? this.nomClient,
      coordonneesClient: coordonneesClient ?? this.coordonneesClient,
      dimensions: dimensions ?? this.dimensions,
      nuance: nuance ?? this.nuance,
      nWps: nWps ?? this.nWps,
      nPqr: nPqr ?? this.nPqr,
      methodeEssai: methodeEssai ?? this.methodeEssai,
      nbEchantillons: nbEchantillons ?? this.nbEchantillons,
      methodeEchantillonnage:
          methodeEchantillonnage ?? this.methodeEchantillonnage,
      specificationEssai: specificationEssai ?? this.specificationEssai,
      projet: projet ?? this.projet,
      observation: observation ?? this.observation,
      dateSignature: dateSignature ?? this.dateSignature,
      laboratoire: laboratoire ?? this.laboratoire,
      sigCol1Value: sigCol1Value ?? this.sigCol1Value,
      sigCol2Header: sigCol2Header ?? this.sigCol2Header,
      sigCol2Value: sigCol2Value ?? this.sigCol2Value,
      sigCol3Header: sigCol3Header ?? this.sigCol3Header,
      sigCol3Value: sigCol3Value ?? this.sigCol3Value,
      sigCol4Header: sigCol4Header ?? this.sigCol4Header,
      sigCol4Value: sigCol4Value ?? this.sigCol4Value,
      demandeur: demandeur ?? this.demandeur,
      nCommandeInterne: nCommandeInterne ?? this.nCommandeInterne,
      designationSoudure: designationSoudure ?? this.designationSoudure,
      dateSoudage: dateSoudage ?? this.dateSoudage,
      procedeSoudage: procedeSoudage ?? this.procedeSoudage,
      metalApport: metalApport ?? this.metalApport,
      positionSoudage: positionSoudage ?? this.positionSoudage,
      nJoint: nJoint ?? this.nJoint,
      traitementThermique: traitementThermique ?? this.traitementThermique,
      soudeurCode: soudeurCode ?? this.soudeurCode,
      paramPenetration: paramPenetration ?? this.paramPenetration,
      paramRemplissage: paramRemplissage ?? this.paramRemplissage,
      paramFinition: paramFinition ?? this.paramFinition,
      attaqueChimique: attaqueChimique ?? this.attaqueChimique,
      materielUtilise: materielUtilise ?? this.materielUtilise,
      sigInterneOperateur: sigInterneOperateur ?? this.sigInterneOperateur,
      sigInterneVerificateur: sigInterneVerificateur ?? this.sigInterneVerificateur,
      sigInterneChef: sigInterneChef ?? this.sigInterneChef,
      photosPerRow: photosPerRow ?? this.photosPerRow,
      photoHeightPdf: photoHeightPdf ?? this.photoHeightPdf,
      customFieldsJson: customFieldsJson ?? this.customFieldsJson,
      createdAt: createdAt ?? this.createdAt,
      echantillons: echantillons ?? this.echantillons,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pv_numero': pvNumero,
      'date_reception': dateReception,
      'date_emission': dateEmission,
      'date_essai': dateEssai,
      'type_rapport': typeRapport,
      'nom_client': nomClient,
      'coordonnees_client': coordonneesClient,
      'dimensions': dimensions,
      'nuance': nuance,
      'n_wps': nWps,
      'n_pqr': nPqr,
      'methode_essai': methodeEssai,
      'nb_echantillons': nbEchantillons,
      'methode_echantillonnage': methodeEchantillonnage,
      'specification_essai': specificationEssai,
      'projet': projet,
      'observation': observation,
      'date_signature': dateSignature,
      'laboratoire': laboratoire,
      'sig_col1_value': sigCol1Value,
      'sig_col2_header': sigCol2Header,
      'sig_col2_value': sigCol2Value,
      'sig_col3_header': sigCol3Header,
      'sig_col3_value': sigCol3Value,
      'sig_col4_header': sigCol4Header,
      'sig_col4_value': sigCol4Value,
      'demandeur': demandeur,
      'n_commande_interne': nCommandeInterne,
      'designation_soudure': designationSoudure,
      'date_soudage': dateSoudage,
      'procede_soudage': procedeSoudage,
      'metal_apport': metalApport,
      'position_soudage': positionSoudage,
      'n_joint': nJoint,
      'traitement_thermique': traitementThermique,
      'soudeur_code': soudeurCode,
      'param_penetration': paramPenetration,
      'param_remplissage': paramRemplissage,
      'param_finition': paramFinition,
      'attaque_chimique': attaqueChimique,
      'materiel_utilise': materielUtilise,
      'sig_interne_operateur': sigInterneOperateur,
      'sig_interne_verificateur': sigInterneVerificateur,
      'sig_interne_chef': sigInterneChef,
      'photos_per_row': photosPerRow,
      'photo_height_pdf': photoHeightPdf,
      'custom_fields_json': customFieldsJson,
      'created_at': createdAt,
    };
  }

  Map<String, dynamic> toMapWithEchantillons() {
    final map = toMap();
    map['echantillons'] = echantillons.map((e) => e.toMap()).toList();
    return map;
  }

  factory Rapport.fromMap(Map<String, dynamic> map,
      {List<Echantillon> echantillons = const []}) {
    return Rapport(
      id: map['id'] as int?,
      pvNumero: map['pv_numero'] as String? ?? '',
      dateReception: map['date_reception'] as String? ?? '',
      dateEmission: map['date_emission'] as String? ?? '',
      dateEssai: map['date_essai'] as String? ?? '',
      typeRapport: map['type_rapport'] as String? ?? 'prestation',
      nomClient: map['nom_client'] as String? ?? '',
      coordonneesClient: map['coordonnees_client'] as String? ?? '',
      dimensions: map['dimensions'] as String? ?? '',
      nuance: map['nuance'] as String? ?? '',
      nWps: map['n_wps'] as String? ?? '',
      nPqr: map['n_pqr'] as String? ?? '',
      methodeEssai: map['methode_essai'] as String? ?? '',
      nbEchantillons: map['nb_echantillons'] as int? ?? 0,
      methodeEchantillonnage: map['methode_echantillonnage'] as String? ?? '',
      specificationEssai: map['specification_essai'] as String? ?? '',
      projet: map['projet'] as String? ?? '',
      observation: map['observation'] as String? ?? '',
      dateSignature: map['date_signature'] as String? ?? '',
      laboratoire: map['laboratoire'] as String? ?? '',
      sigCol1Value: map['sig_col1_value'] as String? ?? '',
      sigCol2Header: map['sig_col2_header'] as String? ?? 'Nom Client / Représentant',
      sigCol2Value: map['sig_col2_value'] as String? ?? '',
      sigCol3Header: map['sig_col3_header'] as String? ?? 'Représentant Cosider',
      sigCol3Value: map['sig_col3_value'] as String? ?? '',
      sigCol4Header: map['sig_col4_header'] as String? ?? 'Tierce Partie / Autorités',
      sigCol4Value: map['sig_col4_value'] as String? ?? '/',
      demandeur: map['demandeur'] as String? ?? '',
      nCommandeInterne: map['n_commande_interne'] as String? ?? '',
      designationSoudure: map['designation_soudure'] as String? ?? '',
      dateSoudage: map['date_soudage'] as String? ?? '',
      procedeSoudage: map['procede_soudage'] as String? ?? '',
      metalApport: map['metal_apport'] as String? ?? '',
      positionSoudage: map['position_soudage'] as String? ?? '',
      nJoint: map['n_joint'] as String? ?? '',
      traitementThermique: map['traitement_thermique'] as String? ?? '',
      soudeurCode: map['soudeur_code'] as String? ?? '',
      paramPenetration: map['param_penetration'] as String? ?? ';;;;;;;',
      paramRemplissage: map['param_remplissage'] as String? ?? ';;;;;;;',
      paramFinition: map['param_finition'] as String? ?? ';;;;;;;',
      attaqueChimique: map['attaque_chimique'] as String? ?? '',
      materielUtilise: map['materiel_utilise'] as String? ?? '',
      sigInterneOperateur: map['sig_interne_operateur'] as String? ?? '',
      sigInterneVerificateur: map['sig_interne_verificateur'] as String? ?? '',
      sigInterneChef: map['sig_interne_chef'] as String? ?? '',
      photosPerRow: map['photos_per_row'] as int? ?? 2,
      photoHeightPdf: map['photo_height_pdf'] as int? ?? 140,
      customFieldsJson: map['custom_fields_json'] as String? ?? '{}',
      createdAt: map['created_at'] as String? ?? '',
      echantillons: echantillons,
    );
  }
}
