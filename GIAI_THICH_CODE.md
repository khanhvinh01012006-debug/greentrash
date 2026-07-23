# GIẢI THÍCH CODE & CÁCH VẬN HÀNH - GREENTRASH

Tài liệu này giải thích **từng file làm gì, tại sao viết như vậy, và dữ liệu
chạy qua hệ thống như thế nào**. Đọc kỹ trước khi bảo vệ đồ án - các câu
"tại sao" bên dưới chính là những câu thầy cô hay hỏi.

---

## 1. BỨC TRANH TỔNG THỂ

```
┌─────────────────┐         Internet          ┌──────────────────────────┐
│  FLUTTER WEB    │ ◄───────────────────────► │        SUPABASE          │
│  (trình duyệt)  │                           │  ┌────────────────────┐  │
│                 │   1. Auth (đăng nhập)     │  │ Authentication     │  │
│  screens/  ─────┼──►                        │  ├────────────────────┤  │
│  services/ ─────┼──► 2. Đọc/ghi dữ liệu     │  │ PostgreSQL + RLS   │  │
│  widgets/       │                           │  ├────────────────────┤  │
│                 │   3. Upload/tải ảnh       │  │ Storage (ảnh)      │  │
│                 │                           │  ├────────────────────┤  │
│                 │ ◄─ 4. Realtime (tự đẩy)   │  │ Realtime           │  │
└─────────────────┘                           │  └────────────────────┘  │
                                              └──────────────────────────┘
```

**Tại sao chia 3 thư mục `screens / services / widgets`?**
- `screens/` = giao diện (cái NGƯỜI DÙNG thấy)
- `services/` = nghiệp vụ + gọi database (cái HỆ THỐNG làm)
- `widgets/` = mảnh giao diện dùng chung (nhãn trạng thái, định dạng tiền...)

Tách như vậy để **sửa giao diện không đụng nghiệp vụ và ngược lại** - đây là
"tách lớp truy cập dữ liệu" ghi trong yêu cầu công nghệ của báo cáo. Ví dụ
muốn đổi database khác, chỉ sửa thư mục `services/`, toàn bộ `screens/` giữ nguyên.

---

## 2. LUỒNG CHẠY CHÍNH (kể theo vòng đời 1 lịch thu gom)

### Bước 0 - Mở app (main.dart)
1. `Supabase.initialize(url, anonKey)` - "cắm dây" nối app với project Supabase.
2. `CongDieuHuong` lắng nghe `onAuthStateChange` (stream trạng thái đăng nhập):
   - Chưa đăng nhập → `LoginScreen`
   - Đã đăng nhập → đọc `vai_tro` từ bảng `nguoi_dung` → rẽ nhánh
     `CustomerHomeScreen` hoặc `AdminHomeScreen`
   - `bi_khoa = true` → màn hình "Tài khoản đã bị khóa"
3. **Tại sao cache vai trò?** Mỗi lần giao diện build lại mà hỏi database lại
   thì vừa chậm vừa tốn truy vấn → hỏi 1 lần, nhớ kết quả theo user id.

### Bước 1 - Đăng ký (auth_service.dart + register_screen.dart)
- `signUp(email, password)` tạo tài khoản trong **Authentication** (mật khẩu
  được Supabase băm bcrypt - ta không bao giờ lưu mật khẩu thô).
- Ngay sau đó `insert` một dòng hồ sơ vào bảng `nguoi_dung` (họ tên, SĐT...).
- **Tại sao tách 2 bảng?** Authentication chỉ lo đăng nhập; thông tin nghiệp vụ
  (tên, địa chỉ, vai trò) nằm ở bảng riêng do ta toàn quyền thiết kế.

### Bước 2 - Đặt lịch (dat_lich_screen.dart)
1. Mở màn hình: tải danh sách `loai_rac` (đổ vào dropdown) + tự điền địa chỉ
   từ hồ sơ (`layHoSoCuaToi`).
2. Khách nhập khối lượng → app tính `chi_phi = kg × đơn_giá` hiện ngay
   (getter `_chiPhiDuKien` chạy lại mỗi lần `setState`).
3. Chọn ảnh: `image_picker` đọc file thành **bytes** (Uint8List) - đọc bytes
   để chạy được trên web (web không có đường dẫn file như điện thoại).
4. Bấm Đặt lịch: upload ảnh lên Storage trước → nhận link → `insert` lịch kèm
   link ảnh. **Tại sao upload trước insert?** Vì dòng lịch cần cột
   `hinh_anh_url`, phải có link rồi mới ghi được.

### Bước 3 - Admin duyệt (quan_ly_lich_screen.dart)
- Danh sách lịch là `StreamBuilder` bọc `supabase.from(...).stream(...)`:
  database đẩy dữ liệu mới xuống → giao diện tự vẽ lại, **không cần nút refresh**.
- Admin bấm Duyệt → `update trang_thai = 'da_xac_nhan'` → màn hình khách
  (cũng đang stream) đổi nhãn NGAY. Đây chính là Realtime.

### Bước 4 - Khách thanh toán (lich_cua_toi_screen.dart)
- Lịch `da_xac_nhan` hiện nút **Thanh toán** → dialog chọn:
  - **Tiền mặt**: ghi `phuong_thuc_tt='tien_mat'`, trả khi nhân viên đến.
  - **Chuyển khoản**: hiện 2 mã QR (ảnh đóng gói trong `assets/`, gọi bằng
    `Image.asset`) → khách quét bằng app ngân hàng → bấm "Tôi đã chuyển khoản"
    → ghi `trang_thai_tt='khach_bao_da_chuyen'`.
- **"Thông báo cho admin" hoạt động thế nào?** Không cần hệ thống thông báo
  riêng: bảng `lich_thu_gom` đã bật realtime, nên nhãn 💰 trên màn hình admin
  đổi sang màu cam "Khách báo đã chuyển khoản" ngay khi khách bấm nút.
- Admin kiểm tra tài khoản thật → menu "💰 Xác nhận đã nhận tiền" →
  `trang_thai_tt='da_thanh_toan'` → nhãn phía khách đổi xanh.
- **Tại sao chỉ làm "tượng trưng"?** Cổng thanh toán tự động (VNPay/MoMo) đòi
  đăng ký doanh nghiệp + ký hợp đồng. Mô hình "QR tĩnh + xác nhận thủ công"
  là cách các cửa hàng nhỏ ngoài đời vẫn dùng, đủ minh họa nghiệp vụ UC15.

### Bước 5 - Admin hoàn tất → HÓA ĐƠN + TRỪ KHO (HoaDonService)
Bấm "Hoàn tất thu gom" chạy hàm `hoanTatLichVaLapHoaDon` gồm 4 bước:
1. **Kiểm tra kho**: lấy các vật tư có `dinh_muc_su_dung > 0`, so với tồn.
   Thiếu → ném lỗi, KHÔNG hoàn tất (ép admin nhập kho trước - đúng nghiệp vụ).
2. Đổi `trang_thai='hoan_tat'`.
3. `insert` vào bảng `hoa_don` (tiền rác + tổng tiền vật tư).
4. Với từng vật tư: trừ `so_luong_ton` theo định mức + `insert` dòng chi tiết
   vào `hoa_don_vat_tu` kèm **snapshot** tên/đơn giá.
- **Snapshot là gì, tại sao cần?** Là "chụp lại" giá trị tại thời điểm lập.
  Nếu chỉ lưu mã vật tư, sau này admin đổi giá găng tay thì mọi hóa đơn cũ
  tự sai theo. Chứng từ kế toán không được phép đổi → lưu cứng tên + giá.
- **Điểm nêu khi bảo vệ:** 4 bước này ở hệ thống thật phải gói trong 1
  transaction của database (hoặc tất cả thành công, hoặc không gì cả);
  đồ án chạy tuần tự từ app cho dễ hiểu.

### Bước 6 - Khách xem hóa đơn + đánh giá
- Nút "Hóa đơn": truy vấn `hoa_don` theo `ma_lich`. RLS đảm bảo khách chỉ đọc
  được hóa đơn của lịch chính mình đặt.
- Nút "Đánh giá": chèn vào `danh_gia`; ràng buộc `UNIQUE(ma_lich)` trong
  database chặn đánh giá 2 lần (chặn ở tầng dữ liệu chắc hơn chặn ở giao diện).

---

## 3. GIẢI THÍCH TỪNG FILE

### supabase/ (chạy trong SQL Editor theo thứ tự)
| File | Vai trò |
|---|---|
| `schema.sql` | Tạo 5 bảng gốc + hàm `la_admin()` + toàn bộ RLS + bật realtime + dữ liệu mẫu |
| `update_01_bai_viet.sql` | Bảng `bai_viet` (tin tức) + 3 bài mẫu |
| `update_02_hoa_don_nguoi_dung.sql` | Cột `bi_khoa`, `dinh_muc_su_dung`; bảng `hoa_don`, `hoa_don_vat_tu` |
| `update_03_thanh_toan.sql` | Cột `phuong_thuc_tt`, `trang_thai_tt` |

**Tại sao chia nhiều file update thay vì gộp 1 file?** Minh họa cách nâng cấp
CSDL theo từng đợt bằng `ALTER TABLE` / `CREATE TABLE IF NOT EXISTS` mà
**không xóa dữ liệu cũ** - mỗi file là một "phiên bản" của database.

**RLS (Row Level Security) là gì?** Luật gắn TRONG database quy định ai đọc/ghi
dòng nào, ví dụ: `USING (ma_khach_hang = auth.uid() OR la_admin())` = chỉ chủ
dòng hoặc admin. Kể cả ai đó lấy được anon key và gọi API trực tiếp bỏ qua app,
họ vẫn không đọc được dữ liệu người khác - bảo mật ở tầng sâu nhất.

**Hàm `la_admin()` tại sao cần SECURITY DEFINER?** Policy của bảng `nguoi_dung`
cần biết "người này có phải admin không" bằng cách... đọc chính bảng
`nguoi_dung` → tự gọi vòng tròn (đệ quy). SECURITY DEFINER cho hàm chạy bằng
quyền hệ thống, thoát khỏi vòng lặp đó.

### lib/config/supabase_config.dart
Chứa URL + anon key của project. Anon key để lộ cũng không nguy hiểm bằng
service key vì mọi truy cập qua anon key đều bị RLS kiểm soát.

### lib/main.dart
Khởi tạo Supabase + `CongDieuHuong` (cổng điều hướng): nghe stream đăng nhập,
đọc vai trò (có cache), rẽ nhánh 4 hướng: Login / Bị khóa / Admin / Khách.
Có xử lý lỗi hiển thị rõ ràng thay vì xoay vô tận.

### lib/services/
| File / class | Nhiệm vụ chính |
|---|---|
| `auth_service.dart` | Đăng ký (signUp + tạo hồ sơ), đăng nhập, quên mật khẩu, dịch lỗi sang tiếng Việt |
| `database_service.dart` → `DatabaseService` | Hồ sơ cá nhân, loại rác, lịch (đặt/stream/hủy/đổi trạng thái), vật tư, đánh giá, báo cáo tháng |
| ... → `BaiVietService` | CRUD bài viết tin tức |
| ... → `NguoiDungService` | Admin: danh sách người dùng, đổi vai trò, khóa/mở khóa |
| ... → `HoaDonService` | Hoàn tất lịch trọn gói (kiểm kho → hóa đơn → trừ kho → chi tiết), tra cứu hóa đơn |
| ... → `ThanhToanService` | Khách chọn phương thức / báo đã CK; admin xác nhận nhận tiền |
| `storage_service.dart` | Chọn ảnh (bytes, nén maxWidth 1200 quality 80 cho nhẹ), upload lên bucket, trả link public |

**Tại sao hàm đều `static`?** Không cần tạo đối tượng (`DatabaseService()`),
gọi thẳng `DatabaseService.datLich(...)` - gọn và đủ cho quy mô đồ án.

### lib/widgets/common.dart
Hàm/mảnh giao diện dùng chung: `dinhDangTien` (1.500.000 ₫ kiểu vi_VN),
`dinhDangNgay`, `ChipTrangThai` (nhãn màu theo trạng thái lịch),
`ChipThanhToan` (nhãn 💰 xám/cam/xanh theo trạng thái tiền).
**Tại sao gom vào 1 file?** Định dạng tiền xuất hiện ở 7-8 màn hình; viết 1
chỗ, sửa 1 chỗ là mọi nơi đổi theo (nguyên tắc DRY - Don't Repeat Yourself).

### lib/screens/auth/
- `login_screen.dart`: Form + validator; con mắt hiện mật khẩu (`obscureText`
  gắn với biến bool); ghi nhớ email bằng `shared_preferences` (chỉ nhớ email,
  KHÔNG nhớ mật khẩu - việc đó của trình duyệt).
- `register_screen.dart`: validate SĐT bằng regex `^0\d{9}$` (bắt đầu số 0,
  đủ 10 số), mật khẩu ≥ 6 ký tự, nhập lại phải khớp.
- `forgot_password_screen.dart`: gọi `resetPasswordForEmail` - Supabase tự
  gửi email đặt lại, app không phải tự làm hệ thống email.

### lib/screens/customer/
- `customer_home_screen.dart`: khung 4 tab (`NavigationBar` + `IndexedStack`).
  **Tại sao IndexedStack thay vì đổi widget?** IndexedStack giữ nguyên trạng
  thái các tab ẩn - đang gõ dở form đặt lịch, qua tab khác quay lại vẫn còn.
  Kèm `_NenTrangTri`: Stack 3 lớp (gradient → icon mờ 5% → nội dung) lấp
  khoảng trống 2 bên trên màn hình web rộng.
- `trang_chu_screen.dart`: landing kiểu vechaioi - hero (nút gọi callback
  `onDatLichNgay` để trang cha chuyển tab), quy trình 3 bước, bảng giá đọc từ
  DB, lưới tin tức tự co giãn (LayoutBuilder đo bề rộng → 1/2/3 cột), hướng
  dẫn phân loại (ExpansionTile).
- `dat_lich_screen.dart`: form đặt lịch (xem Bước 2 ở trên).
- `lich_cua_toi_screen.dart`: stream lịch của tôi; nút theo trạng thái:
  Hủy (chờ duyệt) / Thanh toán (đã duyệt, chưa trả xong) / Hóa đơn + Đánh giá
  (hoàn tất). 2 bước thanh toán: dialog chọn phương thức → dialog QR
  (`SegmentedButton` gạt Ngân hàng/MoMo, `StatefulBuilder` cho setState riêng
  trong dialog).
- `tai_khoan_screen.dart`: xem/sửa hồ sơ, đổi mật khẩu (`auth.updateUser`),
  đăng xuất. Địa chỉ ở đây tự điền sang form đặt lịch.
- `chi_tiet_bai_viet_screen.dart`: đọc bài viết đầy đủ.

### lib/screens/admin/
- `admin_home_screen.dart`: khung Drawer 7 mục. **Tại sao Drawer?** Thanh tab
  đáy chỉ đẹp ≤ 5 mục; menu trượt là bố cục chuẩn trang quản trị, thêm mục
  không phá giao diện.
- `quan_ly_lich_screen.dart`: lọc theo trạng thái (`FilterChip`), stream tất
  cả lịch, menu Duyệt/Hoàn tất/Từ chối/Xác nhận nhận tiền, bottom sheet chi
  tiết kèm thông tin khách + ảnh.
- `hoa_don_screen.dart`: lịch sử hóa đơn (JOIN lồng: hóa đơn → lịch → khách
  bằng cú pháp `select('*, lich_thu_gom(..., nguoi_dung(...))')`), chi tiết
  có bảng vật tư tiêu hao.
- `quan_ly_nguoi_dung_screen.dart`: tìm kiếm (lọc phía client bằng getter
  `_dsSauLoc`), đổi vai trò, khóa/mở khóa; chặn tự thao tác lên chính mình.
- `quan_ly_loai_rac_screen.dart`: CRUD loại rác; bắt lỗi khóa ngoại khi xóa
  loại đang có lịch dùng (RESTRICT trong schema).
- `quan_ly_vat_tu_screen.dart`: nhập/xuất kho, cảnh báo đỏ khi
  `ton < ton_toi_thieu`, chỉnh định mức sử dụng/lần thu gom.
- `quan_ly_bai_viet_screen.dart`: đăng/sửa/xóa bài viết kèm upload ảnh bìa
  (tái sử dụng StorageService của phần đặt lịch).
- `bao_cao_screen.dart`: doanh thu tháng (lọc lịch `hoan_tat` theo tháng),
  đếm trạng thái, biểu đồ thanh ngang tự vẽ bằng `FractionallySizedBox`
  (widthFactor = giá trị/max) - không cần thư viện chart.

---

## 4. CÁC CÂU HỎI BẢO VỆ THƯỜNG GẶP (gợi ý trả lời)

1. **"Sao không dùng Firebase?"** - Thiết kế LAB 3 là 18 bảng QUAN HỆ có khóa
   ngoại; Firestore là NoSQL không có JOIN/khóa ngoại. Supabase = PostgreSQL
   chuẩn SQL đúng như môn CSDL đã học, lại nâng cấp bằng ALTER TABLE không
   mất dữ liệu.
2. **"Bảo mật ở đâu?"** - 3 tầng: mật khẩu băm bởi Supabase Auth; phân quyền
   RLS trong database; app chỉ dùng anon key (bị RLS kiểm soát).
3. **"Realtime hoạt động sao?"** - Bảng được thêm vào publication
   `supabase_realtime`; app mở kết nối WebSocket qua `.stream()`; database
   đổi → đẩy xuống → `StreamBuilder` vẽ lại.
4. **"Tại sao hủy lịch không xóa dòng?"** - Đổi `trang_thai='da_huy'` để giữ
   lịch sử phục vụ báo cáo, và tôn trọng nguyên tắc không phá hủy dữ liệu.
5. **"Định mức vật tư để làm gì?"** - Chuẩn hóa tiêu hao: mỗi lần thu gom tự
   trừ kho đúng số lượng quy định, ghi vào hóa đơn → quản lý được giá vốn,
   biết khi nào cần nhập thêm (cảnh báo tồn tối thiểu).

---

## 5. LỆNH HAY DÙNG

```bash
flutter pub get                          # tải thư viện (sau khi đổi pubspec.yaml)
flutter run -d chrome --web-port=5000    # chạy dev, cổng cố định
flutter run -d chrome --web-port=5000 --release   # chạy mượt để demo
```
