// import 'package:flutter_project_web/logic/calculator.dart';
// import 'package:flutter_project_web/logic/currency.dart';
// import 'package:flutter_test/flutter_test.dart';
//
//
// void main() {
//   group('Калькулятор', () {
//     test('сложение', () {
//       final r = calculate('2', '+', '3');
//       expect(r, isA<CalcSuccess>());
//       expect((r as CalcSuccess).value, 5);
//     });
//
//     test('вычитание', () {
//       final r = calculate('10', '-', '4');
//       expect((r as CalcSuccess).value, 6);
//     });
//
//     test('умножение', () {
//       final r = calculate('3', '*', '4');
//       expect((r as CalcSuccess).value, 12);
//     });
//
//     test('деление', () {
//       final r = calculate('9', '/', '3');
//       expect((r as CalcSuccess).value, 3);
//     });
//
//     test('деление на ноль даёт ошибку', () {
//       final r = calculate('5', '/', '0');
//       expect(r, isA<CalcFailure>());
//       expect((r as CalcFailure).message, contains('ноль'));
//     });
//
//     test('нечисловой ввод даёт ошибку', () {
//       final r = calculate('abc', '+', '3');
//       expect(r, isA<CalcFailure>());
//     });
//
//     test('неизвестная операция даёт ошибку', () {
//       final r = calculate('2', '%', '3');
//       expect(r, isA<CalcFailure>());
//     });
//
//     test('пустой параметр даёт ошибку', () {
//       final r = calculate(null, '+', '3');
//       expect(r, isA<CalcFailure>());
//     });
//
//     test('округление убирает хвостовые нули', () {
//       expect(formatNumber(3.3333333333333335), '3.333333');
//       expect(formatNumber(5.0), '5');
//     });
//   });
//
//   group('Конвертер', () {
//     test('перевод USD в RUB', () {
//       final r = convert('10', 'USD', 'RUB');
//       expect((r as ConvertSuccess).value, closeTo(925, 0.01));
//     });
//
//     test('неизвестная валюта', () {
//       final r = convert('10', 'XXX', 'RUB');
//       expect(r, isA<ConvertFailure>());
//     });
//
//     test('отрицательная сумма', () {
//       final r = convert('-5', 'USD', 'RUB');
//       expect(r, isA<ConvertFailure>());
//     });
//   });
// }






// import 'dart:convert';
// import 'dart:typed_data';
//
// import 'package:dio/dio.dart';
// import 'package:flutter_project_web/core/api_exceptions.dart';
// import 'package:flutter_project_web/models/product.dart';
// import 'package:flutter_project_web/models/product_query.dart';
// import 'package:flutter_project_web/repositories/api_product_repository.dart';
// import 'package:flutter_test/flutter_test.dart';
//
// /// Подменный адаптер Dio: возвращает заранее подготовленные ответы,
// /// не выходя в сеть.
// class _FakeAdapter implements HttpClientAdapter {
//   _FakeAdapter(this.handler);
//
//   final Future<ResponseBody> Function(RequestOptions options) handler;
//
//   @override
//   Future<ResponseBody> fetch(
//       RequestOptions options,
//       Stream<Uint8List>? requestStream,
//       Future<void>? cancelFuture,
//       ) =>
//       handler(options);
//
//   @override
//   void close({bool force = false}) {}
// }
//
// ResponseBody _json(Object data, {int status = 200}) {
//   final body = utf8.encode(jsonEncode(data));
//   return ResponseBody.fromBytes(
//     body,
//     status,
//     headers: {
//       Headers.contentTypeHeader: [Headers.jsonContentType],
//     },
//   );
// }
//
// void main() {
//   group('ApiProductRepository', () {
//     test('разбирает успешный ответ GET /products', () async {
//       final dio = Dio(BaseOptions(baseUrl: 'http://test/api'));
//       dio.httpClientAdapter = _FakeAdapter((options) async {
//         expect(options.path, '/products');
//         return _json({
//           'items': [
//             {
//               'id': 1,
//               'name': 'Молоко 3,2% 1 л',
//               'sku': 'MIL-001',
//               'price': 89.90,
//               'weightGr': 1030,
//               'category': {'id': 1, 'name': 'Молочные продукты'},
//               'supplier': {'id': 1, 'name': 'Молочный дом'},
//               'stockTotal': 100,
//               'stockAvailable': 100,
//             }
//           ],
//           'page': 1,
//           'size': 10,
//           'total': 1,
//         });
//       });
//
//       final repo = ApiProductRepository(dio);
//       final page = await repo.find(const ProductQuery());
//
//       expect(page.total, 1);
//       expect(page.items, hasLength(1));
//       expect(page.items.first.name, 'Молоко 3,2% 1 л');
//       expect(page.items.first.sku, 'MIL-001');
//       expect(page.items.first.price, 89.90);
//       expect(page.items.first.weightGr, 1030);
//       expect(page.items.first.categoryId, 1);
//       expect(page.items.first.supplierIds, [1]);
//       expect(page.items.first.categoryName, 'Молочные продукты');
//       expect(page.items.first.supplierNames, ['Молочный дом']);
//       expect(page.items.first.stockTotal, 100);
//       expect(page.items.first.stockAvailable, 100);
//     });
//
//     test('422 преобразуется в ValidationException', () async {
//       final dio = Dio(BaseOptions(
//         baseUrl: 'http://test/api',
//         validateStatus: (s) => s != null && s < 500,
//       ));
//       dio.httpClientAdapter = _FakeAdapter((_) async => _json(
//         {
//           'message': 'Ошибка валидации',
//           'errors': {'sku': 'Товар с таким артикулом уже существует'},
//         },
//         status: 422,
//       ));
//
//       dio.interceptors.add(InterceptorsWrapper(
//         onResponse: (response, handler) {
//           final status = response.statusCode ?? 0;
//           if (status >= 400) {
//             handler.reject(
//               DioException(
//                 requestOptions: response.requestOptions,
//                 response: response,
//                 type: DioExceptionType.badResponse,
//                 error: mapHttpError(status, response.data),
//               ),
//               true,
//             );
//           } else {
//             handler.next(response);
//           }
//         },
//       ));
//
//       final repo = ApiProductRepository(dio);
//       await expectLater(
//             () => repo.create(const Product(
//           id: 0,
//           name: 'X',
//           sku: 'Y',
//           price: 0,
//           weightGr: 0,
//           categoryId: 0,
//           stockTotal: 0,
//           stockAvailable: 0,
//         )),
//         throwsA(
//           isA<ValidationException>().having(
//                 (e) => e.errors['sku'],
//             'errors.sku',
//             'Товар с таким артикулом уже существует',
//           ),
//         ),
//       );
//     });
//
//     test('недоступность сервера → NetworkException', () async {
//       final dio = Dio(BaseOptions(baseUrl: 'http://test/api'));
//       dio.httpClientAdapter = _FakeAdapter((_) async {
//         throw DioException(
//           requestOptions: RequestOptions(path: '/products'),
//           type: DioExceptionType.connectionError,
//         );
//       });
//
//       final repo = ApiProductRepository(dio);
//       await expectLater(
//             () => repo.find(const ProductQuery()),
//         throwsA(isA<NetworkException>()),
//       );
//     });
//
//     test('пустой ответ корректно превращается в пустую страницу', () async {
//       final dio = Dio(BaseOptions(baseUrl: 'http://test/api'));
//       dio.httpClientAdapter = _FakeAdapter((_) async => _json({
//         'items': [],
//         'page': 1,
//         'size': 10,
//         'total': 0,
//       }));
//
//       final repo = ApiProductRepository(dio);
//       final page = await repo.find(const ProductQuery());
//       expect(page.items, isEmpty);
//       expect(page.total, 0);
//     });
//
//     test('отмена запроса через CancelToken → NetworkException', () async {
//       final dio = Dio(BaseOptions(baseUrl: 'http://test/api'));
//       dio.httpClientAdapter = _FakeAdapter((options) async {
//         throw DioException(
//           requestOptions: options,
//           type: DioExceptionType.cancel,
//         );
//       });
//
//       final repo = ApiProductRepository(dio);
//       final token = CancelToken();
//       token.cancel('тест');
//
//       await expectLater(
//             () => repo.find(const ProductQuery(), cancelToken: token),
//         throwsA(isA<NetworkException>()),
//       );
//     });
//
//     test('передаёт categoryId и supplierId в query-параметрах', () async {
//       final dio = Dio(BaseOptions(baseUrl: 'http://test/api'));
//       late Map<String, dynamic> capturedQuery;
//
//       dio.httpClientAdapter = _FakeAdapter((options) async {
//         capturedQuery = Map<String, dynamic>.from(options.queryParameters);
//         return _json({
//           'items': [],
//           'page': 1,
//           'size': 10,
//           'total': 0,
//         });
//       });
//
//       final repo = ApiProductRepository(dio);
//       await repo.find(const ProductQuery(
//         categoryId: 2,
//         supplierId: 3,
//         priceFrom: 100,
//         priceTo: 500,
//       ));
//
//       expect(capturedQuery['categoryId'], 2);
//       expect(capturedQuery['supplierId'], 3);
//       expect(capturedQuery['priceFrom'], 100);
//       expect(capturedQuery['priceTo'], 500);
//     });
//   });
// }


import 'package:flutter_project_web/core/role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Role', () {
    test('уровни ролей возрастают: client < manager < admin', () {
      expect(Role.client.level, lessThan(Role.manager.level));
      expect(Role.manager.level, lessThan(Role.admin.level));
    });

    test('client не пропускает manager', () {
      expect(Role.client.allows(Role.manager), isFalse);
    });

    test('manager пропускает client, но не admin', () {
      expect(Role.manager.allows(Role.client), isTrue);
      expect(Role.manager.allows(Role.admin), isFalse);
    });

    test('admin пропускает все роли', () {
      expect(Role.admin.allows(Role.client), isTrue);
      expect(Role.admin.allows(Role.manager), isTrue);
      expect(Role.admin.allows(Role.admin), isTrue);
    });

    test('Role.parse корректно разбирает строки сервера', () {
      expect(Role.parse('admin'), Role.admin);
      expect(Role.parse('manager'), Role.manager);
      expect(Role.parse('client'), Role.client);
      expect(Role.parse(null), Role.client);
      expect(Role.parse('unknown'), Role.client);
    });

    test('wire-представление соответствует серверу', () {
      expect(Role.admin.wire, 'admin');
      expect(Role.manager.wire, 'manager');
      expect(Role.client.wire, 'client');
    });
  });
}