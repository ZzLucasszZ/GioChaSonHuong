# 📦 Hệ thống Quản lý Đơn hàng & Tồn kho

**Phiên bản:** 2.0  
**Cập nhật:** 04/02/2026  
**Kiến trúc:** Local-first (SQLite) - Không cần Backend

---

## 🎯 Mục tiêu

Ứng dụng Android quản lý đơn hàng cho nhà cung cấp thực phẩm:
- **1 người dùng** (chủ doanh nghiệp)
- **Chạy offline** hoàn toàn trên Android
- **Dữ liệu local** với SQLite

---

## 📦 Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Database
  sqflite: ^2.3.0
  path: ^1.8.3
  
  # State Management
  provider: ^6.0.5
  
  # Utilities
  intl: ^0.19.0              # Date/Currency formatting
  uuid: ^4.2.1               # Generate unique IDs
  
  # PDF & Sharing
  pdf: ^3.10.0               # PDF generation
  printing: ^5.12.0          # Print PDF
  share_plus: ^7.2.0         # Share to Zalo/SMS
  path_provider: ^2.1.1      # Get storage path
  url_launcher: ^6.2.0       # Open Zalo/Phone
  
  # UI Components
  flutter_slidable: ^3.0.0   # Swipe actions
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

---

## 🗄️ Database Schema

### ERD (Entity Relationship Diagram)

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│ restaurants │────<│ restaurant_prices│>────│  products   │
└─────────────┘     └──────────────────┘     └─────────────┘
       │                                            │
       │                                            │
       ▼                                            ▼
┌─────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│   orders    │────<│   order_items    │>────│ inventory_transactions│
└─────────────┘     └──────────────────┘     └─────────────────────┘
       │
       │
       ▼
┌─────────────┐
│  payments   │
└─────────────┘
```

### Quan hệ:
- 1 Restaurant → N Orders
- 1 Restaurant → N Restaurant_Prices
- 1 Product → N Restaurant_Prices
- 1 Product → N Order_Items
- 1 Product → N Inventory_Transactions
- 1 Order → N Order_Items
- 1 Order → N Payments

---

## 📋 Table Definitions

### 1. restaurants
```sql
CREATE TABLE restaurants (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    contact_person TEXT,
    phone TEXT NOT NULL,
    address TEXT NOT NULL,
    notes TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX idx_restaurants_name ON restaurants(name);
CREATE INDEX idx_restaurants_active ON restaurants(is_active);
```

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✓ | Primary key |
| name | TEXT | ✓ | Tên nhà hàng |
| contact_person | TEXT | | Người liên hệ |
| phone | TEXT | ✓ | Số điện thoại |
| address | TEXT | ✓ | Địa chỉ giao hàng |
| notes | TEXT | | Ghi chú |
| is_active | INTEGER | | 1=Hoạt động, 0=Ngừng |
| created_at | TEXT | ✓ | ISO8601 datetime |
| updated_at | TEXT | ✓ | ISO8601 datetime |

---

### 2. products
```sql
CREATE TABLE products (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    sku TEXT UNIQUE,
    unit TEXT NOT NULL,
    base_price REAL NOT NULL DEFAULT 0,
    current_stock REAL NOT NULL DEFAULT 0,
    min_stock_alert REAL NOT NULL DEFAULT 0,
    category TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_stock_alert ON products(current_stock, min_stock_alert);
```

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✓ | Primary key |
| name | TEXT | ✓ | Tên sản phẩm |
| sku | TEXT | | Mã sản phẩm (unique) |
| unit | TEXT | ✓ | Đơn vị (kg, thùng, chai...) |
| base_price | REAL | ✓ | Giá mặc định |
| current_stock | REAL | ✓ | Tồn kho hiện tại |
| min_stock_alert | REAL | ✓ | Mức cảnh báo tồn kho |
| category | TEXT | | Danh mục |
| is_active | INTEGER | | 1=Đang bán, 0=Ngừng |
| created_at | TEXT | ✓ | ISO8601 datetime |
| updated_at | TEXT | ✓ | ISO8601 datetime |

**Categories (gợi ý):**
- `meat` - Thịt
- `seafood` - Hải sản
- `vegetable` - Rau củ
- `fruit` - Trái cây
- `spice` - Gia vị
- `drink` - Đồ uống
- `other` - Khác

---

### 3. restaurant_prices
```sql
CREATE TABLE restaurant_prices (
    id TEXT PRIMARY KEY,
    restaurant_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    price REAL NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (restaurant_id) REFERENCES restaurants(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    UNIQUE(restaurant_id, product_id)
);

CREATE INDEX idx_restaurant_prices_restaurant ON restaurant_prices(restaurant_id);
CREATE INDEX idx_restaurant_prices_product ON restaurant_prices(product_id);
```

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✓ | Primary key |
| restaurant_id | TEXT | ✓ | FK → restaurants |
| product_id | TEXT | ✓ | FK → products |
| price | REAL | ✓ | Giá riêng cho nhà hàng này |
| created_at | TEXT | ✓ | ISO8601 datetime |
| updated_at | TEXT | ✓ | ISO8601 datetime |

**Logic lấy giá:**
```dart
// Ưu tiên: restaurant_prices.price > products.base_price
double getPrice(String restaurantId, String productId) {
  final customPrice = restaurantPrices.find(restaurantId, productId);
  return customPrice?.price ?? product.basePrice;
}
```

---

### 4. orders
```sql
CREATE TABLE orders (
    id TEXT PRIMARY KEY,
    restaurant_id TEXT NOT NULL,
    order_date TEXT NOT NULL,
    delivery_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    total_amount REAL NOT NULL DEFAULT 0,
    paid_amount REAL NOT NULL DEFAULT 0,
    payment_status TEXT NOT NULL DEFAULT 'unpaid',
    notes TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (restaurant_id) REFERENCES restaurants(id) ON DELETE RESTRICT
);

CREATE INDEX idx_orders_restaurant ON orders(restaurant_id);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_orders_delivery_date ON orders(delivery_date);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_payment_status ON orders(payment_status);
```

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✓ | Primary key |
| restaurant_id | TEXT | ✓ | FK → restaurants |
| order_date | TEXT | ✓ | Ngày đặt (yyyy-MM-dd) |
| delivery_date | TEXT | ✓ | Ngày giao (yyyy-MM-dd) |
| status | TEXT | ✓ | Trạng thái đơn |
| total_amount | REAL | ✓ | Tổng tiền |
| paid_amount | REAL | ✓ | Đã thanh toán |
| payment_status | TEXT | ✓ | Trạng thái thanh toán |
| notes | TEXT | | Ghi chú |
| created_at | TEXT | ✓ | ISO8601 datetime |
| updated_at | TEXT | ✓ | ISO8601 datetime |

**Order Status:**
| Value | Display | Description | Can Edit | Can Delete |
|-------|---------|-------------|----------|------------|
| `pending` | Chờ xử lý | Mới tạo | ✓ | ✓ |
| `confirmed` | Đã xác nhận | Đã duyệt | ✓ | ✓ |
| `delivering` | Đang giao | Đang vận chuyển | ✗ | ✗ |
| `delivered` | Đã giao | Hoàn thành | ✗ | ✗ |
| `cancelled` | Đã hủy | Bị hủy | ✗ | ✗ |

**Payment Status:**
| Value | Display | Condition |
|-------|---------|-----------|
| `unpaid` | Chưa thanh toán | paid_amount = 0 |
| `partial` | Thanh toán một phần | 0 < paid_amount < total_amount |
| `paid` | Đã thanh toán | paid_amount >= total_amount |

---

### 5. order_items
```sql
CREATE TABLE order_items (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    product_name TEXT NOT NULL,
    unit TEXT NOT NULL,
    quantity REAL NOT NULL,
    unit_price REAL NOT NULL,
    subtotal REAL NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
```

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✓ | Primary key |
| order_id | TEXT | ✓ | FK → orders |
| product_id | TEXT | ✓ | FK → products |
| product_name | TEXT | ✓ | Tên SP lúc đặt (snapshot) |
| unit | TEXT | ✓ | Đơn vị lúc đặt (snapshot) |
| quantity | REAL | ✓ | Số lượng |
| unit_price | REAL | ✓ | Giá lúc đặt (snapshot) |
| subtotal | REAL | ✓ | = quantity × unit_price |

**Lưu ý:** `product_name`, `unit`, `unit_price` là **snapshot** - lưu giá trị tại thời điểm đặt hàng, không thay đổi khi sản phẩm được cập nhật.

---

### 6. inventory_transactions
```sql
CREATE TABLE inventory_transactions (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL,
    type TEXT NOT NULL,
    quantity REAL NOT NULL,
    stock_before REAL NOT NULL,
    stock_after REAL NOT NULL,
    reference_type TEXT,
    reference_id TEXT,
    notes TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

CREATE INDEX idx_inventory_product ON inventory_transactions(product_id);
CREATE INDEX idx_inventory_type ON inventory_transactions(type);
CREATE INDEX idx_inventory_created ON inventory_transactions(created_at);
CREATE INDEX idx_inventory_reference ON inventory_transactions(reference_type, reference_id);
```

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✓ | Primary key |
| product_id | TEXT | ✓ | FK → products |
| type | TEXT | ✓ | Loại giao dịch |
| quantity | REAL | ✓ | Số lượng (+/-) |
| stock_before | REAL | ✓ | Tồn kho trước |
| stock_after | REAL | ✓ | Tồn kho sau |
| reference_type | TEXT | | 'order' hoặc null |
| reference_id | TEXT | | order_id nếu xuất hàng |
| notes | TEXT | | Ghi chú |
| created_at | TEXT | ✓ | ISO8601 datetime |

**Transaction Types:**
| Value | Display | Quantity | Description |
|-------|---------|----------|-------------|
| `import` | Nhập kho | + | Nhập hàng vào kho |
| `export` | Xuất kho | - | Xuất cho đơn hàng |
| `adjustment_add` | Điều chỉnh tăng | + | Kiểm kê thừa |
| `adjustment_sub` | Điều chỉnh giảm | - | Kiểm kê thiếu |
| `return` | Hàng trả lại | + | Khách trả hàng |

---

### 7. payments
```sql
CREATE TABLE payments (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    amount REAL NOT NULL,
    payment_method TEXT NOT NULL,
    notes TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_created ON payments(created_at);
CREATE INDEX idx_payments_method ON payments(payment_method);
```

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | TEXT (UUID) | ✓ | Primary key |
| order_id | TEXT | ✓ | FK → orders |
| amount | REAL | ✓ | Số tiền thanh toán |
| payment_method | TEXT | ✓ | Phương thức |
| notes | TEXT | | Ghi chú |
| created_at | TEXT | ✓ | ISO8601 datetime |

**Payment Methods:**
| Value | Display |
|-------|---------|
| `cash` | Tiền mặt |
| `bank_transfer` | Chuyển khoản |
| `momo` | Ví MoMo |
| `zalo_pay` | ZaloPay |

---

### 8. app_settings
```sql
CREATE TABLE app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

**Settings Keys:**
| Key | Default | Description |
|-----|---------|-------------|
| `company_name` | "" | Tên công ty (in hóa đơn) |
| `company_phone` | "" | SĐT công ty |
| `company_address` | "" | Địa chỉ công ty |
| `default_delivery_days` | "1" | Số ngày giao mặc định |

---

## 📁 Project Structure

```
lib/
├── main.dart                          # Entry point
├── app.dart                           # MaterialApp configuration
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart         # App-wide constants
│   │   ├── db_constants.dart          # Database table/column names
│   │   └── route_constants.dart       # Route names
│   │
│   ├── theme/
│   │   ├── app_theme.dart             # ThemeData
│   │   └── app_colors.dart            # Color palette
│   │
│   └── utils/
│       ├── date_utils.dart            # Date formatting helpers
│       ├── currency_utils.dart        # Currency formatting
│       ├── validators.dart            # Input validation
│       └── extensions.dart            # Dart extensions
│
├── data/
│   ├── database/
│   │   ├── database_helper.dart       # SQLite connection & init
│   │   └── migrations/
│   │       └── migration_v1.dart      # Initial schema
│   │
│   ├── models/
│   │   ├── restaurant.dart
│   │   ├── product.dart
│   │   ├── restaurant_price.dart
│   │   ├── order.dart
│   │   ├── order_item.dart
│   │   ├── inventory_transaction.dart
│   │   ├── payment.dart
│   │   └── app_setting.dart
│   │
│   └── repositories/
│       ├── base_repository.dart       # Abstract base
│       ├── restaurant_repository.dart
│       ├── product_repository.dart
│       ├── restaurant_price_repository.dart
│       ├── order_repository.dart
│       ├── inventory_repository.dart
│       ├── payment_repository.dart
│       └── settings_repository.dart
│
├── providers/
│   ├── restaurant_provider.dart
│   ├── product_provider.dart
│   ├── order_provider.dart
│   ├── inventory_provider.dart
│   ├── payment_provider.dart
│   └── settings_provider.dart
│
├── screens/
│   ├── home/
│   │   └── home_screen.dart           # Bottom nav container
│   │
│   ├── dashboard/
│   │   ├── dashboard_screen.dart
│   │   └── widgets/
│   │       ├── summary_card.dart
│   │       ├── low_stock_card.dart
│   │       └── today_deliveries_card.dart
│   │
│   ├── restaurants/
│   │   ├── restaurant_list_screen.dart
│   │   ├── restaurant_form_screen.dart
│   │   ├── restaurant_detail_screen.dart
│   │   ├── restaurant_prices_screen.dart
│   │   └── widgets/
│   │       └── restaurant_card.dart
│   │
│   ├── products/
│   │   ├── product_list_screen.dart
│   │   ├── product_form_screen.dart
│   │   └── widgets/
│   │       └── product_card.dart
│   │
│   ├── orders/
│   │   ├── order_list_screen.dart
│   │   ├── order_form_screen.dart
│   │   ├── order_detail_screen.dart
│   │   └── widgets/
│   │       ├── order_card.dart
│   │       ├── order_item_row.dart
│   │       └── product_selector_dialog.dart
│   │
│   ├── deliveries/
│   │   ├── delivery_list_screen.dart
│   │   └── widgets/
│   │       └── delivery_card.dart
│   │
│   ├── inventory/
│   │   ├── inventory_list_screen.dart
│   │   ├── inventory_import_screen.dart
│   │   ├── inventory_history_screen.dart
│   │   └── widgets/
│   │       └── stock_item_card.dart
│   │
│   ├── payments/
│   │   ├── debt_list_screen.dart
│   │   ├── payment_form_screen.dart
│   │   └── widgets/
│   │       └── debt_card.dart
│   │
│   └── settings/
│       └── settings_screen.dart
│
├── widgets/
│   ├── common/
│   │   ├── app_drawer.dart
│   │   ├── loading_widget.dart
│   │   ├── empty_state_widget.dart
│   │   ├── error_widget.dart
│   │   ├── confirm_dialog.dart
│   │   └── search_bar.dart
│   │
│   └── forms/
│       ├── app_text_field.dart
│       ├── app_dropdown.dart
│       ├── app_date_picker.dart
│       └── app_number_field.dart
│
└── services/
    ├── pdf_service.dart               # Generate PDF invoice
    ├── share_service.dart             # Share to Zalo/SMS
    └── backup_service.dart            # Export/Import database
```

---

## 🧩 Model Classes

### Restaurant
```dart
class Restaurant {
  final String id;
  final String name;
  final String? contactPerson;
  final String phone;
  final String address;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Constructor, copyWith, toMap, fromMap, toString, ==, hashCode
}
```

### Product
```dart
class Product {
  final String id;
  final String name;
  final String? sku;
  final String unit;
  final double basePrice;
  final double currentStock;
  final double minStockAlert;
  final String? category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed
  bool get isLowStock => currentStock <= minStockAlert;
  bool get isOutOfStock => currentStock <= 0;
}
```

### RestaurantPrice
```dart
class RestaurantPrice {
  final String id;
  final String restaurantId;
  final String productId;
  final double price;
  final DateTime createdAt;
  final DateTime updatedAt;

  // For display (joined data)
  final String? productName;
  final String? productUnit;
  final double? productBasePrice;
}
```

### Order
```dart
enum OrderStatus { pending, confirmed, delivering, delivered, cancelled }
enum PaymentStatus { unpaid, partial, paid }

class Order {
  final String id;
  final String restaurantId;
  final DateTime orderDate;
  final DateTime deliveryDate;
  final OrderStatus status;
  final double totalAmount;
  final double paidAmount;
  final PaymentStatus paymentStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // For display (joined data)
  final String? restaurantName;
  final String? restaurantPhone;
  final String? restaurantAddress;
  final List<OrderItem>? items;

  // Computed
  double get debtAmount => totalAmount - paidAmount;
  bool get canEdit => status == OrderStatus.pending || status == OrderStatus.confirmed;
  bool get canDelete => status == OrderStatus.pending || status == OrderStatus.confirmed;
  bool get canMarkDelivered => status == OrderStatus.pending || 
                               status == OrderStatus.confirmed || 
                               status == OrderStatus.delivering;
}
```

### OrderItem
```dart
class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productName;  // Snapshot
  final String unit;         // Snapshot
  final double quantity;
  final double unitPrice;    // Snapshot
  final double subtotal;
}
```

### InventoryTransaction
```dart
enum TransactionType { import, export, adjustmentAdd, adjustmentSub, return_ }

class InventoryTransaction {
  final String id;
  final String productId;
  final TransactionType type;
  final double quantity;
  final double stockBefore;
  final double stockAfter;
  final String? referenceType;
  final String? referenceId;
  final String? notes;
  final DateTime createdAt;

  // For display
  final String? productName;
  final String? productUnit;
}
```

### Payment
```dart
enum PaymentMethod { cash, bankTransfer, momo, zaloPay }

class Payment {
  final String id;
  final String orderId;
  final double amount;
  final PaymentMethod paymentMethod;
  final String? notes;
  final DateTime createdAt;
}
```

---

## 🔄 Business Flows

### Flow 1: Tạo Đơn hàng

```
┌──────────────────────────────────────────────────────────────┐
│                    TẠO ĐƠN HÀNG                              │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ 1. Chọn nhà hàng                                             │
│    - Load danh sách nhà hàng (is_active = 1)                 │
│    - Hiển thị: name, phone, address                          │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. Chọn ngày giao                                            │
│    - Ngày đặt: auto = today                                  │
│    - Ngày giao: default = today + default_delivery_days      │
│    - Validate: delivery_date >= order_date                   │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ 3. Thêm sản phẩm                                             │
│    - Load danh sách sản phẩm (is_active = 1)                 │
│    - Lấy giá: restaurant_prices.price ?? products.base_price │
│    - Nhập số lượng                                           │
│    - Kiểm tra tồn kho:                                       │
│      • quantity <= current_stock → OK                        │
│      • quantity > current_stock → Warning (vẫn cho đặt)      │
│    - Tính subtotal = quantity × unit_price                   │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ 4. Lưu đơn hàng                                              │
│    - Tính total_amount = SUM(subtotal)                       │
│    - INSERT orders (status='pending', payment_status='unpaid')│
│    - INSERT order_items (với snapshot giá, tên, đơn vị)      │
│    - KHÔNG trừ tồn kho (chờ giao hàng)                       │
└──────────────────────────────────────────────────────────────┘
```

### Flow 2: Xác nhận Giao hàng

```
┌──────────────────────────────────────────────────────────────┐
│                 XÁC NHẬN GIAO HÀNG                           │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ 1. Kiểm tra điều kiện                                        │
│    - status IN ('pending', 'confirmed', 'delivering')        │
│    - Nếu không → hiển thị lỗi                                │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. Transaction (tất cả hoặc không gì cả)                     │
│    BEGIN TRANSACTION                                         │
│                                                              │
│    a. UPDATE orders SET status = 'delivered'                 │
│                                                              │
│    b. Với mỗi order_item:                                    │
│       - Lấy current_stock của product                        │
│       - INSERT inventory_transactions:                       │
│         • type = 'export'                                    │
│         • quantity = -item.quantity                          │
│         • stock_before = current_stock                       │
│         • stock_after = current_stock - item.quantity        │
│         • reference_type = 'order'                           │
│         • reference_id = order.id                            │
│       - UPDATE products SET current_stock -= item.quantity   │
│                                                              │
│    COMMIT                                                    │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ 3. Refresh UI                                                │
│    - Reload order detail                                     │
│    - Reload inventory (nếu đang xem)                         │
│    - Update dashboard                                        │
└──────────────────────────────────────────────────────────────┘
```

### Flow 3: Nhập kho

```
┌──────────────────────────────────────────────────────────────┐
│                      NHẬP KHO                                │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ 1. Chọn sản phẩm & nhập số lượng                             │
│    - Load danh sách sản phẩm                                 │
│    - Nhập quantity > 0                                       │
│    - Có thể nhập nhiều sản phẩm cùng lúc                     │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. Lưu (Transaction)                                         │
│    BEGIN TRANSACTION                                         │
│                                                              │
│    Với mỗi sản phẩm:                                         │
│    - Lấy current_stock                                       │
│    - INSERT inventory_transactions:                          │
│      • type = 'import'                                       │
│      • quantity = +input.quantity                            │
│      • stock_before = current_stock                          │
│      • stock_after = current_stock + input.quantity          │
│    - UPDATE products SET current_stock += input.quantity     │
│                                                              │
│    COMMIT                                                    │
└──────────────────────────────────────────────────────────────┘
```

### Flow 4: Thanh toán

```
┌──────────────────────────────────────────────────────────────┐
│                    THANH TOÁN                                │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ 1. Nhập thông tin thanh toán                                 │
│    - Số tiền (amount) > 0                                    │
│    - Phương thức thanh toán                                  │
│    - Ghi chú (optional)                                      │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. Lưu (Transaction)                                         │
│    BEGIN TRANSACTION                                         │
│                                                              │
│    - INSERT payments                                         │
│    - Tính new_paid = SUM(payments.amount) WHERE order_id     │
│    - UPDATE orders SET                                       │
│      • paid_amount = new_paid                                │
│      • payment_status = CASE                                 │
│          WHEN new_paid = 0 THEN 'unpaid'                     │
│          WHEN new_paid < total_amount THEN 'partial'         │
│          ELSE 'paid'                                         │
│        END                                                   │
│                                                              │
│    COMMIT                                                    │
└──────────────────────────────────────────────────────────────┘
```

---

## 📱 Screen Specifications

### Navigation (Bottom Navigation Bar)
```
┌─────────┬─────────┬─────────┬─────────┬─────────┐
│  🏠     │  📦     │  🛒     │  💰     │  ☰      │
│ Tổng quan│ Sản phẩm│ Đơn hàng│ Công nợ │  Menu   │
└─────────┴─────────┴─────────┴─────────┴─────────┘
```

### Drawer Menu
```
┌─────────────────────────────────────┐
│  📱 Order Manager                   │
│  version 1.0.0                      │
├─────────────────────────────────────┤
│  🏪 Quản lý Nhà hàng               │
│  🚚 Giao hàng hôm nay              │
│  📊 Quản lý Tồn kho                │
│  📥 Nhập hàng                      │
├─────────────────────────────────────┤
│  ⚙️ Cài đặt                        │
│  💾 Sao lưu dữ liệu                │
└─────────────────────────────────────┘
```

---

### Screen: Dashboard (Tab 1)
**Route:** `/dashboard`

**Components:**
1. **Summary Cards** (2x2 grid)
   - Đơn hôm nay: COUNT orders WHERE order_date = today
   - Cần giao: COUNT orders WHERE delivery_date = today AND status != 'delivered'
   - Tổng công nợ: SUM(total_amount - paid_amount) WHERE payment_status != 'paid'
   - Tồn kho thấp: COUNT products WHERE current_stock <= min_stock_alert

2. **Low Stock Alert** (expandable card)
   - Query: products WHERE current_stock <= min_stock_alert
   - Show: name, current_stock, unit, min_stock_alert
   - Action: Tap → go to Import screen

3. **Today's Deliveries** (list)
   - Query: orders WHERE delivery_date = today ORDER BY restaurant_name
   - Show: restaurant_name, total_amount, status
   - Action: Tap → Order detail

---

### Screen: Product List (Tab 2)
**Route:** `/products`

**Components:**
1. **Search bar** - Filter by name/sku
2. **Category filter** - Dropdown/Chips
3. **Product list** (ListView)
   - Show: name, sku, current_stock, unit, base_price
   - Badge: ⚠️ if isLowStock
   - Swipe actions: Edit, Delete (if no orders)

**FAB:** Add new product

---

### Screen: Product Form
**Route:** `/products/add` or `/products/edit/:id`

**Fields:**
| Field | Type | Required | Validation |
|-------|------|----------|------------|
| Tên sản phẩm | TextField | ✓ | Not empty |
| Mã SP (SKU) | TextField | | Unique if provided |
| Đơn vị | Dropdown | ✓ | Select from list |
| Giá mặc định | Number | ✓ | >= 0 |
| Tồn kho | Number | ✓ | >= 0 |
| Mức cảnh báo | Number | ✓ | >= 0 |
| Danh mục | Dropdown | | Select from list |

**Units list:** kg, g, lít, ml, chai, lon, thùng, hộp, gói, cái, con, bó, chục

---

### Screen: Order List (Tab 3)
**Route:** `/orders`

**Components:**
1. **Date filter** - Select date range
2. **Status filter** - Chips (All, Pending, Delivered...)
3. **Order list** (ListView)
   - Show: #id, restaurant_name, delivery_date, total_amount, status, payment_status
   - Color code by status

**FAB:** Create new order

---

### Screen: Order Form
**Route:** `/orders/add` or `/orders/edit/:id`

**Sections:**
1. **Header**
   - Nhà hàng: Dropdown (required)
   - Ngày đặt: DatePicker (default: today)
   - Ngày giao: DatePicker (default: today + 1)

2. **Products** (dynamic list)
   - Button: [+ Thêm sản phẩm]
   - Each item: Product dropdown, Quantity input, Price (auto), Subtotal
   - Swipe to remove

3. **Footer**
   - Ghi chú: TextField (multiline)
   - Tổng cộng: Calculated sum

**Validations:**
- At least 1 product
- Quantity > 0
- Delivery date >= Order date

---

### Screen: Order Detail
**Route:** `/orders/:id`

**Sections:**
1. **Status bar** - Current status with change dropdown
2. **Restaurant info** - Name, phone (tappable), address
3. **Dates** - Order date, Delivery date
4. **Items table** - Product, Qty, Price, Subtotal
5. **Payment info** - Total, Paid, Debt
6. **Payment history** - List of payments
7. **Actions:**
   - [Sửa] - if canEdit
   - [In PDF]
   - [Chia sẻ]
   - [Thanh toán] - if debt > 0
   - [Đã giao] - if canMarkDelivered

---

### Screen: Debt List (Tab 4)
**Route:** `/debts`

**Query:**
```sql
SELECT 
  r.id, r.name, r.phone,
  SUM(o.total_amount) as total_orders,
  SUM(o.paid_amount) as total_paid,
  SUM(o.total_amount - o.paid_amount) as total_debt
FROM restaurants r
JOIN orders o ON o.restaurant_id = r.id
WHERE o.payment_status != 'paid'
GROUP BY r.id
HAVING total_debt > 0
ORDER BY total_debt DESC
```

**Components:**
1. **Summary header** - Tổng công nợ
2. **Restaurant debt list**
   - Show: name, phone, total_debt
   - Tap → Restaurant debt detail

---

### Screen: Restaurant List
**Route:** `/restaurants`

**Components:**
1. **Search bar** - Filter by name/phone
2. **Restaurant list** (ListView)
   - Show: name, contact_person, phone, address
   - Badge: Active/Inactive

**FAB:** Add new restaurant

---

### Screen: Restaurant Prices
**Route:** `/restaurants/:id/prices`

**Query:**
```sql
SELECT 
  p.id, p.name, p.unit, p.base_price,
  rp.price as custom_price
FROM products p
LEFT JOIN restaurant_prices rp 
  ON rp.product_id = p.id AND rp.restaurant_id = :restaurantId
WHERE p.is_active = 1
ORDER BY p.name
```

**Components:**
1. **Product price list**
   - Show: name, unit, base_price, custom_price (editable)
   - Inline edit: Tap price → TextField → Save

---

### Screen: Inventory
**Route:** `/inventory`

**Tabs:**
1. **Tồn kho** - Current stock list
2. **Lịch sử** - Transaction history

**Stock list query:**
```sql
SELECT * FROM products 
WHERE is_active = 1 
ORDER BY 
  CASE WHEN current_stock <= min_stock_alert THEN 0 ELSE 1 END,
  name
```

**FAB:** Import stock

---

### Screen: Import Stock
**Route:** `/inventory/import`

**Components:**
1. **Product selector** - Dropdown
2. **Quantity input** - Number
3. **Add button** - Add to import list
4. **Import list** - Products to import
5. **Notes** - Optional
6. **Save button** - Process import

---

## 🎨 Theme & Colors

```dart
class AppColors {
  // Primary
  static const primary = Color(0xFF1976D2);       // Blue
  static const primaryLight = Color(0xFF42A5F5);
  static const primaryDark = Color(0xFF1565C0);
  
  // Status colors
  static const success = Color(0xFF4CAF50);       // Green
  static const warning = Color(0xFFFFA726);       // Orange
  static const error = Color(0xFFF44336);         // Red
  static const info = Color(0xFF29B6F6);          // Light Blue
  
  // Order status
  static const pending = Color(0xFFFFA726);       // Orange
  static const confirmed = Color(0xFF42A5F5);     // Blue
  static const delivering = Color(0xFF7E57C2);    // Purple
  static const delivered = Color(0xFF66BB6A);     // Green
  static const cancelled = Color(0xFF9E9E9E);     // Grey
  
  // Payment status
  static const unpaid = Color(0xFFF44336);        // Red
  static const partial = Color(0xFFFFA726);       // Orange
  static const paid = Color(0xFF4CAF50);          // Green
  
  // Background
  static const background = Color(0xFFF5F5F5);
  static const surface = Colors.white;
  static const card = Colors.white;
  
  // Text
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const textHint = Color(0xFFBDBDBD);
}
```

---

## 🚀 Implementation Order

### Phase 1: Core Setup ⏱️ 2-3 hours
1. ✅ pubspec.yaml (dependencies)
2. [ ] Project structure (folders)
3. [ ] Database helper + migrations
4. [ ] All model classes
5. [ ] All repositories (CRUD)
6. [ ] App theme & colors

### Phase 2: Basic CRUD ⏱️ 3-4 hours
1. [ ] Restaurant CRUD screens
2. [ ] Product CRUD screens
3. [ ] Basic navigation (drawer + bottom nav)

### Phase 3: Orders ⏱️ 4-5 hours
1. [ ] Restaurant prices screen
2. [ ] Order list screen
3. [ ] Order form (create/edit)
4. [ ] Order detail screen
5. [ ] Delivery confirmation logic

### Phase 4: Inventory ⏱️ 2-3 hours
1. [ ] Stock list screen
2. [ ] Import stock screen
3. [ ] Transaction history

### Phase 5: Payments ⏱️ 2-3 hours
1. [ ] Debt list screen
2. [ ] Payment form
3. [ ] Payment history

### Phase 6: Dashboard & Polish ⏱️ 2-3 hours
1. [ ] Dashboard screen
2. [ ] Summary calculations
3. [ ] Low stock alerts

### Phase 7: PDF & Share ⏱️ 2-3 hours
1. [ ] PDF invoice template
2. [ ] Share functionality
3. [ ] Settings screen

### Phase 8: Backup & Test ⏱️ 2-3 hours
1. [ ] Export/Import database
2. [ ] Testing on real device
3. [ ] Bug fixes

**Total estimated: ~20-25 hours**

---

## 📝 Notes

### SQLite Best Practices
1. Luôn dùng **parameterized queries** để tránh SQL injection
2. Dùng **transactions** cho operations liên quan nhiều bảng
3. Tạo **indexes** cho các cột hay query (đã định nghĩa ở trên)
4. Dùng **TEXT** cho dates (ISO8601 format) để dễ compare

### Flutter Best Practices
1. Tách **Model** và **Repository** rõ ràng
2. **Provider** cho state management đơn giản
3. Dùng **const constructors** khi có thể
4. **Null safety** - handle null properly
5. **Form validation** trước khi save

### Backup Strategy
1. Export database file (.db) ra external storage
2. Import từ file .db
3. Định kỳ nhắc user backup

---

**🎯 Ready to code! Start with Phase 1.**
