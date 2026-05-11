import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/resource_model.dart';

class ResourcesRemoteDatasource {
  final Dio _dio = ApiClient().dio;

  Future<AllResourcesModel> getAll() async {
    final res = await _dio.get('/resources/');
    return AllResourcesModel.fromJson(res.data);
  }

  Future<Map<String, dynamic>> tap(String resourceType, int tapCount) async {
    final res = await _dio.post('/resources/tap', data: {
      'resource_type': resourceType,
      'tap_count': tapCount,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> upgradeTap(String resourceType) async {
    final res = await _dio.post('/resources/upgrade-tap', data: {
      'resource_type': resourceType,
    });
    return res.data;
  }

  Future<List<BuildingModel>> getBuildings() async {
    final res = await _dio.get('/resources/buildings');
    final list = res.data['buildings'] as List;
    return list.map((e) => BuildingModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> buildOrUpgrade(String buildingType) async {
    final res = await _dio.post('/resources/build', data: {
      'building_type': buildingType,
    });
    return res.data;
  }

  Future<SoldiersResponse> getSoldiers() async {
    final res = await _dio.get('/resources/soldiers');
    return SoldiersResponse.fromJson(res.data);
  }

  Future<Map<String, dynamic>> trainSoldiers(String soldierType, int amount) async {
    final res = await _dio.post('/resources/train', data: {
      'soldier_type': soldierType,
      'amount': amount,
    });
    return res.data;
  }
}
