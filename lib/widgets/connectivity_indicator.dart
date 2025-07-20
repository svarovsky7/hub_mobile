import 'package:flutter/material.dart';
import '../services/offline_service.dart';

class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({super.key});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _isOnline = OfflineService.isOnline;
    
    // Слушаем изменения подключения
    OfflineService.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade600,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Режим офлайн. Изменения будут синхронизированы при подключении к интернету.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (OfflineService.hasPendingSync) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.sync_problem,
              color: Colors.white,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }
}