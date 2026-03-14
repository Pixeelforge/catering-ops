import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

class LocationPickerScreen extends StatefulWidget {
  final String companyId;
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({
    super.key,
    required this.companyId,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final supabase = Supabase.instance.client;
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _currentAddress = 'Move the map to select a location...';
  bool _isLoading = false;
  bool _isFetchingAddress = false;
  Timer? _debounce;

  // Default to a generic location if none provided (e.g. Hyderabad)
  final LatLng _defaultLocation = const LatLng(17.3850, 78.4867);

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);
      _fetchAddress(_selectedLocation!);
    } else {
      _selectedLocation = _defaultLocation;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _selectedLocation = position.target;
      _currentAddress = 'Loading address...';
      _isFetchingAddress = true;
    });
    
    // Debounce the geocoding to avoid spamming the API
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (_selectedLocation != null) {
        _fetchAddress(_selectedLocation!);
      }
    });
  }

  Future<void> _fetchAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final address = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.postalCode,
        ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
        
        if (mounted) {
          setState(() {
            _currentAddress = address.isEmpty ? 'Unknown Location' : address;
            _isFetchingAddress = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = 'Could not fetch address';
          _isFetchingAddress = false;
        });
      }
    }
  }

  Future<void> _saveLocation() async {
    if (_selectedLocation == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      await supabase.from('companies').update({
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'address': _currentAddress != 'Could not fetch address' && _currentAddress != 'Loading address...' ? _currentAddress : null,
      }).eq('id', widget.companyId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business location saved!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, _selectedLocation);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving location: $e'), backgroundColor: Colors.redAccent),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Set Business Location', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _selectedLocation ?? _defaultLocation,
              zoom: 14.0,
            ),
            onCameraMove: _onCameraMove,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          
          // Custom Fixed Marker in the center
          const Center(
            child: Icon(
              Icons.location_on,
              size: 50.0,
              color: Colors.redAccent,
            ),
          ),
          
          
          // Address Info Overlay
          Positioned(
            bottom: 110,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF232336).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_city,
                    color: Colors.orangeAccent.withOpacity(0.8),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Selected Address',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentAddress,
                          style: TextStyle(
                            color: _isFetchingAddress ? Colors.white54 : Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Save Button Overlay
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _isLoading || _isFetchingAddress ? null : _saveLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
              ),
              child: _isLoading
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'SAVE LOCATION & ADDRESS',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
