# GreenTrash

Đồ án môn Công Nghệ Phần Mềm — sinh viên năm 2.
Flutter Web + Supabase. Dịch vụ đặt lịch thu gom rác tái chế tận nhà.
Chạy dev: `flutter run -d chrome` (port 5000).

---

## 1. BỐI CẢNH CODE HIỆN TẠI

### Quy ước đặt tên
- Tên biến, hàm, class, comment đều dùng **tiếng Việt không dấu** (`_tabDangChon`,
  `_khoiLienHe()`, `CongDieuHuong`, `_BannerCarousel`). **GIỮ ĐÚNG** quy ước này
  cho mọi code mới. Không đổi sang tiếng Anh.
- File đặt tên snake_case tiếng Việt: `trang_chu_screen.dart`, `dat_lich_screen.dart`.

### Cấu trúc thư mục
```
lib/
  main.dart                          -> GreenTrashApp + CongDieuHuong (rẽ nhánh vai trò)
  screens/
    login_screen.dart
    register_screen.dart
    forgot_password_screen.dart
    customer/
      customer_home_screen.dart      -> khung chính phía khách (NavigationBar 4 tab)
      trang_chu_screen.dart          -> trang chủ 1-trang-dài (~900 dòng)
      dat_lich_screen.dart           -> đặt lịch thu gom (UC04)
      lich_cua_toi_screen.dart       -> theo dõi lịch realtime, hủy, đánh giá
      chi_tiet_bai_viet_screen.dart
      tai_khoan_screen.dart
    admin/
      admin_home_screen.dart         -> khung chính phía admin (Drawer 8 mục)
      quan_ly_lich_screen.dart, hoa_don_screen.dart,
      quan_ly_nguoi_dung_screen.dart, quan_ly_loai_rac_screen.dart,
      quan_ly_vat_tu_screen.dart, quan_ly_bai_viet_screen.dart,
      danh_gia_screen.dart, bao_cao_screen.dart
  services/
    auth_service.dart
  widgets/
    common.dart                      -> widget dùng chung
assets/images/                       -> banner1-4.png, gioi_thieu.png, HUONG_DAN.txt
```

### Điều hướng
- `CongDieuHuong` trong `main.dart` dùng `StreamBuilder` nghe
  `supabase.auth.onAuthStateChange`, đọc vai trò rồi rẽ nhánh:
  - chưa đăng nhập / `khach_hang` → `CustomerHomeScreen`
  - `admin` → `AdminHomeScreen`
  - `bi_khoa` → màn chặn tài khoản
- Route: `/` và `/admin`, URL sạch qua `usePathUrlStrategy()`.
- Phía khách dùng `IndexedStack` để giữ trạng thái giữa 4 tab.

### Màu sắc
- Theme chính khai trong `main.dart` (xanh lá, AppBar xanh đậm chữ trắng).
- Hằng số `_xanhDam` dùng trong `trang_chu_screen.dart` cho khối Liên hệ/footer.
- **KHÔNG thêm màu mới.** Cần màu thì lấy từ theme hoặc hằng số sẵn có.

---

## 2. NHỮNG CHỖ ĐANG ĐÚNG — TUYỆT ĐỐI KHÔNG SỬA

Các mục dưới đây trông giống lỗi nhưng là **cố ý**. Đã kiểm chứng.
Nếu thấy "có vẻ sai", **hỏi lại trước**, không tự sửa.

1. **Menu ngang chỉ hiện ở tab Trang chủ.**
   Trong `customer_home_screen.dart`, nhánh đã đăng nhập có
   `if (_tabDangChon == 0) menuNgang,` — ĐÚNG NHƯ THIẾT KẾ.
   Nhánh khách vãng lai render vô điều kiện cũng đúng, vì khách chỉ có 1 màn.

2. **Khối đệm cuối `trang_chu_screen.dart`.**
   `Container` màu `_xanhDam` đặt sau `_boc(_khoiLienHe(), ...)` là CỐ Ý —
   tạo không gian cuộn cho `Scrollable.ensureVisible` khi bấm menu
   "Liên hệ" / "Hướng dẫn phân loại" (vì đó là khối cuối trang).
   Được phép giảm chiều cao, **KHÔNG được xóa hẳn** nếu chưa test cuộn.

3. **Banner thiếu ảnh không phải lỗi.**
   `_BannerCarousel` đọc `assets/images/banner1-4.png`, có `errorBuilder`
   fallback về gradient + icon. Thiếu file ảnh vẫn chạy bình thường.

4. **`trang_chu_screen.dart` dài ~900 dòng.**
   CHẤP NHẬN. Không tách file, không refactor.

---

## 3. RÀNG BUỘC BẮT BUỘC

### Giao diện — giữ nguyên phong cách hiện tại
- Giữ đúng bảng màu đang dùng, **KHÔNG thêm màu mới**
- Dùng **font mặc định** của Flutter, không thêm Google Fonts
- Chỉ dùng widget Material chuẩn: `Card`, `ElevatedButton`,
  `TextField` + `OutlineInputBorder`, `ListTile`, `NavigationBar` —
  đúng như code hiện tại
- Bo góc và đổ bóng giữ nguyên mức đang có, không tăng thêm
- **CẤM:** glassmorphism, neumorphism, gradient nhiều lớp, shadow nhiều tầng,
  parallax, animation phức tạp
- Animation chỉ dùng `AnimatedContainer` / `AnimatedOpacity` đơn giản
- Responsive dùng `LayoutBuilder` / `MediaQuery` thuần

### Code — giữ mức đơn giản
- State: giữ nguyên **`setState`**. **CẤM** thêm BLoC, Riverpod, GetX,
  freezed, injectable, get_it
- **KHÔNG thêm package mới** vào `pubspec.yaml` nếu chưa hỏi và được đồng ý.
  Việc gì Flutter core làm được thì dùng Flutter core.
- Giữ nguyên cấu trúc thư mục, **không tái tổ chức**
- **CẤM** tách Clean Architecture nhiều tầng (domain/data/presentation)
- File hiện tại có thể dài — CHẤP NHẬN, không tách. Code mới thêm vào thì
  viết gọn, tách thành **method private trong cùng file** nếu quá dài
- Comment **tiếng Việt** ở các đoạn logic chính
- Ưu tiên code **dễ hiểu** hơn code ngắn gọn/thông minh

---

## 4. QUY TẮC LÀM VIỆC

1. **Giải thích ngắn gọn TRƯỚC khi sửa.** Nói rõ sẽ đụng vào file nào,
   sửa gì, vì sao.
2. **CHỈ sửa đúng phần được yêu cầu.** Thấy chỗ khác chưa tối ưu thì
   **ghi chú lại cho người dùng biết**, KHÔNG tự sửa.
3. **Không đổi logic khi được nhờ đổi giao diện**, và ngược lại.
4. Sau khi sửa: **liệt kê file đã đổi** + **nói rõ cần test lại những gì**
   (vì có những thứ chỉ người dùng test bằng tay được: cuộn trang,
   responsive, luồng đăng nhập).
5. Sửa xong chạy `flutter analyze`, báo nếu có **lỗi/warning mới**.
   (20 issue `info` sẵn có phần lớn là `deprecated_member_use` và
   `prefer_const` — không cần xử lý trừ khi được yêu cầu.)
6. Nếu một yêu cầu cần tạo **hơn 5 file mới**, dừng lại và đề nghị chia nhỏ.

---

## 5. MỤC TIÊU CUỐI

Đây là đồ án phải **bảo vệ trước giáo viên**. Người viết là sinh viên năm 2.

Tiêu chí quan trọng nhất: **mọi dòng code phải giải thích được.**
Code "xịn" mà chủ nhân không hiểu thì tệ hơn code đơn giản mà hiểu rõ.

Khi phân vân giữa hai cách làm — chọn cách **dễ giải thích hơn**.
