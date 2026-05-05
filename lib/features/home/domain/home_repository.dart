import 'home_models.dart';

abstract class HomeRepository {
  Future<HomePortalData> getHomePortalData();
}
