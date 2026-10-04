#!/usr/bin/env node
/**
 * Мок-сервер учебного API «Продуктовый магазин».
 *
 *   node mock-server.js --port 8080 --origin http://localhost:5555
 *
 * Данные хранятся в памяти и сбрасываются при перезапуске
 * либо запросом POST /api/__reset
 *
 * Учебные возможности:
 *   ?__delay=1500   задержка ответа в миллисекундах
 *   ?__fail=500     принудительный код ошибки
 */

'use strict';

const http = require('node:http');
const crypto = require('node:crypto');

// ─────────────────────────── параметры запуска ───────────────────────────

const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf('--' + name);
  return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
}

const PORT = Number(arg('port', 8080));
const ORIGIN = arg('origin', '*');
const SECRET = 'учебный-ключ-не-для-продакшена';
const ACCESS_TTL = Number(arg('ttl', 900));
const REFRESH_TTL = 60 * 60 * 24 * 7;

// ─────────────────────────────── токены ───────────────────────────────

function b64url(buf) {
  return Buffer.from(buf).toString('base64url');
}

function sign(payload) {
  const withId = { ...payload, jti: crypto.randomUUID() };
  const body = b64url(JSON.stringify(withId));
  const mac = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  return body + '.' + mac;
}

function verify(token) {
  if (typeof token !== 'string' || !token.includes('.')) return null;
  const [body, mac] = token.split('.');
  const expected = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  if (mac !== expected) return null;
  let payload;
  try {
    payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (payload.exp && payload.exp * 1000 < Date.now()) return null;
  return payload;
}

// ─────────────────────────────── данные ───────────────────────────────

let db;

function seed() {
  db = {
    seq: {},
    categories: [],
    suppliers: [],
    products: [],
    customers: [],
    cards: [],
    sales: [],
    users: [],
    refreshTokens: new Set(),
  };

  const C = (name, description) => push('categories', { name, description });
  const S = (name, city, phone) => push('suppliers', { name, city, phone });
  const P = (name, sku, price, weightGr, categoryId, supplierId, stockTotal) =>
    push('products', {
      name,
      sku,
      price,
      weightGr,
      categoryId,
      supplierId,
      stockTotal,
      stockAvailable: stockTotal,
    });

  // Категории
  const dairy     = C('Молочные продукты',      'Молоко, сыр, творог, кефир');
  const bread     = C('Хлеб и выпечка',         'Хлеб, батоны, булочки');
  const meat      = C('Мясо и птица',           'Свежее мясо, колбасы, птица');
  const veg       = C('Овощи и фрукты',         'Свежие овощи, фрукты, зелень');
  const grocery   = C('Бакалея',                'Крупы, макароны, мука, сахар');
  const drinks    = C('Напитки',                'Соки, вода, газировка, чай');
  const sweets    = C('Сладости',               'Конфеты, печенье, шоколад');
  const frozen    = C('Замороженные продукты',  'Пельмени, мороженое, полуфабрикаты');

  // Поставщики
  const milkDom    = S('Молочный дом',           'frozen@trade.ru',           '+7 495 111-11-11');
  const hlebozavod = S('Хлебозавод №1',          'sweet@world.ru',           '+7 495 222-22-22');
  const myaso      = S('Мясокомбинат «Первый»',  'sale@drinks.ru',           '+7 495 333-33-33');
  const ovosh      = S('Овощная база «Юг»',      'info@grocery.ru',  '+7 812 444-44-44');
  const bakaleya   = S('Бакалея-Опт',            'opt@veg.ru',           '+7 495 555-55-55');
  const napitki    = S('НапиткиПлюс',            'order@meat.ru',           '+7 495 666-66-66');
  const sladkiy    = S('Сладкий мир',            'sales@bread.ru',           '+7 495 777-77-77');
  const zamorozka  = S('Заморозка-Трейд',        'info@milk.ru',  '+7 812 888-88-88');

  // Товары
  P('Молоко 3,2% 1 л',          'MIL-001',  89.90, 1030, dairy,   milkDom,     100);
  P('Кефир 2,5% 1 л',           'MIL-002',  79.50, 1030, dairy,   milkDom,      80);
  P('Сыр «Российский» 200 г',   'MIL-003', 189.00,  200, dairy,   milkDom,      40);
  P('Творог 5% 200 г',          'MIL-004', 109.00,  200, dairy,   milkDom,      55);
  P('Хлеб «Бородинский»',       'BRD-001',  45.00,  400, bread,   hlebozavod,   60);
  P('Батон нарезной',           'BRD-002',  39.90,  400, bread,   hlebozavod,   55);
  P('Курица охлаждённая',       'MET-001', 259.00, 1500, meat,    myaso,        25);
  P('Фарш свино-говяжий',       'MET-002', 389.00,  500, meat,    myaso,        30);
  P('Помидоры тепличные',       'VEG-001', 149.90, 1000, veg,     ovosh,        70);
  P('Огурцы свежие',            'VEG-002',  99.90, 1000, veg,     ovosh,        65);
  P('Бананы 1 кг',              'FRU-001', 119.90, 1000, veg,     ovosh,        90);
  P('Яблоки «Голден»',          'FRU-002', 139.90, 1000, veg,     ovosh,        85);
  P('Рис длиннозёрный 900 г',   'GRO-001', 129.00,  900, grocery, bakaleya,     50);
  P('Макароны «Спагетти»',      'GRO-002',  89.00,  450, grocery, bakaleya,     60);
  P('Мука пшеничная 2 кг',      'GRO-003', 109.00, 2000, grocery, bakaleya,     45);
  P('Сок апельсиновый 1 л',     'BEV-001', 119.00, 1060, drinks,  napitki,      75);
  P('Вода минеральная 1,5 л',   'BEV-002',  55.00, 1560, drinks,  napitki,     120);
  P('Кола 1 л',                 'BEV-003',  89.00, 1060, drinks,  napitki,     100);
  P('Шоколад молочный 90 г',    'SWE-001',  99.00,   90, sweets,  sladkiy,      80);
  P('Печенье овсяное 300 г',    'SWE-002',  79.00,  300, sweets,  sladkiy,      65);
  P('Пельмени «Сибирские»',     'FRZ-001', 329.00,  800, frozen,  zamorozka,    40);
  P('Мороженое «Пломбир»',      'FRZ-002',  89.00,  100, frozen,  zamorozka,    90);

  // Покупатели
  const customerNames = [
    ['Смирнов П. А.',   'smirnov@example.com',   '+7 900 100-10-01'],
    ['Кузнецова М. И.', 'kuznetsova@example.com','+7 900 100-10-02'],
    ['Попов Д. С.',     'popov@example.com',     '+7 900 100-10-03'],
    ['Васильева Е. О.', 'vasileva@example.com',  '+7 900 100-10-04'],
    ['Новиков А. В.',   'novikov@example.com',   '+7 900 100-10-05'],
    ['Морозова Т. Н.',  'morozova@example.com',  '+7 900 100-10-06'],
  ];

  customerNames.forEach(([fullName, email, phone], i) => {
    const customerId = push('customers', { fullName, email, phone });
    push('cards', {
      customerId,
      number: 'DC-' + String(customerId).padStart(6, '0'),
      discountPercent: 5 + (i % 3) * 5,
      issuedAt: iso(2026, 1, 15 + i),
    });
  });

  // Несколько продаж
  makeSale(1, 1, -20, 1);   // активная
  makeSale(2, 6, -5, 2);
  makeSale(3, 11, -30, 1, true); // завершена

  // Пользователи
  push('users', { username: 'admin',     passwordHash: hash('admin123'),     fullName: 'Администратор', email: 'admin@shop.local',    role: 'admin',     customerId: null });
  push('users', { username: 'manager', passwordHash: hash('manager123'), fullName: 'Петрова А. С.', email: 'petrova@shop.local',  role: 'manager', customerId: null });
  push('users', { username: 'client',    passwordHash: hash('client123'),    fullName: 'Смирнов П. А.', email: 'smirnov@example.com', role: 'client',    customerId: 1 });
}

function push(collection, obj) {
  db.seq[collection] = (db.seq[collection] || 0) + 1;
  const id = db.seq[collection];
  db[collection].push({ id, ...obj, createdAt: new Date().toISOString(), deletedAt: null });
  return id;
}

function iso(y, m, d) {
  return new Date(Date.UTC(y, m - 1, d)).toISOString();
}

function hash(password) {
  return crypto.createHash('sha256').update(password + SECRET).digest('hex');
}

function makeSale(customerId, productId, daysAgo, qty, closed = false) {
  const soldAt = new Date(Date.now() + daysAgo * 86400000);
  const id = push('sales', {
    customerId,
    productId,
    quantity: qty,
    soldAt: soldAt.toISOString(),
    closedAt: closed ? new Date().toISOString() : null,
  });
  if (!closed) {
    const product = db.products.find((p) => p.id === productId);
    if (product) {
      product.stockAvailable = Math.max(0, product.stockAvailable - qty);
    }
  }
  return id;
}

// ──────────────────────── развёртывание объектов ────────────────────────

function slimCategory(id) {
  const c = db.categories.find((x) => x.id === id);
  return c ? { id: c.id, name: c.name } : null;
}

function slimSupplier(id) {
  const s = db.suppliers.find((x) => x.id === id);
  return s ? { id: s.id, name: s.name } : null;
}

function expandProduct(p) {
  return {
    id: p.id,
    name: p.name,
    sku: p.sku,
    price: p.price,
    weightGr: p.weightGr,
    category: slimCategory(p.categoryId),
    supplier: slimSupplier(p.supplierId),
    stockTotal: p.stockTotal,
    stockAvailable: p.stockAvailable,
    createdAt: p.createdAt,
    deletedAt: p.deletedAt,
  };
}

function expandCustomer(c) {
  const card = db.cards.find((x) => x.customerId === c.id && !x.deletedAt);
  return {
    id: c.id,
    fullName: c.fullName,
    email: c.email,
    phone: c.phone,
    card: card
      ? {
          id: card.id,
          number: card.number,
          discountPercent: card.discountPercent,
          issuedAt: card.issuedAt,
        }
      : null,
    createdAt: c.createdAt,
    deletedAt: c.deletedAt,
  };
}

function expandSale(s) {
  const customer = db.customers.find((c) => c.id === s.customerId);
  const product = db.products.find((p) => p.id === s.productId);
  return {
    id: s.id,
    customer: customer ? { id: customer.id, fullName: customer.fullName } : null,
    product: product ? { id: product.id, name: product.name } : null,
    quantity: s.quantity,
    soldAt: s.soldAt,
    closedAt: s.closedAt,
    status: s.closedAt ? 'closed' : 'active',
    deletedAt: s.deletedAt,
  };
}

function expandUser(u) {
  return {
    id: u.id,
    username: u.username,
    fullName: u.fullName,
    email: u.email,
    role: u.role,
    customerId: u.customerId,
  };
}

const EXPANDERS = {
  products: expandProduct,
  customers: expandCustomer,
  sales: expandSale,
  categories: (c) => c,
  suppliers: (s) => s,
};

// ─────────────────────────── общие операции ───────────────────────────

function searchableText(collection, item) {
  switch (collection) {
    case 'products':  return [item.name, item.sku].join(' ');
    case 'categories':return [item.name, item.description].join(' ');
    case 'suppliers': return [item.name, item.city, item.phone].join(' ');
    case 'customers': return [item.fullName, item.email, item.phone].join(' ');
    default: return '';
  }
}

function applyFilters(collection, rows, q) {
  let result = rows;

  if (q.search) {
    const needle = String(q.search).toLowerCase();
    result = result.filter((x) =>
      searchableText(collection, x).toLowerCase().includes(needle),
    );
  }

  if (collection === 'products') {
    if (q.categoryId) {
      result = result.filter((p) => p.categoryId === Number(q.categoryId));
    }
    if (q.supplierId) {
      result = result.filter((p) => p.supplierId === Number(q.supplierId));
    }
    if (q.priceFrom) {
      result = result.filter((p) => p.price >= Number(q.priceFrom));
    }
    if (q.priceTo) {
      result = result.filter((p) => p.price <= Number(q.priceTo));
    }
  }

  if (collection === 'sales') {
    if (q.customerId) {
      result = result.filter((s) => s.customerId === Number(q.customerId));
    }
    if (q.productId) {
      result = result.filter((s) => s.productId === Number(q.productId));
    }
    if (q.status) {
      result = result.filter((s) => expandSale(s).status === q.status);
    }
  }

  return result;
}

function applySort(rows, sort) {
  if (!sort) return rows;
  const [field, dirRaw] = String(sort).split(',');
  const dir = (dirRaw || 'asc').toLowerCase() === 'desc' ? -1 : 1;
  return [...rows].sort((a, b) => {
    const av = a[field];
    const bv = b[field];
    if (av == null && bv == null) return 0;
    if (av == null) return 1;
    if (bv == null) return -1;
    if (typeof av === 'number' && typeof bv === 'number') return (av - bv) * dir;
    return String(av).localeCompare(String(bv), 'ru') * dir;
  });
}

function paginate(rows, q) {
  const page = Math.max(1, Number(q.page) || 1);
  const size = Math.min(100, Math.max(1, Number(q.size) || 10));
  const total = rows.length;
  const totalPages = Math.max(1, Math.ceil(total / size));
  return {
    items: rows.slice((page - 1) * size, page * size),
    page,
    size,
    total,
    totalPages,
  };
}

// ─────────────────────────────── валидация ───────────────────────────────

function validate(collection, body, id = null) {
  const e = {};
  const str = (v) => (typeof v === 'string' ? v.trim() : '');

  if (collection === 'products') {
    if (!str(body.name)) e.name = 'Укажите название товара';
    else if (str(body.name).length > 200) e.name = 'Не длиннее 200 символов';

    if (!str(body.sku)) e.sku = 'Укажите артикул';
    else {
      const dup = db.products.find(
        (p) => p.sku === str(body.sku) && p.id !== id && !p.deletedAt,
      );
      if (dup) e.sku = 'Товар с таким артикулом уже существует';
    }

    const price = Number(body.price);
    if (!Number.isFinite(price) || price <= 0) e.price = 'Цена — положительное число';

    const weight = Number(body.weightGr);
    if (!Number.isInteger(weight) || weight < 1) e.weightGr = 'Вес — целое положительное число';

    if (body.categoryId != null &&
        !db.categories.find((c) => c.id === Number(body.categoryId) && !c.deletedAt)) {
      e.categoryId = 'Категория не найдена';
    }
    if (body.supplierId != null &&
        !db.suppliers.find((s) => s.id === Number(body.supplierId) && !s.deletedAt)) {
      e.supplierId = 'Поставщик не найден';
    }

    const total = Number(body.stockTotal);
    if (!Number.isInteger(total) || total < 0) e.stockTotal = 'Запас — целое, не меньше нуля';
  }

  if (collection === 'categories') {
    if (!str(body.name)) e.name = 'Укажите название категории';
    else {
      const dup = db.categories.find(
        (c) => c.name.toLowerCase() === str(body.name).toLowerCase() && c.id !== id && !c.deletedAt,
      );
      if (dup) e.name = 'Такая категория уже существует';
    }
  }

  if (collection === 'suppliers') {
    if (!str(body.name)) e.name = 'Укажите название поставщика';
    if (body.phone != null && str(body.phone).length > 40) e.phone = 'Не длиннее 40 символов';
  }

  if (collection === 'customers') {
    if (!str(body.fullName)) e.fullName = 'Укажите ФИО покупателя';
    if (!str(body.email)) e.email = 'Укажите адрес почты';
    else if (!/^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(str(body.email))) e.email = 'Некорректный адрес почты';
    else {
      const dup = db.customers.find(
        (c) => c.email === str(body.email) && c.id !== id && !c.deletedAt,
      );
      if (dup) e.email = 'Покупатель с такой почтой уже зарегистрирован';
    }
  }

  return e;
}

// ──────────────────────────── HTTP-обвязка ────────────────────────────

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
  res.setHeader('Vary', 'Origin');
}

function send(res, status, payload) {
  cors(res);
  if (payload === undefined || status === 204) {
    res.writeHead(204);
    res.end();
    return;
  }
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function fail(res, status, message) {
  send(res, status, { message });
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    return null;
  }
}

function currentUser(req) {
  const header = req.headers['authorization'] || '';
  if (!header.startsWith('Bearer ')) return null;
  const payload = verify(header.slice(7));
  if (!payload || payload.type !== 'access') return null;
  return db.users.find((u) => u.id === payload.sub && !u.deletedAt) || null;
}

const ROLE_LEVEL = { client: 1, manager: 2, admin: 3 };

function requireRole(res, user, minRole) {
  if (!user) {
    fail(res, 401, 'Требуется аутентификация');
    return false;
  }
  if (ROLE_LEVEL[user.role] < ROLE_LEVEL[minRole]) {
    fail(res, 403, `Операция доступна начиная с роли «${minRole}»`);
    return false;
  }
  return true;
}

const COLLECTIONS = ['products', 'categories', 'suppliers', 'customers', 'sales'];

// ─────────────────────────────── маршруты ───────────────────────────────

async function handle(req, res, url) {
  const q = Object.fromEntries(url.searchParams.entries());
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const method = req.method.toUpperCase();
  const user = currentUser(req);

  if (q.__fail) {
    return fail(res, Number(q.__fail), 'Ошибка вызвана намеренно параметром __fail');
  }

  if (path === '/api/__reset' && method === 'POST') {
    seed();
    return send(res, 200, { message: 'Данные восстановлены в исходное состояние' });
  }

  if (path === '/api/__health' && method === 'GET') {
    return send(res, 200, { status: 'ok', time: new Date().toISOString() });
  }

  // ── аутентификация ──
  if (path === '/api/auth/register' && method === 'POST') {
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');
    const errors = {};
    const username = String(body.username || '').trim();
    const password = String(body.password || '');
    if (username.length < 3) errors.username = 'Логин не короче трёх символов';
    else if (db.users.find((u) => u.username === username)) errors.username = 'Такой логин уже занят';
    if (password.length < 8) errors.password = 'Пароль не короче восьми символов';
    else if (!/\d/.test(password)) errors.password = 'Пароль должен содержать цифру';
    if (body.email && !/^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(String(body.email))) {
      errors.email = 'Некорректный адрес почты';
    }
    if (Object.keys(errors).length) {
      return send(res, 422, { message: 'Ошибка валидации', errors });
    }
    const id = push('users', {
      username,
      passwordHash: hash(password),
      fullName: String(body.fullName || username),
      email: String(body.email || ''),
      role: 'client',
      customerId: null,
    });
    return send(res, 201, expandUser(db.users.find((u) => u.id === id)));
  }

  if (path === '/api/auth/login' && method === 'POST') {
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');
    const found = db.users.find(
      (u) => u.username === String(body.username || '').trim() && !u.deletedAt,
    );
    if (!found || found.passwordHash !== hash(String(body.password || ''))) {
      return fail(res, 401, 'Неверный логин или пароль');
    }
    const now = Math.floor(Date.now() / 1000);
    const accessToken = sign({ sub: found.id, role: found.role, type: 'access', exp: now + ACCESS_TTL });
    const refreshToken = sign({ sub: found.id, type: 'refresh', exp: now + REFRESH_TTL });
    db.refreshTokens.add(refreshToken);
    return send(res, 200, {
      accessToken,
      refreshToken,
      expiresIn: ACCESS_TTL,
      user: expandUser(found),
    });
  }

  if (path === '/api/auth/refresh' && method === 'POST') {
    const body = await readBody(req);
    const token = body && body.refreshToken;
    const payload = verify(token);
    if (!payload || payload.type !== 'refresh' || !db.refreshTokens.has(token)) {
      return fail(res, 401, 'Токен обновления недействителен');
    }
    const found = db.users.find((u) => u.id === payload.sub);
    if (!found) return fail(res, 401, 'Пользователь не найден');
    db.refreshTokens.delete(token);
    const now = Math.floor(Date.now() / 1000);
    const accessToken = sign({ sub: found.id, role: found.role, type: 'access', exp: now + ACCESS_TTL });
    const refreshToken = sign({ sub: found.id, type: 'refresh', exp: now + REFRESH_TTL });
    db.refreshTokens.add(refreshToken);
    return send(res, 200, { accessToken, refreshToken, expiresIn: ACCESS_TTL, user: expandUser(found) });
  }

  if (path === '/api/auth/me' && method === 'GET') {
    if (!user) return fail(res, 401, 'Требуется аутентификация');
    return send(res, 200, expandUser(user));
  }

  if (path === '/api/auth/logout' && method === 'POST') {
    const body = await readBody(req);
    if (body && body.refreshToken) db.refreshTokens.delete(body.refreshToken);
    return send(res, 204);
  }

  if (path === '/api/users' && method === 'GET') {
    if (!requireRole(res, user, 'admin')) return;
    const rows = applySort(db.users.filter((u) => !u.deletedAt), q.sort);
    const page = paginate(rows, q);
    return send(res, 200, { ...page, items: page.items.map(expandUser) });
  }

  // ── продажи ──
  if (path === '/api/sales' && method === 'POST') {
    if (!requireRole(res, user, 'manager')) return;
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const errors = {};
    const customer = db.customers.find((c) => c.id === Number(body.customerId) && !c.deletedAt);
    const product = db.products.find((p) => p.id === Number(body.productId) && !p.deletedAt);
    if (!customer) errors.customerId = 'Покупатель не найден';
    if (!product) errors.productId = 'Товар не найден';
    const qty = Number(body.quantity || 1);
    if (!Number.isInteger(qty) || qty < 1 || qty > 1000) errors.quantity = 'Количество от 1 до 1000';
    if (Object.keys(errors).length) {
      return send(res, 422, { message: 'Ошибка валидации', errors });
    }
    if (product.stockAvailable < qty) {
      return fail(res, 409, 'Недостаточно товара на складе');
    }
    const id = push('sales', {
      customerId: customer.id,
      productId: product.id,
      quantity: qty,
      soldAt: new Date().toISOString(),
      closedAt: null,
    });
    product.stockAvailable -= qty;
    return send(res, 201, expandSale(db.sales.find((s) => s.id === id)));
  }

  let m = path.match(/^\/api\/sales\/(\d+)\/close$/);
  if (m && method === 'POST') {
    if (!requireRole(res, user, 'manager')) return;
    const sale = db.sales.find((s) => s.id === Number(m[1]) && !s.deletedAt);
    if (!sale) return fail(res, 404, 'Продажа не найдена');
    if (sale.closedAt) return fail(res, 409, 'Продажа уже закрыта');
    sale.closedAt = new Date().toISOString();
    return send(res, 200, expandSale(sale));
  }

  // ── CRUD ──
  m = path.match(/^\/api\/([a-z]+)(?:\/(\d+))?(?:\/(restore))?$/);
  const bulk = path.match(/^\/api\/([a-z]+)\/bulk-delete$/);

  if (bulk && method === 'POST') {
    const collection = bulk[1];
    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');
    if (!requireRole(res, user, 'manager')) return;
    const body = await readBody(req);
    const ids = Array.isArray(body && body.ids) ? body.ids.map(Number) : [];
    if (!ids.length) {
      return send(res, 422, {
        message: 'Ошибка валидации',
        errors: { ids: 'Передайте непустой список идентификаторов' },
      });
    }
    let deleted = 0;
    for (const row of db[collection]) {
      if (ids.includes(row.id) && !row.deletedAt) {
        row.deletedAt = new Date().toISOString();
        deleted += 1;
      }
    }
    return send(res, 200, { deleted });
  }

  if (m) {
    const collection = m[1];
    const id = m[2] ? Number(m[2]) : null;
    const action = m[3] || null;

    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');
    const expand = EXPANDERS[collection];

    if (action === 'restore' && method === 'POST') {
      if (!requireRole(res, user, 'admin')) return;
      const row = db[collection].find((x) => x.id === id);
      if (!row) return fail(res, 404, 'Объект не найден');
      row.deletedAt = null;
      return send(res, 200, expand(row));
    }

    if (id === null && method === 'GET') {
      let rows = db[collection];
      if (q.includeDeleted !== 'true') rows = rows.filter((x) => !x.deletedAt);
      if (collection === 'sales' && user && user.role === 'client') {
        rows = rows.filter((s) => s.customerId === user.customerId);
      }
      rows = applyFilters(collection, rows, q);
      rows = applySort(rows, q.sort);
      const page = paginate(rows, q);
      return send(res, 200, { ...page, items: page.items.map(expand) });
    }

    if (id !== null && method === 'GET') {
      const row = db[collection].find(
        (x) => x.id === id && (q.includeDeleted === 'true' || !x.deletedAt),
      );
      if (!row) return fail(res, 404, 'Объект не найден');
      return send(res, 200, expand(row));
    }

    if (id === null && method === 'POST') {
      if (!requireRole(res, user, 'manager')) return;
      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

      const errors = validate(collection, body);
      if (Object.keys(errors).length) {
        return send(res, 422, { message: 'Ошибка валидации', errors });
      }

      const data = normalize(collection, body);
      const newId = push(collection, data);
      const row = db[collection].find((x) => x.id === newId);

      // Карта покупателя создаётся в отдельной коллекции.
      if (collection === 'customers' && data.__card) {
        push('cards', {
          customerId: newId,
          number: data.__card.number,
          discountPercent: data.__card.discountPercent,
          issuedAt: data.__card.issuedAt,
        });
        delete row.__card;
      }

      if (collection === 'products') {
        row.stockAvailable = row.stockTotal;
      }

      return send(res, 201, expand(row));
    }

    if (id !== null && (method === 'PUT' || method === 'PATCH')) {
      if (!requireRole(res, user, 'manager')) return;
      const row = db[collection].find((x) => x.id === id && !x.deletedAt);
      if (!row) return fail(res, 404, 'Объект не найден');
      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');
      const merged = method === 'PATCH' ? { ...row, ...body } : body;
      const errors = validate(collection, merged, id);
      if (Object.keys(errors).length) {
        return send(res, 422, { message: 'Ошибка валидации', errors });
      }
      Object.assign(row, normalize(collection, merged));

      if (collection === 'products') {
        const inUse = db.sales
          .filter((s) => s.productId === id && !s.closedAt && !s.deletedAt)
          .reduce((acc, s) => acc + s.quantity, 0);
        row.stockAvailable = Math.max(0, row.stockTotal - inUse);
      }

            if (collection === 'customers' && body.card) {
              let card = db.cards.find((x) => x.customerId === id && !x.deletedAt);
              const cardData = {
                number: String(body.card.number || '').trim(),
                discountPercent: Number(body.card.discountPercent) || 0,
                issuedAt: String(body.card.issuedAt || new Date().toISOString()),
              };
              if (card) {
                Object.assign(card, cardData);
              } else {
                push('cards', { customerId: id, ...cardData });
              }
            } else if (collection === 'customers' && body.card === null) {
              // Явное снятие карты
              const card = db.cards.find((x) => x.customerId === id && !x.deletedAt);
              if (card) card.deletedAt = new Date().toISOString();
            }

            return send(res, 200, expand(row));
          }

          // удаление
          if (id !== null && method === 'DELETE') {
      const hard = q.hard === 'true';
      if (!requireRole(res, user, hard ? 'admin' : 'librarian')) return;

      const index = db[collection].findIndex((x) => x.id === id);
      if (index === -1) return fail(res, 404, 'Объект не найден');

      // Проверка ссылочной целостности для поставщиков и категорий —
      // она нужна и при логическом, и при физическом удалении.
      if (collection === 'suppliers') {
        const used = db.products.filter((p) => p.supplierId === id && !p.deletedAt).length;
        if (used > 0) {
          return fail(res, 409, `На поставщика ссылаются ${used} товаров`);
        }
      }
      if (collection === 'categories') {
        const used = db.products.filter((p) => p.categoryId === id && !p.deletedAt).length;
        if (used > 0) {
          return fail(res, 409, `На категорию ссылаются ${used} товаров`);
        }
      }


      if (hard) {
        db[collection].splice(index, 1);
      } else {
        db[collection][index].deletedAt = new Date().toISOString();
      }
      return send(res, 204);
    }
  }

  return fail(res, 404, `Адрес ${method} ${path} не обслуживается`);
}

function normalize(collection, body) {
  const num = (v) => (v == null || v === '' ? null : Number(v));
  const str = (v) => (v == null ? '' : String(v).trim());

  switch (collection) {
    case 'products':
      return {
        name: str(body.name),
        sku: str(body.sku),
        price: num(body.price),
        weightGr: num(body.weightGr),
        categoryId: num(body.categoryId),
        supplierId: num(body.supplierId),
        stockTotal: num(body.stockTotal) ?? 0,
      };
    case 'categories':
      return { name: str(body.name), description: str(body.description) };
    case 'suppliers':
      return { name: str(body.name), city: str(body.city), phone: str(body.phone) };
    case 'customers': {
      const result = {
        fullName: str(body.fullName),
        email: str(body.email),
        phone: str(body.phone),
      };
      // Карту сохраним отдельно, чтобы создать после push.
      if (body.card && typeof body.card === 'object') {
        result.__card = {
          number: str(body.card.number),
          discountPercent: Number(body.card.discountPercent) || 0,
          issuedAt: str(body.card.issuedAt) || new Date().toISOString(),
        };
      }
      return result;
    }
    default:
      return { ...body };
  }
}

// ─────────────────────────────── запуск ───────────────────────────────

seed();

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'OPTIONS') {
    cors(res);
    res.writeHead(204);
    return res.end();
  }

  const delay = Number(url.searchParams.get('__delay') || 0);
  if (delay > 0) await new Promise((r) => setTimeout(r, Math.min(delay, 10000)));

  const started = Date.now();
  try {
    await handle(req, res, url);
  } catch (err) {
    console.error(err);
    if (!res.headersSent) fail(res, 500, 'Внутренняя ошибка сервера: ' + err.message);
  }
  console.log(
    `${req.method.padEnd(6)} ${url.pathname}${url.search}  → ${res.statusCode}  ${Date.now() - started} мс`,
  );
});

server.listen(PORT, () => {
  console.log('');
  console.log('  Учебное API «Продуктовый магазин»');
  console.log(`  Адрес:              http://localhost:${PORT}/api`);
  console.log(`  Разрешённый источник: ${ORIGIN}`);
  console.log(`  Срок жизни токена:  ${ACCESS_TTL} с`);
  console.log('');
  console.log('  Учётные записи:  admin/admin123   manager/manager123   client/client123');
  console.log('  Сброс данных:    POST /api/__reset');
  console.log('  Задержка ответа: любой запрос с ?__delay=1500');
  console.log('  Ошибка по требованию: любой запрос с ?__fail=500');
  console.log('');
});