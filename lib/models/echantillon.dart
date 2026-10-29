class Echantillon {
  final int? id;
  final int? rapportId;
  final int numero; // 1, 2, 3, 4...
  final String? photoPath; // chemin local de la photo macro-graphique
  final String observation; // constat par échantillon

  // --- PARAMETRES ---
  final String vitesse;
  final String uInt;
  final String uExt;
  final String iInt;
  final String iExt;
  final String filInt1;
  final String filInt2;
  final String flux;

  // --- PHOTO HEADER / FOOTER ---
  final String typeLot;
  final String grossissement;

  // --- METAL DE BASE ---
  final String metalNuance;
  final String nCoulee;
  final String nBobine;
  final String diametreTube;
  final String epNominale;
  final String epReel;
  final String fournisseur;

  // --- SOUDURE ---
  final String nTube;
  final String surepExt;
  final String surepInt;
  final String largeurExt;
  final String largeurInt;
  final String penetrationExt;
  final String penetrationInt;
  final String desaxage;
  final String interpenetration;

  // --- MESURES & TRACAGE (État persistant des repères & photo brute) ---
  final String? rawPhotoPath; // Chemin de la photo originale brute (non annotée)
  final String measureData;   // JSON des repères, poignées et guides pour modification ultérieure

  Echantillon({
    this.id,
    this.rapportId,
    required this.numero,
    this.photoPath,
    this.observation = '',
    this.vitesse = '',
    this.uInt = '',
    this.uExt = '',
    this.iInt = '',
    this.iExt = '',
    this.filInt1 = '',
    this.filInt2 = '',
    this.flux = '',
    this.typeLot = '',
    this.grossissement = '',
    this.metalNuance = '',
    this.nCoulee = '',
    this.nBobine = '',
    this.diametreTube = '',
    this.epNominale = '',
    this.epReel = '',
    this.fournisseur = '',
    this.nTube = '',
    this.surepExt = '',
    this.surepInt = '',
    this.largeurExt = '',
    this.largeurInt = '',
    this.penetrationExt = '',
    this.penetrationInt = '',
    this.desaxage = '',
    this.interpenetration = '',
    this.rawPhotoPath,
    this.measureData = '',
  });

  Echantillon copyWith({
    int? id,
    int? rapportId,
    int? numero,
    String? photoPath,
    String? observation,
    String? vitesse,
    String? uInt,
    String? uExt,
    String? iInt,
    String? iExt,
    String? filInt1,
    String? filInt2,
    String? flux,
    String? typeLot,
    String? grossissement,
    String? metalNuance,
    String? nCoulee,
    String? nBobine,
    String? diametreTube,
    String? epNominale,
    String? epReel,
    String? fournisseur,
    String? nTube,
    String? surepExt,
    String? surepInt,
    String? largeurExt,
    String? largeurInt,
    String? penetrationExt,
    String? penetrationInt,
    String? desaxage,
    String? interpenetration,
    String? rawPhotoPath,
    String? measureData,
    bool clearPhoto = false,
  }) {
    return Echantillon(
      id: id ?? this.id,
      rapportId: rapportId ?? this.rapportId,
      numero: numero ?? this.numero,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      observation: observation ?? this.observation,
      vitesse: vitesse ?? this.vitesse,
      uInt: uInt ?? this.uInt,
      uExt: uExt ?? this.uExt,
      iInt: iInt ?? this.iInt,
      iExt: iExt ?? this.iExt,
      filInt1: filInt1 ?? this.filInt1,
      filInt2: filInt2 ?? this.filInt2,
      flux: flux ?? this.flux,
      typeLot: typeLot ?? this.typeLot,
      grossissement: grossissement ?? this.grossissement,
      metalNuance: metalNuance ?? this.metalNuance,
      nCoulee: nCoulee ?? this.nCoulee,
      nBobine: nBobine ?? this.nBobine,
      diametreTube: diametreTube ?? this.diametreTube,
      epNominale: epNominale ?? this.epNominale,
      epReel: epReel ?? this.epReel,
      fournisseur: fournisseur ?? this.fournisseur,
      nTube: nTube ?? this.nTube,
      surepExt: surepExt ?? this.surepExt,
      surepInt: surepInt ?? this.surepInt,
      largeurExt: largeurExt ?? this.largeurExt,
      largeurInt: largeurInt ?? this.largeurInt,
      penetrationExt: penetrationExt ?? this.penetrationExt,
      penetrationInt: penetrationInt ?? this.penetrationInt,
      desaxage: desaxage ?? this.desaxage,
      interpenetration: interpenetration ?? this.interpenetration,
      rawPhotoPath: clearPhoto ? null : (rawPhotoPath ?? this.rawPhotoPath),
      measureData: measureData ?? this.measureData,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rapport_id': rapportId,
      'numero': numero,
      'photo_path': photoPath,
      'observation': observation,
      'vitesse': vitesse,
      'u_int': uInt,
      'u_ext': uExt,
      'i_int': iInt,
      'i_ext': iExt,
      'fil_int_1': filInt1,
      'fil_int_2': filInt2,
      'flux': flux,
      'type_lot': typeLot,
      'grossissement': grossissement,
      'metal_nuance': metalNuance,
      'n_coulee': nCoulee,
      'n_bobine': nBobine,
      'diametre_tube': diametreTube,
      'ep_nominale': epNominale,
      'ep_reel': epReel,
      'fournisseur': fournisseur,
      'n_tube': nTube,
      'surep_ext': surepExt,
      'surep_int': surepInt,
      'largeur_ext': largeurExt,
      'largeur_int': largeurInt,
      'penetration_ext': penetrationExt,
      'penetration_int': penetrationInt,
      'desaxage': desaxage,
      'interpenetration': interpenetration,
      'raw_photo_path': rawPhotoPath,
      'measure_data': measureData,
    };
  }

  factory Echantillon.fromMap(Map<String, dynamic> map) {
    return Echantillon(
      id: map['id'] as int?,
      rapportId: map['rapport_id'] as int?,
      numero: map['numero'] as int,
      photoPath: map['photo_path'] as String?,
      observation: map['observation'] as String? ?? '',
      vitesse: map['vitesse'] as String? ?? '',
      uInt: map['u_int'] as String? ?? '',
      uExt: map['u_ext'] as String? ?? '',
      iInt: map['i_int'] as String? ?? '',
      iExt: map['i_ext'] as String? ?? '',
      filInt1: map['fil_int_1'] as String? ?? '',
      filInt2: map['fil_int_2'] as String? ?? '',
      flux: map['flux'] as String? ?? '',
      typeLot: map['type_lot'] as String? ?? '',
      grossissement: map['grossissement'] as String? ?? '',
      metalNuance: map['metal_nuance'] as String? ?? '',
      nCoulee: map['n_coulee'] as String? ?? '',
      nBobine: map['n_bobine'] as String? ?? '',
      diametreTube: map['diametre_tube'] as String? ?? '',
      epNominale: map['ep_nominale'] as String? ?? '',
      epReel: map['ep_reel'] as String? ?? '',
      fournisseur: map['fournisseur'] as String? ?? '',
      nTube: map['n_tube'] as String? ?? '',
      surepExt: map['surep_ext'] as String? ?? '',
      surepInt: map['surep_int'] as String? ?? '',
      largeurExt: map['largeur_ext'] as String? ?? '',
      largeurInt: map['largeur_int'] as String? ?? '',
      penetrationExt: map['penetration_ext'] as String? ?? '',
      penetrationInt: map['penetration_int'] as String? ?? '',
      desaxage: map['desaxage'] as String? ?? '',
      interpenetration: map['interpenetration'] as String? ?? '',
      rawPhotoPath: map['raw_photo_path'] as String?,
      measureData: map['measure_data'] as String? ?? '',
    );
  }

  String get label => 'Echantillon ${numero.toString().padLeft(2, '0')}';
}
