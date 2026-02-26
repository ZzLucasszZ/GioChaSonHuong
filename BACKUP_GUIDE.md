# 🔄 Backup & Restore Guide

## 📦 Tính năng Sao lưu & Khôi phục

App đã được tích hợp hệ thống backup/restore dữ liệu dạng JSON.

### ✨ Tính năng

1. **Export dữ liệu** - Xuất toàn bộ database thành file JSON
2. **Import dữ liệu** - Khôi phục dữ liệu từ file JSON backup
3. **Share file** - Chia sẻ file backup qua email, Zalo, Google Drive, etc.

### 📋 Dữ liệu được backup

- ✅ Sản phẩm (Products)
- ✅ Nhà hàng (Restaurants)  
- ✅ Đơn hàng (Orders)
- ✅ Chi tiết đơn hàng (Order Items)
- ✅ Giao dịch kho (Inventory Transactions)

### 🚀 Cách sử dụng

#### Export (Sao lưu)

1. Vào **Home screen** → nhấn icon **🔄 Backup** ở góc trên
2. Chọn **"Xuất file backup"**
3. File JSON sẽ được tạo với tên: `order_inventory_backup_YYYYMMDD_HHMMSS.json`
4. Chọn app để share (Gmail, Drive, Zalo, etc.)
5. Lưu file vào nơi an toàn (Google Drive, Dropbox, Email, etc.)

#### Import (Khôi phục)

1. Vào **Home screen** → nhấn icon **🔄 Backup** ở góc trên
2. Chọn **"Nhập file backup"**
3. Chọn file JSON backup từ thiết bị
4. Xem thông tin backup (số lượng sản phẩm, đơn hàng, etc.)
5. Xác nhận khôi phục
6. ⚠️ **Lưu ý**: Dữ liệu hiện tại sẽ bị xóa và thay thế!
7. Khởi động lại app sau khi restore

### 💡 Best Practices

- **Backup thường xuyên**: Nên backup mỗi ngày hoặc sau mỗi thay đổi quan trọng
- **Lưu nhiều nơi**: Google Drive + Email để đảm bảo an toàn
- **Đặt tên rõ ràng**: File có timestamp tự động, nhưng có thể rename thêm note
- **Test restore**: Thỉnh thoảng test restore trên device khác để đảm bảo file backup hoạt động

### 📱 File backup example

```json
{
  "version": "1.0",
  "exportDate": "2026-02-06T10:30:00.000Z",
  "data": {
    "products": [...],
    "restaurants": [...],
    "orders": [...],
    "order_items": [...],
    "inventory_transactions": [...]
  }
}
```

### ⚠️ Quan trọng

- File backup chứa **TOÀN BỘ** dữ liệu nhạy cảm (giá, đơn hàng, công nợ)
- **KHÔNG** share file backup công khai
- Lưu file ở nơi an toàn, có mật khẩu nếu cần

### 🔧 Technical Details

- Format: JSON với indent 2 spaces (dễ đọc)
- Size: Phụ thuộc vào số lượng data (~100KB cho 1000 orders)
- Compatible: Cross-platform (Android/iOS/Desktop)
- Version: v1.0 (có thể upgrade sau)

---

## 🚦 Next Steps

Sau khi backup system hoàn tất, các tính năng tiếp theo:

### Phase 1: Quick Wins ✅
- [x] Task 0: Backup/Restore system
- [ ] Task 3: Remove autofocus in add order
- [ ] Task 6: Show restaurant + date in add order dialog
- [ ] Task 8: Sort by date (oldest first)

### Phase 2: Input & Share
- [ ] Task 4: Decimal input for Kg products
- [ ] Task 5: Share debt by date or all

### Phase 3: Search & Filter
- [ ] Task 7a: Search in order list
- [ ] Task 7b: Search dropdown for products

### Phase 4: Major Features
- [ ] Task 1: Full order editing
- [ ] Task 2: Product management screen
