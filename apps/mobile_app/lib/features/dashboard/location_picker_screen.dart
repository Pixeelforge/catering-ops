import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _isLoading = false;

  // Default to a generic location if none provided (e.g. Hyderabad)
  final LatLng _defaultLocation = const LatLng(17.3850, 78.4867);

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);
    } else {
      _selectedLocation = _defaultLocation;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _selectedLocation = position.target;
    });
  }

  Future<void> _saveLocation() async {
    if (_selectedLocation == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      await supabase.from('companies').update({
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
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
          
          // Save Button Overlay
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
              ),
              child: _isLoading
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'SAVE LOCATION',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
