import 'dart:convert';

import 'package:http/http.dart';

///a class to connect to the [_apiEndpoint] and returns [_respone_status] and [_response_message] to determine the result of the connection.
///* must have a working [_apiEndpoint].
class BackendDataFetch {
  late int _respone_status;
  late String _response_message;
  final String _apiEndpoint =
      "https://backendgradproject-z9mv-master-gtgu5kzprq-wl.a.run.app/";

  BackendDataFetch();
  /// function that connects to the backend server to get the latest [dangerZonesData].
  Future<Map<String, dynamic>> fetchDangerZoneData(
      dynamic dangerZonesData) async {
    try {
      final response = await get(Uri.parse(_apiEndpoint))
          .timeout(const Duration(minutes: 2));
      _respone_status = response.statusCode;
      if (_respone_status == 200) {
        _response_message = "!تم العتور على مناطق خطر جديدة";
        List<Map<String, dynamic>> data =
            json.decode(response.body).cast<Map<String, dynamic>>();
        processDangerZoneData(dangerZonesData, data);
      } else {
        _response_message = "لم يتم العثور على مناطق خطر";
        throw 'Problem with the GET request';
      }
    } catch (e) {
      if (e.toString() == 'Connection closed while receiving data') {
        await fetchDangerZoneData(
            dangerZonesData); // Retry fetching danger zones if the connection is closed
      }
    }
    return {"message": _response_message, "status": _respone_status};
  }
  /// function that takes [dangerZonesData] and [data] to add the new data elements to the [dangerZonesData] list.
  void processDangerZoneData(
      dynamic dangerZonesData, List<Map<String, dynamic>> data) {
    data.forEach((Map<String, dynamic> newData) {
      int id = newData['id'];
      // Check if the ID already exists in dangerZonesData
      bool idExists = dangerZonesData.any(
          (existingData) => existingData['id'].toString() == id.toString());
      if (!idExists) {
        dangerZonesData.add(newData);
      }
    });
  }
}
