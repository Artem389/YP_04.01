import '../models/product_category.dart';
import '../models/product.dart';

const seedCategories = <ProductCategory>[
  ProductCategory(id: 1, name: 'Молочные продукты', description: 'Молоко, сыр, творог'),
  ProductCategory(id: 2, name: 'Хлеб и выпечка', description: 'Хлеб, батоны, булочки'),
  ProductCategory(id: 3, name: 'Мясо и птица', description: 'Свежее мясо, колбасы'),
  ProductCategory(id: 4, name: 'Овощи и фрукты', description: 'Свежие овощи и фрукты'),
  ProductCategory(id: 5, name: 'Бакалея', description: 'Крупы, макароны, мука'),
  ProductCategory(id: 6, name: 'Напитки', description: 'Соки, вода, газировка'),
  ProductCategory(id: 7, name: 'Сладости', description: 'Конфеты, печенье, шоколад'),
  ProductCategory(id: 8, name: 'Замороженные продукты', description: 'Пельмени, мороженое'),
];

final seedProducts = <Product>[
  Product(id: 1,  name: 'Молоко 3,2% 1 л',        sku: 'MIL-001', price: 89.90,  weightGr: 1030, categoryId: 1, supplierId: 1, stockTotal: 100, stockAvailable: 100),
  Product(id: 2,  name: 'Кефир 2,5% 1 л',         sku: 'MIL-002', price: 79.50,  weightGr: 1030, categoryId: 1, supplierId: 1, stockTotal: 80,  stockAvailable: 80),
  Product(id: 3,  name: 'Сыр «Российский» 200 г', sku: 'MIL-003', price: 189.00, weightGr: 200,  categoryId: 1, supplierId: 1, stockTotal: 40,  stockAvailable: 40),
  Product(id: 4,  name: 'Хлеб «Бородинский»',     sku: 'BRD-001', price: 45.00,  weightGr: 400,  categoryId: 2, supplierId: 2, stockTotal: 60,  stockAvailable: 60),
  Product(id: 5,  name: 'Батон нарезной',         sku: 'BRD-002', price: 39.90,  weightGr: 400,  categoryId: 2, supplierId: 2, stockTotal: 55,  stockAvailable: 55),
  Product(id: 6,  name: 'Курица охлаждённая',     sku: 'MET-001', price: 259.00, weightGr: 1500, categoryId: 3, supplierId: 3, stockTotal: 25,  stockAvailable: 25),
  Product(id: 7,  name: 'Фарш свино-говяжий',     sku: 'MET-002', price: 389.00, weightGr: 500,  categoryId: 3, supplierId: 3, stockTotal: 30,  stockAvailable: 30),
  Product(id: 8,  name: 'Помидоры тепличные',     sku: 'VEG-001', price: 149.90, weightGr: 1000, categoryId: 4, supplierId: 4, stockTotal: 70,  stockAvailable: 70),
  Product(id: 9,  name: 'Огурцы свежие',          sku: 'VEG-002', price: 99.90,  weightGr: 1000, categoryId: 4, supplierId: 4, stockTotal: 65,  stockAvailable: 65),
  Product(id: 10, name: 'Бананы 1 кг',            sku: 'FRU-001', price: 119.90, weightGr: 1000, categoryId: 4, supplierId: 4, stockTotal: 90,  stockAvailable: 90),
  Product(id: 11, name: 'Яблоки «Голден»',        sku: 'FRU-002', price: 139.90, weightGr: 1000, categoryId: 4, supplierId: 4, stockTotal: 85,  stockAvailable: 85),
  Product(id: 12, name: 'Рис длиннозёрный 900 г', sku: 'GRO-001', price: 129.00, weightGr: 900,  categoryId: 5, supplierId: 5, stockTotal: 50,  stockAvailable: 50),
  Product(id: 13, name: 'Макароны «Спагетти»',    sku: 'GRO-002', price: 89.00,  weightGr: 450,  categoryId: 5, supplierId: 5, stockTotal: 60,  stockAvailable: 60),
  Product(id: 14, name: 'Мука пшеничная 2 кг',    sku: 'GRO-003', price: 109.00, weightGr: 2000, categoryId: 5, supplierId: 5, stockTotal: 45,  stockAvailable: 45),
  Product(id: 15, name: 'Сок апельсиновый 1 л',   sku: 'BEV-001', price: 119.00, weightGr: 1060, categoryId: 6, supplierId: 6, stockTotal: 75,  stockAvailable: 75),
  Product(id: 16, name: 'Вода минеральная 1,5 л', sku: 'BEV-002', price: 55.00,  weightGr: 1560, categoryId: 6, supplierId: 6, stockTotal: 120, stockAvailable: 120),
  Product(id: 17, name: 'Кола 1 л',               sku: 'BEV-003', price: 89.00,  weightGr: 1060, categoryId: 6, supplierId: 6, stockTotal: 100, stockAvailable: 100),
  Product(id: 18, name: 'Шоколад молочный 90 г',  sku: 'SWE-001', price: 99.00,  weightGr: 90,   categoryId: 7, supplierId: 7, stockTotal: 80,  stockAvailable: 80),
  Product(id: 19, name: 'Печенье овсяное 300 г',  sku: 'SWE-002', price: 79.00,  weightGr: 300,  categoryId: 7, supplierId: 7, stockTotal: 65,  stockAvailable: 65),
  Product(id: 20, name: 'Пельмени «Сибирские»',   sku: 'FRZ-001', price: 329.00, weightGr: 800,  categoryId: 8, supplierId: 8, stockTotal: 40,  stockAvailable: 40),
  Product(id: 21, name: 'Мороженое «Пломбир»',    sku: 'FRZ-002', price: 89.00,  weightGr: 100,  categoryId: 8, supplierId: 8, stockTotal: 90,  stockAvailable: 90),
  Product(id: 22, name: 'Творог 5% 200 г',        sku: 'MIL-004', price: 109.00, weightGr: 200,  categoryId: 1, supplierId: 1, stockTotal: 55,  stockAvailable: 0),  // нет в наличии
];