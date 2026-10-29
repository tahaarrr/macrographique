class ClientModel {
  final String nomClient;
  final String coordonneesClient;
  final int nbRapports;
  final int totalEchantillons;
  final String? latestDate;
  final String? latestPvNumero;
  final String mainType; // 'prestation' | 'commande_interne'

  ClientModel({
    required this.nomClient,
    this.coordonneesClient = '',
    required this.nbRapports,
    required this.totalEchantillons,
    this.latestDate,
    this.latestPvNumero,
    this.mainType = 'prestation',
  });

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      nomClient: map['nom_client'] as String? ?? 'Client Inconnu',
      coordonneesClient: map['coordonnees_client'] as String? ?? '',
      nbRapports: map['nb_rapports'] as int? ?? 0,
      totalEchantillons: map['total_echantillons'] as int? ?? 0,
      latestDate: map['latest_date'] as String?,
      latestPvNumero: map['latest_pv'] as String?,
      mainType: map['main_type'] as String? ?? 'prestation',
    );
  }

  bool get isCommandeInterne => mainType == 'commande_interne';
}
