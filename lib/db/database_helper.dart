import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/client.dart';
import '../models/echantillon.dart';
import '../models/rapport.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Utiliser AppData pour un chemin stable (persiste après flutter clean)
    String dbPath;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final appSupportDir = await getApplicationSupportDirectory();
      dbPath = appSupportDir.path;
    } else {
      dbPath = await getDatabasesPath();
    }
    final path = join(dbPath, 'rapport_essai.db');

    return await openDatabase(
      path,
      version: 13,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        try {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
          await db.execute('PRAGMA cache_size = -64000');
          await db.execute('PRAGMA temp_store = MEMORY');
        } catch (_) {}
      },
      onOpen: (db) async {
        await _createIndexes(db);
        await _fixSonelgazClientTypes(db);
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE rapports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pv_numero TEXT NOT NULL,
            date_reception TEXT,
            date_emission TEXT,
            date_essai TEXT,
            type_rapport TEXT DEFAULT 'prestation',
            nom_client TEXT,
            coordonnees_client TEXT,
            dimensions TEXT,
            nuance TEXT,
            n_wps TEXT,
            n_pqr TEXT,
            methode_essai TEXT,
            nb_echantillons INTEGER,
            methode_echantillonnage TEXT,
            specification_essai TEXT,
            projet TEXT,
            observation TEXT,
            date_signature TEXT,
            laboratoire TEXT,
            sig_col1_value TEXT DEFAULT '',
            sig_col2_header TEXT DEFAULT 'Nom Client / Représentant',
            sig_col2_value TEXT DEFAULT '',
            sig_col3_header TEXT DEFAULT 'Représentant Cosider',
            sig_col3_value TEXT DEFAULT '',
            sig_col4_header TEXT DEFAULT 'Tierce Partie / Autorités',
            sig_col4_value TEXT DEFAULT '/',
            demandeur TEXT DEFAULT '',
            n_commande_interne TEXT DEFAULT '',
            designation_soudure TEXT DEFAULT '',
            date_soudage TEXT DEFAULT '',
            procede_soudage TEXT DEFAULT '',
            position_soudage TEXT DEFAULT '',
            metal_apport TEXT DEFAULT '',
            n_joint TEXT DEFAULT '',
            traitement_thermique TEXT DEFAULT '',
            soudeur_code TEXT DEFAULT '',
            param_penetration TEXT DEFAULT ';;;;;;;',
            param_remplissage TEXT DEFAULT ';;;;;;;',
            param_finition TEXT DEFAULT ';;;;;;;',
            attaque_chimique TEXT DEFAULT '',
            materiel_utilise TEXT DEFAULT '',
            sig_interne_operateur TEXT DEFAULT '',
            sig_interne_verificateur TEXT DEFAULT '',
            sig_interne_chef TEXT DEFAULT '',
            photos_per_row INTEGER DEFAULT 2,
            photo_height_pdf INTEGER DEFAULT 140,
            custom_fields_json TEXT DEFAULT '{}',
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE echantillons (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rapport_id INTEGER NOT NULL,
            numero INTEGER NOT NULL,
            photo_path TEXT,
            observation TEXT DEFAULT '',
            vitesse TEXT DEFAULT '0,9',
            u_int TEXT DEFAULT '32 V',
            u_ext TEXT DEFAULT '32 V',
            i_int TEXT DEFAULT '630 A',
            i_ext TEXT DEFAULT '780 A',
            fil_int_1 TEXT DEFAULT '(3,2mm) 200987',
            fil_int_2 TEXT DEFAULT '(4 mm) 200955',
            flux TEXT DEFAULT 'D1FX25376 P223',
            type_lot TEXT DEFAULT 'LOT 27',
            grossissement TEXT DEFAULT '1,8 FOIS',
            metal_nuance TEXT DEFAULT 'X 60',
            n_coulee TEXT DEFAULT '26302120',
            n_bobine TEXT DEFAULT '2630415233',
            diametre_tube TEXT DEFAULT '406',
            ep_nominale TEXT DEFAULT '11,10',
            ep_reel TEXT DEFAULT '11',
            fournisseur TEXT DEFAULT 'TOSYALI',
            n_tube TEXT DEFAULT '1345 G',
            surep_ext TEXT DEFAULT '1,66',
            surep_int TEXT DEFAULT '1,66',
            largeur_ext TEXT DEFAULT '15',
            largeur_int TEXT DEFAULT '12,77',
            penetration_ext TEXT DEFAULT '68,18',
            penetration_int TEXT DEFAULT '55,54',
            desaxage TEXT DEFAULT '0',
            interpenetration TEXT DEFAULT '2,22',
            raw_photo_path TEXT DEFAULT '',
            measure_data TEXT DEFAULT '',
            FOREIGN KEY (rapport_id) REFERENCES rapports (id) ON DELETE CASCADE
          )
        ''');

        await _seedInitialExamplesIfEmpty(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add observation column to existing echantillons table
          await db.execute(
            "ALTER TABLE echantillons ADD COLUMN observation TEXT DEFAULT ''",
          );
        }
        if (oldVersion < 3) {
          // Add dynamic signature columns to rapports table
          await db.execute("ALTER TABLE rapports ADD COLUMN sig_col2_header TEXT DEFAULT 'Nom Client / Représentant'");
          await db.execute("ALTER TABLE rapports ADD COLUMN sig_col2_value TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN sig_col3_header TEXT DEFAULT 'Représentant Cosider'");
          await db.execute("ALTER TABLE rapports ADD COLUMN sig_col3_value TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN sig_col4_header TEXT DEFAULT 'Tierce Partie / Autorités'");
          await db.execute("ALTER TABLE rapports ADD COLUMN sig_col4_value TEXT DEFAULT '/'");
        }
        if (oldVersion < 4) {
          // Add laboratoire signatory name
          await db.execute("ALTER TABLE rapports ADD COLUMN sig_col1_value TEXT DEFAULT ''");
        }
        if (oldVersion < 5) {
          // Add CMD INTERNE fields
          await db.execute("ALTER TABLE rapports ADD COLUMN type_rapport TEXT DEFAULT 'prestation'");
          await db.execute("ALTER TABLE rapports ADD COLUMN demandeur TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN n_commande_interne TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN designation_soudure TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN date_soudage TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN procede_soudage TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN position_soudage TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN soudeur_code TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN param_penetration TEXT DEFAULT ';;;;;;;'");
          await db.execute("ALTER TABLE rapports ADD COLUMN param_remplissage TEXT DEFAULT ';;;;;;;'");
          await db.execute("ALTER TABLE rapports ADD COLUMN param_finition TEXT DEFAULT ';;;;;;;'");
          await db.execute("ALTER TABLE rapports ADD COLUMN attaque_chimique TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN materiel_utilise TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN sig_interne_operateur TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN sig_interne_verificateur TEXT DEFAULT ''");
          await db.execute("ALTER TABLE rapports ADD COLUMN sig_interne_chef TEXT DEFAULT ''");
        }
        if (oldVersion < 6) {
          // Add dynamic sample fields — wrapped in try/catch to survive duplicate columns
          // (can happen if device had an intermediate build with partial migration)
          Future<void> safeAdd(String sql) async {
            try { await db.execute(sql); } catch (_) {}
          }
          await safeAdd("ALTER TABLE echantillons ADD COLUMN vitesse TEXT DEFAULT '0,9'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN u_int TEXT DEFAULT '32 V'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN u_ext TEXT DEFAULT '32 V'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN i_int TEXT DEFAULT '630 A'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN i_ext TEXT DEFAULT '780 A'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN fil_int_1 TEXT DEFAULT '(3,2mm) 200987'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN fil_int_2 TEXT DEFAULT '(4 mm) 200955'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN flux TEXT DEFAULT 'D1FX25376 P223'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN type_lot TEXT DEFAULT 'LOT 27'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN grossissement TEXT DEFAULT '1,8 FOIS'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN metal_nuance TEXT DEFAULT 'X 60'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN n_coulee TEXT DEFAULT '26302120'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN n_bobine TEXT DEFAULT '2630415233'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN diametre_tube TEXT DEFAULT '406'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN ep_nominale TEXT DEFAULT '11,10'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN ep_reel TEXT DEFAULT '11'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN fournisseur TEXT DEFAULT 'TOSYALI'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN n_tube TEXT DEFAULT '1345 G'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN surep_ext TEXT DEFAULT '1,66'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN surep_int TEXT DEFAULT '1,66'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN largeur_ext TEXT DEFAULT '15'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN largeur_int TEXT DEFAULT '12,77'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN penetration_ext TEXT DEFAULT '68,18'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN penetration_int TEXT DEFAULT '55,54'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN desaxage TEXT DEFAULT '0'");
          await safeAdd("ALTER TABLE echantillons ADD COLUMN interpenetration TEXT DEFAULT '2,22'");
        }
        if (oldVersion < 7) {
          Future<void> safeAdd7(String sql) async {
            try { await db.execute(sql); } catch (_) {}
          }
          await safeAdd7("ALTER TABLE rapports ADD COLUMN photos_per_row INTEGER DEFAULT 2");
          await safeAdd7("ALTER TABLE rapports ADD COLUMN photo_height_pdf INTEGER DEFAULT 140");
        }
        if (oldVersion < 11) {
          Future<void> safeAdd11(String sql) async {
            try { await db.execute(sql); } catch (_) {}
          }
          await safeAdd11("ALTER TABLE rapports ADD COLUMN metal_apport TEXT DEFAULT ''");
          await safeAdd11("ALTER TABLE rapports ADD COLUMN n_joint TEXT DEFAULT ''");
          await safeAdd11("ALTER TABLE rapports ADD COLUMN traitement_thermique TEXT DEFAULT ''");
        }
        if (oldVersion < 12) {
          Future<void> safeAdd12(String sql) async {
            try { await db.execute(sql); } catch (_) {}
          }
          await safeAdd12("ALTER TABLE rapports ADD COLUMN custom_fields_json TEXT DEFAULT '{}'");
        }
        if (oldVersion < 13) {
          Future<void> safeAdd13(String sql) async {
            try { await db.execute(sql); } catch (_) {}
          }
          await safeAdd13("ALTER TABLE echantillons ADD COLUMN raw_photo_path TEXT DEFAULT ''");
          await safeAdd13("ALTER TABLE echantillons ADD COLUMN measure_data TEXT DEFAULT ''");
        }
      },
    );
  }

  // ---------- RAPPORTS ----------

  Future<int> insertRapport(Rapport rapport) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      final rapportId = await txn.insert('rapports', rapport.toMap());
      for (final echantillon in rapport.echantillons) {
        await txn.insert(
          'echantillons',
          echantillon.copyWith(rapportId: rapportId).toMap()..remove('id'),
        );
      }
      return rapportId;
    });
  }

  Future<int> updateRapport(Rapport rapport) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      final count = await txn.update(
        'rapports',
        rapport.toMap(),
        where: 'id = ?',
        whereArgs: [rapport.id],
      );

      await txn.delete(
        'echantillons',
        where: 'rapport_id = ?',
        whereArgs: [rapport.id],
      );
      for (final echantillon in rapport.echantillons) {
        final map = echantillon.copyWith(rapportId: rapport.id).toMap();
        map.remove('id');
        await txn.insert('echantillons', map);
      }
      return count;
    });
  }

  Future<int> deleteRapport(int id) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      await txn.delete('echantillons', where: 'rapport_id = ?', whereArgs: [id]);
      return await txn.delete('rapports', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> deleteClient(String nomClient) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      final rows = await txn.query(
        'rapports',
        columns: ['id'],
        where: 'LOWER(nom_client) = ?',
        whereArgs: [nomClient.toLowerCase().trim()],
      );
      for (final r in rows) {
        final id = r['id'] as int;
        await txn.delete('echantillons', where: 'rapport_id = ?', whereArgs: [id]);
      }
      return await txn.delete(
        'rapports',
        where: 'LOWER(nom_client) = ?',
        whereArgs: [nomClient.toLowerCase().trim()],
      );
    });
  }

  Future<int> moveRapportsToClient(List<int> ids, String newClientName, {String? newAddress}) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final Map<String, dynamic> values = {
      'nom_client': newClientName.trim(),
    };
    if (newAddress != null && newAddress.trim().isNotEmpty) {
      values['coordonnees_client'] = newAddress.trim();
    }
    final inPlaceholders = List.filled(ids.length, '?').join(',');
    return await db.update(
      'rapports',
      values,
      where: 'id IN ($inPlaceholders)',
      whereArgs: ids,
    );
  }

  Future<int> moveRapportsToProject(List<int> ids, String newProjectName) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final inPlaceholders = List.filled(ids.length, '?').join(',');
    return await db.update(
      'rapports',
      {'projet': newProjectName.trim()},
      where: 'id IN ($inPlaceholders)',
      whereArgs: ids,
    );
  }

  /// Tri naturel des numéros de PV (ex: "01/2026", "02/2026", "03/2026"...)
  static int comparePvNumbers(String pvA, String pvB) {
    final reg = RegExp(r'(\d+)(?:\s*/\s*(\d+))?');
    final matchA = reg.firstMatch(pvA);
    final matchB = reg.firstMatch(pvB);

    if (matchA != null && matchB != null) {
      final numA = int.tryParse(matchA.group(1) ?? '') ?? 0;
      final yearA = int.tryParse(matchA.group(2) ?? '') ?? 0;
      final numB = int.tryParse(matchB.group(1) ?? '') ?? 0;
      final yearB = int.tryParse(matchB.group(2) ?? '') ?? 0;

      if (yearA != 0 && yearB != 0 && yearA != yearB) {
        return yearA.compareTo(yearB);
      }
      if (numA != numB) {
        return numA.compareTo(numB);
      }
    }
    return pvA.compareTo(pvB);
  }

  Future<int> updateClientType(String nomClient, String newType) async {
    final db = await database;
    return await db.update(
      'rapports',
      {'type_rapport': newType},
      where: 'LOWER(nom_client) = ?',
      whereArgs: [nomClient.toLowerCase().trim()],
    );
  }

  Future<void> _fixSonelgazClientTypes(Database db) async {
    try {
      await db.execute('''
        UPDATE rapports 
        SET type_rapport = 'commande_interne' 
        WHERE LOWER(nom_client) LIKE '%sonelgaz%' 
           OR LOWER(nom_client) LIKE '%sonalgaz%'
           OR LOWER(nom_client) LIKE '%transport gaz%'
      ''');
    } catch (_) {}
  }

  static Future<void> _createIndexes(Database db) async {
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_echantillons_rapport_id ON echantillons (rapport_id, numero)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rapports_nom_client ON rapports (nom_client)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rapports_pv_numero ON rapports (pv_numero)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rapports_type_client ON rapports (type_rapport, nom_client)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_rapports_projet ON rapports (projet)');
    } catch (_) {}
  }

  Future<List<Rapport>> getAllRapports() async {
    final db = await database;
    final rows = await db.query('rapports', orderBy: 'id DESC');
    if (rows.isEmpty) return [];

    // Optimisation N+1 : récupération de tous les échantillons en une seule requête indexée
    final echantillonRows = await db.query(
      'echantillons',
      orderBy: 'rapport_id ASC, numero ASC',
    );
    final Map<int, List<Echantillon>> echantillonsByRapport = {};
    for (final eRow in echantillonRows) {
      final rId = eRow['rapport_id'] as int;
      (echantillonsByRapport[rId] ??= []).add(Echantillon.fromMap(eRow));
    }

    final List<Rapport> rapports = [];
    for (final row in rows) {
      final rId = row['id'] as int;
      final echantillons = echantillonsByRapport[rId] ?? const [];
      rapports.add(Rapport.fromMap(row, echantillons: echantillons));
    }
    rapports.sort((a, b) => comparePvNumbers(a.pvNumero, b.pvNumero));
    return rapports;
  }

  Future<List<Rapport>> getRapportsForClient(String nomClient) async {
    final db = await database;
    final rows = await db.query(
      'rapports',
      where: 'LOWER(nom_client) = ?',
      whereArgs: [nomClient.toLowerCase().trim()],
      orderBy: 'id DESC',
    );
    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final echantillonRows = await db.query(
      'echantillons',
      where: 'rapport_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'rapport_id ASC, numero ASC',
    );

    final Map<int, List<Echantillon>> echantillonsByRapport = {};
    for (final eRow in echantillonRows) {
      final rId = eRow['rapport_id'] as int;
      (echantillonsByRapport[rId] ??= []).add(Echantillon.fromMap(eRow));
    }

    final List<Rapport> rapports = [];
    for (final row in rows) {
      final rId = row['id'] as int;
      final echantillons = echantillonsByRapport[rId] ?? const [];
      rapports.add(Rapport.fromMap(row, echantillons: echantillons));
    }
    rapports.sort((a, b) => comparePvNumbers(a.pvNumero, b.pvNumero));
    return rapports;
  }

  /// Returns the most recent rapport for a given client name (case-insensitive).
  /// Used to auto-fill client info fields when creating a new rapport.
  Future<Rapport?> getLatestRapportForClient(String nomClient) async {
    final db = await database;
    final rows = await db.query(
      'rapports',
      where: 'LOWER(nom_client) = ?',
      whereArgs: [nomClient.toLowerCase().trim()],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final echantillons = await _getEchantillonsForRapport(rows.first['id'] as int);
    return Rapport.fromMap(rows.first, echantillons: echantillons);
  }

  Future<Rapport?> getRapportById(int id) async {
    final db = await database;
    final rows = await db.query('rapports', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final echantillons = await _getEchantillonsForRapport(id);
    return Rapport.fromMap(rows.first, echantillons: echantillons);
  }

  Future<List<Echantillon>> _getEchantillonsForRapport(int rapportId) async {
    final db = await database;
    final rows = await db.query(
      'echantillons',
      where: 'rapport_id = ?',
      whereArgs: [rapportId],
      orderBy: 'numero ASC',
    );
    return rows.map((r) => Echantillon.fromMap(r)).toList();
  }

  // ---------- CLIENTS (DOSSIERS) ----------

  Future<List<ClientModel>> getAllClients() async {
    final db = await database;

    final rows = await db.rawQuery('''
      SELECT 
        nom_client,
        coordonnees_client,
        CASE 
          WHEN LOWER(nom_client) LIKE '%sonelgaz%' OR LOWER(nom_client) LIKE '%sonalgaz%' OR LOWER(nom_client) LIKE '%transport gaz%' THEN 'commande_interne'
          WHEN SUM(CASE WHEN type_rapport = 'commande_interne' THEN 1 ELSE 0 END) > 0 THEN 'commande_interne'
          ELSE 'prestation'
        END as main_type,
        COUNT(id) as nb_rapports,
        SUM(nb_echantillons) as total_echantillons,
        MAX(date_essai) as latest_date,
        MAX(pv_numero) as latest_pv
      FROM rapports
      WHERE nom_client IS NOT NULL AND TRIM(nom_client) != ''
      GROUP BY LOWER(TRIM(nom_client))
      ORDER BY nb_rapports DESC, nom_client ASC
    ''');

    return rows.map((r) => ClientModel.fromMap(r)).toList();
  }

  Future<void> _seedInitialExamplesIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM rapports'),
    );
    if (count != null && count > 0) return;

    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final now = DateTime.now().toIso8601String();

    // 1. Sonelgaz (Cmd Interne)
    final r1Id = await db.insert('rapports', {
      'pv_numero': '01/2026',
      'date_reception': today,
      'date_emission': today,
      'date_essai': today,
      'type_rapport': 'commande_interne',
      'nom_client': 'Sonelgaz',
      'coordonnees_client': 'Zone Industrielle Réghaia',
      'dimensions': '406 x 11,10 mm',
      'nuance': 'X 60',
      'n_wps': 'WPS-SIG-01',
      'n_pqr': 'PQR-SIG-01',
      'methode_essai': 'Examen Macrographique',
      'nb_echantillons': 1,
      'methode_echantillonnage': 'ISO15614-1',
      'specification_essai': 'ISO15614-1',
      'projet': 'Projet SIG / Réghaia',
      'observation': "L'examen macrographique a relevé une fusion complète et une bonne interpénétration des passes de soudure.",
      'date_signature': today,
      'laboratoire': 'L.N.C',
      'demandeur': 'Sonelgaz',
      'n_commande_interne': '23/164/SIG',
      'designation_soudure': 'Angle bout à bout',
      'date_soudage': today,
      'procede_soudage': 'TIG / MIG',
      'position_soudage': 'PA',
      'soudeur_code': 'S001',
      'param_penetration': 'Pénétration;TIG;3.2mm;180A;22V;12cm/min;DC+;Er70S6',
      'param_remplissage': 'Remplissage;MIG;1.2mm;240A;26V;25cm/min;DC+;Er70S6',
      'param_finition': 'Finition;MIG;1.2mm;220A;25V;20cm/min;DC+;Er70S6',
      'attaque_chimique': 'Nital 5%',
      'materiel_utilise': 'Tronçonneuse, polisseuse',
      'sig_interne_operateur': 'AYATI Tahar',
      'sig_interne_verificateur': 'L.N.C',
      'sig_interne_chef': 'Ingénieur Tahar',
      'created_at': now,
    });

    await db.insert('echantillons', {
      'rapport_id': r1Id,
      'numero': 1,
      'photo_path': null,
      'observation': "Fusion complète et bonne interpénétration.",
      'vitesse': '0,9',
      'u_int': '32 V',
      'u_ext': '32 V',
      'i_int': '630 A',
      'i_ext': '780 A',
      'fil_int_1': '(3,2mm) 200987',
      'fil_int_2': '(4 mm) 200955',
      'flux': 'D1FX25376 P223',
      'type_lot': 'LOT 27',
      'grossissement': '1,8 FOIS',
      'metal_nuance': 'X 60',
      'n_coulee': '26302120',
      'n_bobine': '2630415233',
      'diametre_tube': '406',
      'ep_nominale': '11,10',
      'ep_reel': '11',
      'fournisseur': 'TOSYALI',
      'n_tube': '1345 G',
      'surep_ext': '1,66',
      'surep_int': '1,66',
      'largeur_ext': '15',
      'largeur_int': '12,77',
      'penetration_ext': '68,18',
      'penetration_int': '55,54',
      'desaxage': '0',
      'interpenetration': '2,22',
    });

    // 2. Inspection Power (Prestation)
    final r2Id = await db.insert('rapports', {
      'pv_numero': '02/2026',
      'date_reception': today,
      'date_emission': today,
      'date_essai': today,
      'type_rapport': 'prestation',
      'nom_client': 'Inspection Power',
      'coordonnees_client': '12 Rue des Usines, Alger',
      'dimensions': '406 x 11 mm',
      'nuance': 'Acier au carbone',
      'n_wps': '02 /695',
      'n_pqr': 'A QUALIFIER',
      'methode_essai': '/',
      'nb_echantillons': 2,
      'methode_echantillonnage': 'ISO15614-1',
      'specification_essai': '/',
      'projet': '/',
      'observation': "L'examen macrographique a relevé une fusion complète et une bonne interpénétration des passes de soudure.",
      'date_signature': today,
      'laboratoire': 'EM',
      'sig_col1_value': 'Ingénieur Tahar',
      'sig_col2_header': 'Nom Client / Représentant',
      'sig_col2_value': 'Inspection Power',
      'sig_col3_header': 'Représentant Cosider',
      'sig_col3_value': 'Cosider',
      'sig_col4_header': 'Tierce Partie / Autorités',
      'sig_col4_value': '/',
      'created_at': now,
    });

    await db.insert('echantillons', {
      'rapport_id': r2Id,
      'numero': 1,
      'photo_path': null,
      'observation': "Examen conforme.",
      'vitesse': '0,9',
      'u_int': '32 V',
      'u_ext': '32 V',
      'i_int': '630 A',
      'i_ext': '780 A',
      'fil_int_1': '(3,2mm) 200987',
      'fil_int_2': '(4 mm) 200955',
      'flux': 'D1FX25376 P223',
      'type_lot': 'LOT 27',
      'grossissement': '1,8 FOIS',
      'metal_nuance': 'X 60',
      'n_coulee': '26302120',
      'n_bobine': '2630415233',
      'diametre_tube': '406',
      'ep_nominale': '11,10',
      'ep_reel': '11',
      'fournisseur': 'TOSYALI',
      'n_tube': '1345 G',
      'surep_ext': '1,66',
      'surep_int': '1,66',
      'largeur_ext': '15',
      'largeur_int': '12,77',
      'penetration_ext': '68,18',
      'penetration_int': '55,54',
      'desaxage': '0',
      'interpenetration': '2,22',
    });
  }

  Future<Map<String, int>> getDashboardStats() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT CASE WHEN nom_client IS NOT NULL AND TRIM(nom_client) != '' THEN LOWER(TRIM(nom_client)) END) as client_count,
        COUNT(id) as rapport_count,
        COALESCE(SUM(nb_echantillons), 0) as echantillon_count
      FROM rapports
    ''');

    if (rows.isEmpty) {
      return {'clients': 0, 'rapports': 0, 'echantillons': 0};
    }
    final r = rows.first;
    return {
      'clients': (r['client_count'] as int?) ?? 0,
      'rapports': (r['rapport_count'] as int?) ?? 0,
      'echantillons': (r['echantillon_count'] as int?) ?? 0,
    };
  }

  /// Génère automatiquement le prochain N° PV au format NN/AAAA,
  /// contextualisé par Client et Projet.
  Future<String> getNextPvNumero({
    String? basePvNumero,
    String? nomClient,
    String? projet,
  }) async {
    final db = await database;
    final year = DateTime.now().year;

    String query = "SELECT pv_numero FROM rapports WHERE pv_numero LIKE ?";
    final List<dynamic> args = ['%/$year'];

    if (nomClient != null && nomClient.trim().isNotEmpty) {
      query += " AND LOWER(TRIM(nom_client)) = ?";
      args.add(nomClient.trim().toLowerCase());
    }

    if (projet != null && projet.trim().isNotEmpty && projet.trim() != '/') {
      query += " AND LOWER(TRIM(projet)) = ?";
      args.add(projet.trim().toLowerCase());
    }

    final rows = await db.rawQuery(query, args);
    final existingNumbers = <int>{};
    for (final row in rows) {
      final pv = row['pv_numero'] as String;
      final parts = pv.split('/');
      if (parts.isNotEmpty) {
        final n = int.tryParse(parts[0]);
        if (n != null) existingNumbers.add(n);
      }
    }

    int startNum = 1;
    if (basePvNumero != null && basePvNumero.isNotEmpty) {
      final parts = basePvNumero.split('/');
      if (parts.isNotEmpty) {
        final n = int.tryParse(parts[0]);
        if (n != null) startNum = n + 1;
      }
    } else if (existingNumbers.isNotEmpty) {
      int maxNum = 0;
      for (final n in existingNumbers) {
        if (n > maxNum) maxNum = n;
      }
      startNum = maxNum + 1;
    }

    while (existingNumbers.contains(startNum)) {
      startNum++;
    }

    final next = startNum.toString().padLeft(2, '0');
    return '$next/$year';
  }

}
