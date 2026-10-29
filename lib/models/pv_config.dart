class PvFieldConfig {
  // ── 1. En-tête & Informations Générales ──
  final bool showPvNumero; // N° PV
  final bool showDateEmission; // Date Émission
  final bool showDateReception; // Date Réception
  final bool showDateEssai; // Date d'Essai
  final bool showLogo;
  final bool showCompanyHeader; // Nom Entreprise & Unité
  final bool showLabInfo; // Nom, Adresse & Lieu Laboratoire
  final bool showDocMeta; // Réf Doc, Version, Date Doc
  final bool showDatesBlock; // Legacy / Master

  // ── 2. Tableau des Caractéristiques de l'Essai (Client & Tube) ──
  final bool showNomClient;
  final bool showCoordonneesClient;
  final bool showDimensions;
  final bool showNuance;
  final bool showNWps;
  final bool showNPqr;
  final bool showMethodeEssai;
  final bool showNbEchantillons;
  final bool showMethodeEchantillonnage;
  final bool showSpecificationEssai;
  final bool showProjet;

  // ── 2b. Spécifications Commande Interne ──
  final bool showDemandeur;
  final bool showNCommandeInterne;
  final bool showDesignationSoudure;
  final bool showDateSoudage;
  final bool showAttaqueChimique;
  final bool showMaterielUtilise;
  final bool showSoudeurCode;

  // ── 2c. Soudage & Assemblage ──
  final bool showSectionSoudage;
  final bool showProcedeSoudage;
  final bool showMetalApport;
  final bool showPositionSoudage;
  final bool showNJoint;
  final bool showTraitementThermique;

  // ── 3. Tableau Paramètres de Soudage (Par échantillon) ──
  final bool showTableParametres;
  final bool showParamVitesse;
  final bool showParamTension;
  final bool showParamCourant;
  final bool showParamFils;
  final bool showParamFlux;

  // ── 4. Tableau Métal de Base (Par échantillon) ──
  final bool showTableMetalBase;
  final bool showMetalNuance;
  final bool showNCoulee;
  final bool showNBobine;
  final bool showDiametreTube;
  final bool showEpNominale;
  final bool showEpReel;
  final bool showEpSurPhoto;
  final bool showFournisseur;

  // ── 5. Tableau Géométrie & Soudure (Par échantillon) ──
  final bool showTableSoudure;
  final bool showTypeLot;
  final bool showGrossissement;
  final bool showNTube;
  final bool showSurepaisseur;
  final bool showLargeur;
  final bool showPenetration;
  final bool showDesaxage;
  final bool showInterpenetration;

  // ── 6. Pied de Page & Clôture ──
  final bool showDisclaimer;
  final bool showSectionTitle; // "MACRO-GRAPHIQUE"
  final bool showObservation;
  final bool showSignatures;
  final bool showFootnotes;
  final bool showPageNumber;
  final int selectedCachet; // 0 = Aucun / Vide, 1 = Cachet 1, 2 = Cachet 2, 3 = Cachet 3

  bool get showCachet => selectedCachet > 0;

  // ── 7. Champs Personnalisés ──
  final bool showCustomFields; // Toggle global pour tous les champs ajoutés manuellement

  const PvFieldConfig({
    // En-tête & Dates
    this.showPvNumero = true,
    this.showDateEmission = true,
    this.showDateReception = true,
    this.showDateEssai = true,
    this.showLogo = true,
    this.showCompanyHeader = true,
    this.showLabInfo = true,
    this.showDocMeta = true,
    this.showDatesBlock = true,
    // Caractéristiques
    this.showNomClient = true,
    this.showCoordonneesClient = true,
    this.showDimensions = true,
    this.showNuance = true,
    this.showNWps = true,
    this.showNPqr = true,
    this.showMethodeEssai = true,
    this.showNbEchantillons = true,
    this.showMethodeEchantillonnage = true,
    this.showSpecificationEssai = true,
    this.showProjet = true,
    // Spécifications Commande Interne
    this.showDemandeur = true,
    this.showNCommandeInterne = true,
    this.showDesignationSoudure = true,
    this.showDateSoudage = true,
    this.showAttaqueChimique = true,
    this.showMaterielUtilise = true,
    this.showSoudeurCode = true,
    // Soudage & Assemblage
    this.showSectionSoudage = true,
    this.showProcedeSoudage = true,
    this.showMetalApport = true,
    this.showPositionSoudage = true,
    this.showNJoint = true,
    this.showTraitementThermique = true,
    // Paramètres
    this.showTableParametres = true,
    this.showParamVitesse = true,
    this.showParamTension = true,
    this.showParamCourant = true,
    this.showParamFils = true,
    this.showParamFlux = true,
    // Métal de Base
    this.showTableMetalBase = true,
    this.showMetalNuance = true,
    this.showNCoulee = true,
    this.showNBobine = true,
    this.showDiametreTube = true,
    this.showEpNominale = true,
    this.showEpReel = true,
    this.showEpSurPhoto = true,
    this.showFournisseur = true,
    // Soudure
    this.showTableSoudure = true,
    this.showTypeLot = true,
    this.showGrossissement = true,
    this.showNTube = true,
    this.showSurepaisseur = true,
    this.showLargeur = true,
    this.showPenetration = true,
    this.showDesaxage = true,
    this.showInterpenetration = true,
    // Pied de page
    this.showDisclaimer = true,
    this.showSectionTitle = true,
    this.showObservation = true,
    this.showSignatures = true,
    this.showFootnotes = true,
    this.showPageNumber = true,
    this.selectedCachet = 1,
    // Champs personnalisés
    this.showCustomFields = true,
  });

  PvFieldConfig copyWith({
    bool? showPvNumero,
    bool? showDateEmission,
    bool? showDateReception,
    bool? showDateEssai,
    bool? showLogo,
    bool? showCompanyHeader,
    bool? showLabInfo,
    bool? showDocMeta,
    bool? showDatesBlock,
    bool? showNomClient,
    bool? showCoordonneesClient,
    bool? showDimensions,
    bool? showNuance,
    bool? showNWps,
    bool? showNPqr,
    bool? showMethodeEssai,
    bool? showNbEchantillons,
    bool? showMethodeEchantillonnage,
    bool? showSpecificationEssai,
    bool? showProjet,
    bool? showDemandeur,
    bool? showNCommandeInterne,
    bool? showDesignationSoudure,
    bool? showDateSoudage,
    bool? showAttaqueChimique,
    bool? showMaterielUtilise,
    bool? showSoudeurCode,
    bool? showSectionSoudage,
    bool? showProcedeSoudage,
    bool? showMetalApport,
    bool? showPositionSoudage,
    bool? showNJoint,
    bool? showTraitementThermique,
    bool? showTableParametres,
    bool? showParamVitesse,
    bool? showParamTension,
    bool? showParamCourant,
    bool? showParamFils,
    bool? showParamFlux,
    bool? showTableMetalBase,
    bool? showMetalNuance,
    bool? showNCoulee,
    bool? showNBobine,
    bool? showDiametreTube,
    bool? showEpNominale,
    bool? showEpReel,
    bool? showEpSurPhoto,
    bool? showFournisseur,
    bool? showTableSoudure,
    bool? showTypeLot,
    bool? showGrossissement,
    bool? showNTube,
    bool? showSurepaisseur,
    bool? showLargeur,
    bool? showPenetration,
    bool? showDesaxage,
    bool? showInterpenetration,
    bool? showDisclaimer,
    bool? showSectionTitle,
    bool? showObservation,
    bool? showSignatures,
    bool? showFootnotes,
    bool? showPageNumber,
    int? selectedCachet,
    bool? showCustomFields,
  }) {
    return PvFieldConfig(
      showPvNumero: showPvNumero ?? this.showPvNumero,
      showDateEmission: showDateEmission ?? this.showDateEmission,
      showDateReception: showDateReception ?? this.showDateReception,
      showDateEssai: showDateEssai ?? this.showDateEssai,
      showLogo: showLogo ?? this.showLogo,
      showCompanyHeader: showCompanyHeader ?? this.showCompanyHeader,
      showLabInfo: showLabInfo ?? this.showLabInfo,
      showDocMeta: showDocMeta ?? this.showDocMeta,
      showDatesBlock: showDatesBlock ?? this.showDatesBlock,
      showNomClient: showNomClient ?? this.showNomClient,
      showCoordonneesClient: showCoordonneesClient ?? this.showCoordonneesClient,
      showDimensions: showDimensions ?? this.showDimensions,
      showNuance: showNuance ?? this.showNuance,
      showNWps: showNWps ?? this.showNWps,
      showNPqr: showNPqr ?? this.showNPqr,
      showMethodeEssai: showMethodeEssai ?? this.showMethodeEssai,
      showNbEchantillons: showNbEchantillons ?? this.showNbEchantillons,
      showMethodeEchantillonnage: showMethodeEchantillonnage ?? this.showMethodeEchantillonnage,
      showSpecificationEssai: showSpecificationEssai ?? this.showSpecificationEssai,
      showProjet: showProjet ?? this.showProjet,
      showDemandeur: showDemandeur ?? this.showDemandeur,
      showNCommandeInterne: showNCommandeInterne ?? this.showNCommandeInterne,
      showDesignationSoudure: showDesignationSoudure ?? this.showDesignationSoudure,
      showDateSoudage: showDateSoudage ?? this.showDateSoudage,
      showAttaqueChimique: showAttaqueChimique ?? this.showAttaqueChimique,
      showMaterielUtilise: showMaterielUtilise ?? this.showMaterielUtilise,
      showSoudeurCode: showSoudeurCode ?? this.showSoudeurCode,
      showSectionSoudage: showSectionSoudage ?? this.showSectionSoudage,
      showProcedeSoudage: showProcedeSoudage ?? this.showProcedeSoudage,
      showMetalApport: showMetalApport ?? this.showMetalApport,
      showPositionSoudage: showPositionSoudage ?? this.showPositionSoudage,
      showNJoint: showNJoint ?? this.showNJoint,
      showTraitementThermique: showTraitementThermique ?? this.showTraitementThermique,
      showTableParametres: showTableParametres ?? this.showTableParametres,
      showParamVitesse: showParamVitesse ?? this.showParamVitesse,
      showParamTension: showParamTension ?? this.showParamTension,
      showParamCourant: showParamCourant ?? this.showParamCourant,
      showParamFils: showParamFils ?? this.showParamFils,
      showParamFlux: showParamFlux ?? this.showParamFlux,
      showTableMetalBase: showTableMetalBase ?? this.showTableMetalBase,
      showMetalNuance: showMetalNuance ?? this.showMetalNuance,
      showNCoulee: showNCoulee ?? this.showNCoulee,
      showNBobine: showNBobine ?? this.showNBobine,
      showDiametreTube: showDiametreTube ?? this.showDiametreTube,
      showEpNominale: showEpNominale ?? this.showEpNominale,
      showEpReel: showEpReel ?? this.showEpReel,
      showEpSurPhoto: showEpSurPhoto ?? this.showEpSurPhoto,
      showFournisseur: showFournisseur ?? this.showFournisseur,
      showTableSoudure: showTableSoudure ?? this.showTableSoudure,
      showTypeLot: showTypeLot ?? this.showTypeLot,
      showGrossissement: showGrossissement ?? this.showGrossissement,
      showNTube: showNTube ?? this.showNTube,
      showSurepaisseur: showSurepaisseur ?? this.showSurepaisseur,
      showLargeur: showLargeur ?? this.showLargeur,
      showPenetration: showPenetration ?? this.showPenetration,
      showDesaxage: showDesaxage ?? this.showDesaxage,
      showInterpenetration: showInterpenetration ?? this.showInterpenetration,
      showDisclaimer: showDisclaimer ?? this.showDisclaimer,
      showSectionTitle: showSectionTitle ?? this.showSectionTitle,
      showObservation: showObservation ?? this.showObservation,
      showSignatures: showSignatures ?? this.showSignatures,
      showFootnotes: showFootnotes ?? this.showFootnotes,
      showPageNumber: showPageNumber ?? this.showPageNumber,
      selectedCachet: selectedCachet ?? this.selectedCachet,
      showCustomFields: showCustomFields ?? this.showCustomFields,
    );
  }

  Map<String, String> toMap() {
    return {
      'showPvNumero': showPvNumero.toString(),
      'showDateEmission': showDateEmission.toString(),
      'showDateReception': showDateReception.toString(),
      'showDateEssai': showDateEssai.toString(),
      'showLogo': showLogo.toString(),
      'showCompanyHeader': showCompanyHeader.toString(),
      'showLabInfo': showLabInfo.toString(),
      'showDocMeta': showDocMeta.toString(),
      'showDatesBlock': showDatesBlock.toString(),
      'showNomClient': showNomClient.toString(),
      'showCoordonneesClient': showCoordonneesClient.toString(),
      'showDimensions': showDimensions.toString(),
      'showNuance': showNuance.toString(),
      'showNWps': showNWps.toString(),
      'showNPqr': showNPqr.toString(),
      'showMethodeEssai': showMethodeEssai.toString(),
      'showNbEchantillons': showNbEchantillons.toString(),
      'showMethodeEchantillonnage': showMethodeEchantillonnage.toString(),
      'showSpecificationEssai': showSpecificationEssai.toString(),
      'showProjet': showProjet.toString(),
      'showDemandeur': showDemandeur.toString(),
      'showNCommandeInterne': showNCommandeInterne.toString(),
      'showDesignationSoudure': showDesignationSoudure.toString(),
      'showDateSoudage': showDateSoudage.toString(),
      'showAttaqueChimique': showAttaqueChimique.toString(),
      'showMaterielUtilise': showMaterielUtilise.toString(),
      'showSoudeurCode': showSoudeurCode.toString(),
      'showSectionSoudage': showSectionSoudage.toString(),
      'showProcedeSoudage': showProcedeSoudage.toString(),
      'showMetalApport': showMetalApport.toString(),
      'showPositionSoudage': showPositionSoudage.toString(),
      'showNJoint': showNJoint.toString(),
      'showTraitementThermique': showTraitementThermique.toString(),
      'showTableParametres': showTableParametres.toString(),
      'showParamVitesse': showParamVitesse.toString(),
      'showParamTension': showParamTension.toString(),
      'showParamCourant': showParamCourant.toString(),
      'showParamFils': showParamFils.toString(),
      'showParamFlux': showParamFlux.toString(),
      'showTableMetalBase': showTableMetalBase.toString(),
      'showMetalNuance': showMetalNuance.toString(),
      'showNCoulee': showNCoulee.toString(),
      'showNBobine': showNBobine.toString(),
      'showDiametreTube': showDiametreTube.toString(),
      'showEpNominale': showEpNominale.toString(),
      'showEpReel': showEpReel.toString(),
      'showEpSurPhoto': showEpSurPhoto.toString(),
      'showFournisseur': showFournisseur.toString(),
      'showTableSoudure': showTableSoudure.toString(),
      'showTypeLot': showTypeLot.toString(),
      'showGrossissement': showGrossissement.toString(),
      'showNTube': showNTube.toString(),
      'showSurepaisseur': showSurepaisseur.toString(),
      'showLargeur': showLargeur.toString(),
      'showPenetration': showPenetration.toString(),
      'showDesaxage': showDesaxage.toString(),
      'showInterpenetration': showInterpenetration.toString(),
      'showDisclaimer': showDisclaimer.toString(),
      'showSectionTitle': showSectionTitle.toString(),
      'showObservation': showObservation.toString(),
      'showSignatures': showSignatures.toString(),
      'showFootnotes': showFootnotes.toString(),
      'showPageNumber': showPageNumber.toString(),
      'selectedCachet': selectedCachet.toString(),
      'showCustomFields': showCustomFields.toString(),
    };
  }

  factory PvFieldConfig.fromMap(Map<String, dynamic> map) {
    bool parseBool(String key, bool defaultVal) {
      final val = map[key];
      if (val == null) return defaultVal;
      if (val is bool) return val;
      if (val is String) {
        if (val.toLowerCase() == 'true' || val == '1') return true;
        if (val.toLowerCase() == 'false' || val == '0') return false;
      }
      return defaultVal;
    }

    final datesFallback = parseBool('showDatesBlock', true);

    int parseCachet() {
      final v = map['selectedCachet'];
      if (v is int) return v;
      if (v != null) {
        final parsed = int.tryParse(v.toString());
        if (parsed != null) return parsed;
      }
      if (map['showCachet'] != null) {
        return parseBool('showCachet', true) ? 1 : 0;
      }
      return 1;
    }

    return PvFieldConfig(
      showPvNumero: parseBool('showPvNumero', datesFallback),
      showDateEmission: parseBool('showDateEmission', datesFallback),
      showDateReception: parseBool('showDateReception', datesFallback),
      showDateEssai: parseBool('showDateEssai', datesFallback),
      showLogo: parseBool('showLogo', true),
      showCompanyHeader: parseBool('showCompanyHeader', true),
      showLabInfo: parseBool('showLabInfo', true),
      showDocMeta: parseBool('showDocMeta', true),
      showDatesBlock: datesFallback,
      showNomClient: parseBool('showNomClient', true),
      showCoordonneesClient: parseBool('showCoordonneesClient', true),
      showDimensions: parseBool('showDimensions', true),
      showNuance: parseBool('showNuance', true),
      showNWps: parseBool('showNWps', true),
      showNPqr: parseBool('showNPqr', true),
      showMethodeEssai: parseBool('showMethodeEssai', true),
      showNbEchantillons: parseBool('showNbEchantillons', true),
      showMethodeEchantillonnage: parseBool('showMethodeEchantillonnage', true),
      showSpecificationEssai: parseBool('showSpecificationEssai', true),
      showProjet: parseBool('showProjet', true),
      showDemandeur: parseBool('showDemandeur', true),
      showNCommandeInterne: parseBool('showNCommandeInterne', true),
      showDesignationSoudure: parseBool('showDesignationSoudure', true),
      showDateSoudage: parseBool('showDateSoudage', true),
      showAttaqueChimique: parseBool('showAttaqueChimique', true),
      showMaterielUtilise: parseBool('showMaterielUtilise', true),
      showSoudeurCode: parseBool('showSoudeurCode', true),
      showSectionSoudage: parseBool('showSectionSoudage', true),
      showProcedeSoudage: parseBool('showProcedeSoudage', true),
      showMetalApport: parseBool('showMetalApport', true),
      showPositionSoudage: parseBool('showPositionSoudage', true),
      showNJoint: parseBool('showNJoint', true),
      showTraitementThermique: parseBool('showTraitementThermique', true),
      showTableParametres: parseBool('showTableParametres', true),
      showParamVitesse: parseBool('showParamVitesse', true),
      showParamTension: parseBool('showParamTension', true),
      showParamCourant: parseBool('showParamCourant', true),
      showParamFils: parseBool('showParamFils', true),
      showParamFlux: parseBool('showParamFlux', true),
      showTableMetalBase: parseBool('showTableMetalBase', true),
      showMetalNuance: parseBool('showMetalNuance', true),
      showNCoulee: parseBool('showNCoulee', true),
      showNBobine: parseBool('showNBobine', true),
      showDiametreTube: parseBool('showDiametreTube', true),
      showEpNominale: parseBool('showEpNominale', true),
      showEpReel: parseBool('showEpReel', true),
      showEpSurPhoto: parseBool('showEpSurPhoto', true),
      showFournisseur: parseBool('showFournisseur', true),
      showTableSoudure: parseBool('showTableSoudure', true),
      showTypeLot: parseBool('showTypeLot', true),
      showGrossissement: parseBool('showGrossissement', true),
      showNTube: parseBool('showNTube', true),
      showSurepaisseur: parseBool('showSurepaisseur', true),
      showLargeur: parseBool('showLargeur', true),
      showPenetration: parseBool('showPenetration', true),
      showDesaxage: parseBool('showDesaxage', true),
      showInterpenetration: parseBool('showInterpenetration', true),
      showDisclaimer: parseBool('showDisclaimer', true),
      showSectionTitle: parseBool('showSectionTitle', true),
      showObservation: parseBool('showObservation', true),
      showSignatures: parseBool('showSignatures', true),
      showFootnotes: parseBool('showFootnotes', true),
      showPageNumber: parseBool('showPageNumber', true),
      selectedCachet: parseCachet(),
      showCustomFields: parseBool('showCustomFields', true),
    );
  }

  /// Préréglage Complet (Tout activé)
  factory PvFieldConfig.full() => const PvFieldConfig();

  /// Préréglage Synthétique (Essentiel sans détails de paramètres étendus)
  factory PvFieldConfig.compact() {
    return const PvFieldConfig(
      showDocMeta: false,
      showCoordonneesClient: false,
      showNPqr: false,
      showMethodeEchantillonnage: false,
      showTableParametres: false,
      showFootnotes: false,
    );
  }
}
