import 'dart:math' show cos, sin, asin, sqrt;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

enum SortMode { none, cheap, near }

class Facility {
  final String id;
  final String name;
  final double price; // COP/hora
  final double rating;
  final List<String> types;
  final String address;
  final LatLng pos;
  final Color color;
  Facility({
    required this.id,
    required this.name,
    required this.price,
    required this.rating,
    required this.types,
    required this.address,
    required this.pos,
    required this.color,
  });
}


final List<Facility> kNeivaFacilities = [
  Facility(
    id: 'centro',
    name: 'Cancha Centro',
    price: 35000,
    rating: 4.7,
    types: ['Fútbol 5', 'Baloncesto'],
    address: 'Cra 5 #7-20, Neiva',
    pos: LatLng(2.9348, -75.2895),
    color: Color(0xFF10B981),
  ),
  Facility(
    id: 'norte',
    name: 'Polideportivo Norte',
    price: 42000,
    rating: 4.5,
    types: ['Tenis', 'Fútbol 7'],
    address: 'Av 26 #40-10, Neiva',
    pos: LatLng(2.9546, -75.2801),
    color: Color(0xFF3B82F6),
  ),
  Facility(
    id: 'sur',
    name: 'Club Deportivo Sur',
    price: 28000,
    rating: 4.2,
    types: ['Baloncesto'],
    address: 'Cl 19 Sur #12-80, Neiva',
    pos: LatLng(2.9140, -75.2938),
    color: Color(0xFFF59E0B),
  ),
  Facility(
    id: 'norte',
    name: 'Tercer Tiempo',
    price: 60000,
    rating: 5,
    types: ['Futbol 5'],
    address: 'Cl. 55 #17-98 17-2 a, Comuna 2',
    pos: LatLng(2.9557916446471304, -75.28819035868682),
    color: Color.fromARGB(255, 8, 235, 95),
  ),
];


const Map<String, LatLng> kCities = {'Neiva, Huila': LatLng(2.9375, -75.2893)};

class MapView extends StatefulWidget {
  const MapView({super.key});
  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final mapController = MapController();
  SortMode sort = SortMode.none;
  String city = 'Neiva, Huila';
  LatLng? userPos; // geolocator
  double zoom = 14;

  List<Facility> get facilities => switch (city) {
    'Neiva, Huila' => kNeivaFacilities,
    _ => kNeivaFacilities, // demo
  };

  LatLng get cityCenter => kCities[city]!;
  LatLng get referencePos => userPos ?? cityCenter;

  @override
  void initState() {
    super.initState();
    _ensureLocation();
  }

  Future<void> _ensureLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (!mounted) {
        return;
      }
      setState(() => userPos = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() => userPos = LatLng(last.latitude, last.longitude));
      }
    }
  }

  // Haversine en km
  double _distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final aa =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(a.latitude)) *
            cos(_deg2rad(b.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * asin(sqrt(aa));
  }

  double _deg2rad(double d) => d * (3.141592653589793 / 180.0);

  List<Facility> _sortedFacilities() {
    final list = [...facilities];
    switch (sort) {
      case SortMode.cheap:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortMode.near:
        list.sort(
          (a, b) => _distanceKm(
            a.pos,
            referencePos,
          ).compareTo(_distanceKm(b.pos, referencePos)),
        );
        break;
      case SortMode.none:
        break;
    }
    return list;
  }

  void _openFilters() async {
    final result = await showModalBottomSheet<SortMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filtros',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 16),
            _FilterTile(
              title: 'Precio más bajo',
              selected: sort == SortMode.cheap,
              onTap: () => Navigator.pop(ctx, SortMode.cheap),
            ),
            _FilterTile(
              title: 'Más cercano a mí',
              selected: sort == SortMode.near,
              onTap: () => Navigator.pop(ctx, SortMode.near),
              subtitle: userPos == null ? 'Usa tu ciudad si no hay GPS' : null,
            ),
            _FilterTile(
              title: 'Limpiar',
              selected: sort == SortMode.none,
              onTap: () => Navigator.pop(ctx, SortMode.none),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => sort = result);
  }

  void _chooseCity() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selecciona ciudad'),
        content: DropdownButtonFormField<String>(
          initialValue: city, // <- no usar 'value' (deprecado)
          items: kCities.keys
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => Navigator.pop(ctx, v),
        ),
      ),
    );
    if (result != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        city = result;
        userPos = null; // referencia = centro de la ciudad
      });
      mapController.move(kCities[result]!, 13.5);
    }
  }

  void _centerOnMe() async {
    await _ensureLocation();
    if (!mounted) {
      return;
    }
    if (userPos != null) {
      mapController.move(userPos!, 15);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Centrado en tu ubicación')));
    } else {
      mapController.move(cityCenter, 13.5);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Usando centro de $city')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedFacilities();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SportReserve',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Cambiar ciudad',
            onPressed: _chooseCity,
            icon: const Icon(Icons.location_city),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: cityCenter,
              initialZoom: zoom,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all, // pinch-zoom + pan + rotate
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sportreserve.app',
              ),
              MarkerLayer(
                markers: sorted.map((f) {
                  return Marker(
                    point: f.pos,
                    width: 160,
                    height: 80,
                    child: GestureDetector(
                      onTap: () => _openFacilitySheet(f),
                      child: _MapPin(color: f.color, label: f.name),
                    ),
                  );
                }).toList(),
              ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    onTap: () {},
                    prependCopyright: true,
                  ),
                ],
              ),
            ],
          ),

          // Menú desplegable inferior (speed-dial)
          Positioned(
            right: 16,
            bottom: 16,
            child: _BottomMenu(
              onCenter: _centerOnMe,
              onFilters: _openFilters,
              onZoomIn: () {
                setState(() {
                  zoom = (zoom + .5).clamp(3, 19);
                });
                mapController.move(mapController.camera.center, zoom);
              },
              onZoomOut: () {
                setState(() {
                  zoom = (zoom - .5).clamp(3, 19);
                });
                mapController.move(mapController.camera.center, zoom);
              },
            ),
          ),

          // Etiqueta del filtro activo
          if (sort != SortMode.none)
            Positioned(
              left: 16,
              top: 12,
              child: Chip(
                label: Text(
                  sort == SortMode.cheap
                      ? 'Orden: Más barato'
                      : 'Orden: Más cercano',
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openFacilitySheet(Facility f) {
    final distKm = _distanceKm(f.pos, referencePos);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: f.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${distKm.toStringAsFixed(1)} km · ${f.types.join(" · ")}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9FDF3),
                    border: Border.all(color: const Color(0xFF10B981)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '★ 4.7',
                    style: TextStyle(color: Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Desde ${_cop(f.price)} / hora',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    f.address,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Ver detalles'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        // SnackBar(content: Text('Reserva (mock) en ${f.name}')),
                        SnackBar(content: Text('Funcionalidad aún no añadida'))
                      );
                    },
                    child: const Text('Reservar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _cop(num v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(?!^)(?=(\d{3})+$)'), (m) => '.');
}

/// --- UI helpers --------------------------------------------------------------

class _MapPin extends StatelessWidget {
  final Color color;
  final String label;
  const _MapPin({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                blurRadius: 6,
                color: Colors.black26,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
            boxShadow: const [
              BoxShadow(
                blurRadius: 6,
                color: Colors.black12,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  const _RoundIcon({required this.onTap, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Center(child: Icon(Icons.add, size: 22)),
        ),
      ),
    );
  }
}

class _BottomMenu extends StatefulWidget {
  final VoidCallback onCenter;
  final VoidCallback onFilters;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  const _BottomMenu({
    required this.onCenter,
    required this.onFilters,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  State<_BottomMenu> createState() => _BottomMenuState();
}

class _BottomMenuState extends State<_BottomMenu>
    with TickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _expanded ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _PillButton(
                        text: 'Centrar en mí',
                        onTap: () {
                          widget.onCenter();
                          setState(() => _expanded = false);
                        },
                      ),
                      const SizedBox(height: 8),
                      _PillButton(
                        text: 'Filtros',
                        onTap: () {
                          widget.onFilters();
                          setState(() => _expanded = false);
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _RoundIcon(onTap: widget.onZoomIn, icon: Icons.add),
                          const SizedBox(width: 8),
                          _RoundIcon(
                            onTap: widget.onZoomOut,
                            icon: Icons.remove,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        Material(
          color: Colors.white,
          elevation: 8,
          shadowColor: Colors.black26,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _expanded = !_expanded),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Icon(
                    _expanded ? Icons.close : Icons.menu_rounded,
                    key: ValueKey(_expanded),
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _PillButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 6,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.black12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onPressed: onTap,
      child: Text(text),
    );
  }
}

class _FilterTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _FilterTile({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: selected
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.radio_button_unchecked),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
