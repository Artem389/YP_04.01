import '../models/customer.dart';
import '../models/page_result.dart';
import '../models/product_query.dart';

abstract interface class CustomerRepository {
  Future<PageResult<Customer>> find(ProductQuery query);
  Future<Customer?> findById(int id);
  Future<Customer> create(Customer customer);
  Future<Customer> update(Customer customer);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
  Future<bool> emailExists(String email, {int? exceptId});
}