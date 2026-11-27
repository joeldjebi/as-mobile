/// Types de livraison VITE proposés au client (engin × délai)
const vehicles = {
  'MOTO': ('Moto', 'Petits colis'),
  'CAR': ('Voiture', 'Colis moyens ou fragiles'),
  'CARGO': ('Cargo', 'Gros volumes'),
};

const speeds = {
  'EXPRESS': ('Express', 'Livreur dédié à votre commande'),
  'STANDARD': (
    'Standard',
    'Le livreur peut passer par une autre adresse sur sa route',
  ),
  'SCHEDULED': ('Dans 2 heures', 'Le moins cher'),
};

/// Nom d'un engin : celui de VITE s'il est connu (vélo, tricycle…), sinon le nom d'origine, sinon le code mis en forme
String vehicleName(Object? code, [List? fromVite]) {
  final c = '${code ?? 'MOTO'}';
  final v = fromVite?.cast<Map>().where((x) => x['code'] == c).firstOrNull;
  return (v?['name'] as String?) ??
      vehicles[c]?.$1 ??
      (c.isEmpty ? c : c[0] + c.substring(1).toLowerCase());
}

String vehicleHint(Object? code, [List? fromVite]) {
  final c = '${code ?? 'MOTO'}';
  final v = fromVite?.cast<Map>().where((x) => x['code'] == c).firstOrNull;
  final d = v?['description'] as String?;
  return (d != null && d.isNotEmpty) ? d : (vehicles[c]?.$2 ?? '');
}

String deliveryLabel(Object? v, Object? s, [Object? name]) => [
  (name as String?) ?? vehicleName(v),
  speeds[s ?? 'STANDARD']?.$1,
].whereType<String>().join(' · ');
