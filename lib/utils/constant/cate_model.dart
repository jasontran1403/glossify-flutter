import 'package:hair_sallon/utils/constant/service.dart';

class CategoryModel {
  final String cateId;
  final String cateName;
  final String cateAvt;
  final List<ServiceModel> services;

  CategoryModel({
    required this.cateId,
    required this.cateName,
    required this.services,
    required this.cateAvt
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      cateId: json['cateId'] ?? '',
      cateName: json['cateName'] ?? '',
      cateAvt: json['cateAvt'] ?? '',
      services: (json['services'] as List<dynamic>?)
          ?.map((e) => ServiceModel.fromJson(e))
          .toList() ?? [],
    );
  }
}
