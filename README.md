# 📦 Giò Chả Sơn Hương — Quản lý Đơn hàng & Tồn kho

Ứng dụng Flutter quản lý đơn hàng, tồn kho và công nợ cho nhà cung cấp thực phẩm.  
Chạy **offline hoàn toàn** trên Android (hỗ trợ Windows để debug). Dành cho 1 người dùng (chủ doanh nghiệp).

---

## Tính năng chính

| Module | Mô tả |
|--------|-------|
| **Đặt hàng** | Tạo/sửa đơn theo nhà hàng, ngày giao, buổi (Sáng/Chiều). Tính tự động theo số bàn |
| **Tồn kho** | Nhập/xuất kho, cảnh báo tồn kho thấp, lịch sử giao dịch |
| **Công nợ** | Theo dõi nợ theo nhà hàng, thanh toán từng phần hoặc toàn bộ |
| **Giao hàng** | Xác nhận giao hàng → tự động trừ kho (atomic transaction) |
| **Sản phẩm** | CRUD sản phẩm, giá riêng theo nhà hàng, phân loại theo danh mục |
| **Backup** | JSON export/import + Google Drive auto-backup (throttled 1 lần/giờ, giữ 5 bản) |
| **Chia sẻ** | Share đơn hàng/công nợ qua Zalo, SMS. In PDF hóa đơn |

---

## Tech Stack

| Thành phần | Package | Ghi chú |
|---|---|---|
| Database | `sqflite` + `sqflite_common_ffi` | SQLite local, FFI cho desktop |
| State | `provider` | ChangeNotifier pattern |
| PDF | `pdf` + `printing` | Tạo & in hóa đơn |
| Chia sẻ | `share_plus` + `url_launcher` | Zalo/SMS, gọi điện |
| Backup | `google_sign_in` + `googleapis` | Google Drive |
| File | `file_picker` + `path_provider` | Chọn & lưu file |
| UI | `flutter_slidable` | Swipe actions |
| Locale | `intl` + `flutter_localizations` | Tiếng Việt (`vi_VN`) |

---

## Cấu trúc dự án

```
lib/
├── main.dart                         # Entry point
├── core/
│   ├── constants/
│   │   ├── app_constants.dart        # Units, categories, date formats
│   │   └── db_constants.dart         # Tên bảng & cột (KHÔNG hardcode)
│   ├── theme/
│   │   ├── app_theme.dart            # Material 3 ThemeData
│   │   └── app_colors.dart           # Color palette
│   └── utils/
│       ├── currency_formatter.dart   # TextInputFormatter cho VND
│       ├── currency_utils.dart       # Format tiền VND (150.000 đ)
│       ├── date_utils.dart           # Format ngày tiếng Việt
│       ├── error_dialog.dart         # Dialog hiển thị lỗi
│       ├── logger.dart               # AppLogger thay print()
│       ├── thousands_separator_formatter.dart
│       ├── validators.dart           # Validate input form
│       └── vietnamese_utils.dart     # Tìm kiếm không dấu
├── data/
│   ├── database/
│   │   ├── database_helper.dart      # Singleton SQLite (version 4)
│   │   └── migrations/
│   │       └── migration_v1.dart     # Initial schema
│   ├── models/                       # fromMap/toMap/copyWith
│   │   ├── restaurant.dart
│   │   ├── product.dart
│   │   ├── restaurant_price.dart
│   │   ├── order.dart                # enum OrderStatus, PaymentStatus
│   │   ├── order_item.dart           # Snapshot fields
│   │   ├── inventory_transaction.dart # enum TransactionType
│   │   ├── payment.dart              # enum PaymentMethod
│   │   └── models.dart               # Barrel export
│   └── repositories/
│       ├── base_repository.dart      # Abstract CRUD base
│       ├── restaurant_repository.dart
│       ├── product_repository.dart
│       ├── restaurant_price_repository.dart
│       ├── order_repository.dart
│       ├── inventory_repository.dart
│       ├── payment_repository.dart
│       ├── settings_repository.dart
│       └── repositories.dart         # Barrel export
├── providers/                        # ChangeNotifier + Provider
│   ├── restaurant_provider.dart
│   ├── product_provider.dart
│   ├── order_provider.dart
│   ├── inventory_provider.dart
│   └── providers.dart                # Barrel export
├── screens/
│   ├── main_screen.dart              # Bottom NavigationBar (5 tabs)
│   ├── home/                         # Tab 1: Đặt hàng
│   │   ├── home_screen.dart          # Danh sách nhà hàng
│   │   ├── restaurant_detail_screen.dart
│   │   ├── order_detail_screen.dart
│   │   └── widgets/
│   │       └── add_order_dialog.dart
│   ├── order/                        # Tạo/sửa đơn hàng
│   │   ├── order_tab.dart
│   │   └── widgets/
│   │       └── create_order_dialog.dart
│   ├── inventory/                    # Tab 2: Tồn kho
│   │   ├── inventory_tab.dart
│   │   └── widgets/
│   │       ├── add_stock_dialog.dart
│   │       └── stock_history_screen.dart
│   ├── debt/                         # Tab 3: Công nợ
│   │   ├── debt_tab.dart
│   │   ├── debt_screen.dart
│   │   └── restaurant_debt_detail_screen.dart
│   ├── delivery/                     # Tab 4: Giao hàng
│   │   └── delivery_tab.dart
│   ├── settings/                     # Cài đặt, sản phẩm, backup
│   │   ├── product_management_screen.dart
│   │   ├── backup_screen.dart
│   │   └── help_screen.dart
│   └── shared/
│       └── share_preview_dialog.dart
├── scripts/
│   └── seed_products.dart            # Seed dữ liệu mặc định (1 lần)
└── services/
    ├── backup_service.dart           # JSON export/import
    └── google_drive_backup_service.dart
```

---

## Database Schema (SQLite v4)

### ERD

```
restaurants ──< restaurant_prices >── products
     │                                    │
     ▼                                    ▼
  orders ──< order_items          inventory_transactions
     │
     ▼
  payments
```

### Bảng & quan hệ

| Bảng | PK | Mô tả |
|------|-----|-------|
| `restaurants` | UUID | Nhà hàng/khách hàng → N orders, N restaurant_prices |
| `products` | UUID | Sản phẩm → N restaurant_prices, N order_items, N inventory_transactions |
| `restaurant_prices` | UUID | Giá riêng (restaurant + product → price) |
| `orders` | UUID | Đơn hàng (FK restaurants) → N order_items, N payments |
| `order_items` | UUID | Chi tiết đơn — **snapshot** product_name, unit, unit_price |
| `inventory_transactions` | UUID | Lịch sử kho (FK products) |
| `payments` | UUID | Thanh toán (FK orders) |
| `app_settings` | key TEXT | Cài đặt app (key-value) |

### Quy tắc dữ liệu

- **ID:** UUID (TEXT), generate bằng `uuid` package
- **Date:** ISO8601 TEXT (`yyyy-MM-dd` cho date, `yyyy-MM-dd'T'HH:mm:ss.SSS` cho datetime)
- **Boolean:** INTEGER (1=true, 0=false)
- **Foreign keys:** Luôn bật (`PRAGMA foreign_keys = ON`)
- **Tên cột:** Dùng `DbConstants` — KHÔNG hardcode

### Enums

| Enum | Values |
|------|--------|
| **Order Status** | `pending` → `confirmed` → `delivering` → `delivered` \| `cancelled` (chỉ pending/confirmed cho sửa/xóa) |
| **Payment Status** | `unpaid` (=0) \| `partial` (0 < paid < total) \| `paid` (paid ≥ total) |
| **Transaction Type** | `import` \| `export` \| `adjustment_add` \| `adjustment_sub` \| `return` |
| **Payment Method** | `cash` \| `bank_transfer` \| `momo` \| `zalo_pay` |

---

## Business Flows

### Tạo đơn hàng
1. Chọn nhà hàng → ngày giao → thêm sản phẩm (giá = `restaurant_price ?? base_price`)
2. Lưu: `status=pending`, `payment_status=unpaid`
3. **KHÔNG trừ tồn kho** khi tạo đơn

### Giao hàng (trừ kho)
Khi đổi status → `delivered`, trong **1 DB transaction**:
- Mỗi order_item → tạo `inventory_transaction` (type=`export`) → trừ `current_stock`

### Nhập kho
Tạo `inventory_transaction` (type=`import`) → cộng `current_stock`

### Thanh toán
Tạo payment → `paid_amount` = SUM(payments) → cập nhật `payment_status`

---

## Backup & Restore

### JSON
- **Export:** Toàn bộ DB → `order_inventory_backup_YYYYMMDD_HHMMSS.json`
- **Import:** Chọn file → xác nhận → **thay thế toàn bộ** dữ liệu

### Google Drive
- Auto-backup khi app khởi động + sau mỗi thay đổi (throttle 1 lần/giờ, giữ 5 bản)

### ⚠️ Bảo mật
File backup chứa toàn bộ dữ liệu nhạy cảm — lưu ở nơi an toàn, không share công khai.

---

## Chạy dự án

```bash
flutter pub get
flutter run            # Android
flutter run -d windows # Windows (debug)
```

Desktop dùng `sqflite_common_ffi` — khởi tạo tự động trong `main.dart`.
