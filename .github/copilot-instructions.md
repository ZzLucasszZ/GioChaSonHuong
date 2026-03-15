# Copilot Instructions — Giò Chả Sơn Hương

> Xem [README.md](../README.md) cho tổng quan dự án, tech stack, database schema, và business flows.

## Kiến trúc

- **Local-first** — Offline hoàn toàn, SQLite, không backend/API
- **Pattern:** Repository → Provider (ChangeNotifier) → Screen
- **Ngôn ngữ UI:** Tiếng Việt (`vi_VN`). Mọi text hiển thị phải bằng tiếng Việt

---

## Quy tắc bắt buộc

### KHÔNG được làm
1. **KHÔNG tạo backend/API** — App chạy offline với SQLite
2. **KHÔNG hardcode tên bảng/cột** — Dùng `DbConstants` (`lib/core/constants/db_constants.dart`)
3. **KHÔNG dùng `print()`** — Dùng `AppLogger` (`lib/core/utils/logger.dart`)
4. **KHÔNG hardcode colors** — Dùng `AppColors` (`lib/core/theme/app_colors.dart`)
5. **KHÔNG hardcode units/categories** — Dùng `AppConstants` (`lib/core/constants/app_constants.dart`)

### PHẢI làm
1. **Null safety** — Handle null đúng cách
2. **const constructors** khi có thể
3. **Relative imports** trong project
4. **Parameterized queries** — tránh SQL injection
5. **Database transactions** cho operations multi-table (giao hàng, thanh toán)
6. **try-catch** trong Provider methods, hiển thị lỗi qua `ErrorDialog`
7. **Auto-backup** fire-and-forget sau mỗi thay đổi dữ liệu

---

## Conventions

### Models (`lib/data/models/`)
- Mỗi model có: constructor, `copyWith()`, `toMap()`, `fromMap()` (factory), `toString()`
- `order_items` có **snapshot fields** (product_name, unit, unit_price) — không đổi khi SP cập nhật

### Repositories (`lib/data/repositories/`)
- Kế thừa `BaseRepository<T>` (CRUD: insert, update, delete, getAll, getById)
- Override: `tableName`, `toMap()`, `fromMap()`
- Query phức tạp → thêm methods riêng

### Providers (`lib/providers/`)
- Extend `ChangeNotifier`, nhận `DatabaseHelper` qua constructor
- Pattern: `_isLoading`, `_error`, `notifyListeners()`

### Screens (`lib/screens/`)
- Bottom Navigation: 5 tabs (Đặt hàng, Tồn kho, Công nợ, Giao hàng, Sản phẩm)
- Material 3 (`useMaterial3: true`)
- Currency: `150.000 đ` | Date: `dd/MM/yyyy`

---

## Database

- **Version hiện tại: 4** — Khi thêm migration mới phải tăng version
- **Singleton:** `DatabaseHelper.instance` (private constructor `DatabaseHelper._()`)
- **Foreign keys ON** — `PRAGMA foreign_keys = ON`
- **ID:** UUID TEXT | **Date:** ISO8601 TEXT | **Boolean:** INTEGER (1/0)

### Business rules
- Tạo đơn → **KHÔNG trừ kho**
- Giao hàng (→ `delivered`) → trừ kho trong **1 transaction**
- Thanh toán → `paid_amount` = SUM(payments) → tự động cập nhật `payment_status`
- Chỉ `pending`/`confirmed` cho phép sửa/xóa đơn

---

## Theme

- Primary: `#1976D2` (Blue), Material 3 from seed
- Order status: pending=Orange, confirmed=Blue, delivering=Purple, delivered=Green, cancelled=Grey
- Payment: unpaid=Red, partial=Orange, paid=Green
- Stock: normal=Green, low=Orange, out=Red

---

## Files tham khảo

| File | Mục đích |
|------|----------|
| `lib/core/constants/db_constants.dart` | Tên bảng & cột |
| `lib/core/constants/app_constants.dart` | Units, categories, formats |
| `lib/core/theme/app_colors.dart` | Color palette |
| `lib/data/repositories/base_repository.dart` | Base CRUD |
| `lib/data/database/database_helper.dart` | Singleton DB |
| `lib/core/utils/logger.dart` | AppLogger |
