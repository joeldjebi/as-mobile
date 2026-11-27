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

String deliveryLabel(Object? v, Object? s) => [
  vehicles[v ?? 'MOTO']?.$1,
  speeds[s ?? 'STANDARD']?.$1,
].whereType<String>().join(' · ');
