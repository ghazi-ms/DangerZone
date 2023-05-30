import 'dart:convert';
import 'package:http/http.dart';

///a class to connect to the [_apiEndpoint] and returns [_responseStatus] and [_response_message] to determine the result of the connection.
///* must have a working [_apiEndpoint].
class BackendDataFetch {
  late int _responseStatus;
  late String _responseMessage;
  final String _apiEndpoint =
      "https://backendgradproject-z9mv-master-gtgu5kzprq-wl.a.run.app/";
  static final BackendDataFetch _instance = BackendDataFetch._internal();

  factory BackendDataFetch() {
    return _instance;
  }

  BackendDataFetch._internal();

  /// function that connects to the backend server to get the latest [dangerZonesData].
  Future<Map<String, dynamic>> fetchDangerZoneData(
    dynamic dangerZonesData,
  ) async {
    try {
      final response = await get(Uri.parse(_apiEndpoint))
          .timeout(const Duration(minutes: 2));
      _responseStatus = response.statusCode;
      if (_responseStatus == 200) {
        _responseMessage = "!تم العثور على مناطق خطر جديدة";
        List<Map<String, dynamic>> data =
            json.decode(response.body).cast<Map<String, dynamic>>();
        processDangerZoneData(dangerZonesData, data);
      } else {
        _responseMessage = "لم يتم العثور على مناطق خطر";
        throw 'Problem with the GET request';
      }
    } catch (e) {
      if (e.toString() == 'Connection closed while receiving data') {
        await fetchDangerZoneData(
          dangerZonesData,
        ); // Retry fetching danger zones if the connection is closed
      }
    }

    return {"message": _responseMessage, "status": _responseStatus};
  }

  /// function that takes [dangerZonesData] and [data] to add the new data elements to the [dangerZonesData] list.
  void processDangerZoneData(
    dynamic dangerZonesData,
    List<Map<String, dynamic>> data,
  ) {
    data.forEach((Map<String, dynamic> newData) {
      int id = newData['id'];
      // Check if the ID already exists in dangerZonesData
      bool idExists = dangerZonesData.any(
        (existingData) => existingData['id'].toString() == id.toString(),
      );
      if (!idExists) {
        dangerZonesData.add(newData);
      }
    });
  }
}
