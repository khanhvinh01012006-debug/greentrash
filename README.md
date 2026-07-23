# 🌱 GreenTrash - Đặt Lịch Thu Gom Rác Tại Nhà

Ứng dụng web/mobile Flutter + Supabase — Nhóm 30, môn Công Nghệ Phần Mềm.

## 1. Tại sao dùng Supabase thay vì Firebase?

| Tiêu chí | Supabase ✅ | Firebase |
|---|---|---|
| Loại database | **PostgreSQL (quan hệ)** — khớp thiết kế LAB 3 (bảng, khóa chính/ngoại) | Firestore (NoSQL) — phải thiết kế lại |
| Cập nhật cấu trúc | Chạy `ALTER TABLE`, **giữ nguyên dữ liệu cũ**, không cần xóa DB | Phải tự viết code migrate |
| Upload ảnh | Storage **miễn phí 1GB** | Bắt buộc nhập thẻ (gói Blaze) |
| Realtime | Có (`.stream()`) | Có |
| Viết truy vấn | SQL — đúng thứ học ở trường | Cú pháp riêng |

## 2. Cấu trúc thư mục

```
greentrash/
├── supabase/
│   └── schema.sql                  # Chạy 1 lần trên Supabase để tạo database
├── pubspec.yaml                    # Khai báo thư viện
└── lib/
    ├── main.dart                   # Khởi động app + điều hướng theo vai trò
    ├── config/
    │   └── supabase_config.dart    # ⚠️ Điền URL + key Supabase vào đây
    ├── services/                   # Lớp giao tiếp với server
    │   ├── auth_service.dart       # Đăng ký / đăng nhập / quên mật khẩu
    │   ├── database_service.dart   # Đọc/ghi lịch, loại rác, vật tư, báo cáo
    │   └── storage_service.dart    # Chọn & upload hình ảnh
    ├── widgets/
    │   └── common.dart             # Widget + hàm dùng chung
    └── screens/
        ├── auth/                   # 3 màn hình: login, register, quên mật khẩu
        ├── customer/               # Khách: đặt lịch, lịch của tôi, bảng giá
        └── admin/                  # Admin: duyệt lịch, loại rác, kho, báo cáo
```

## 3. Cài đặt từng bước (làm theo đúng thứ tự)

### Bước 1 — Cài công cụ (bỏ qua nếu đã có)
1. Cài **Flutter SDK**: https://docs.flutter.dev/get-started/install
2. Cài **VS Code** + extension **Flutter** (extension Dart tự cài kèm)
3. Kiểm tra: mở terminal, gõ `flutter doctor` — thấy dấu ✓ ở Flutter và Chrome là ổn.

### Bước 2 — Tạo project Supabase (database)
1. Vào https://supabase.com → đăng ký miễn phí bằng GitHub/Google
2. **New project** → đặt tên `greentrash`, chọn region `Southeast Asia (Singapore)` cho nhanh, đặt mật khẩu database (nhớ lưu lại) → Create
3. Chờ ~2 phút project khởi tạo xong
4. Menu trái → **SQL Editor** → **New query** → dán toàn bộ nội dung file `supabase/schema.sql` → **Run**
   - File này chạy lại được nhiều lần, **không mất dữ liệu cũ**
5. Menu trái → **Storage** → **New bucket** → tên: `hinh-anh-rac` → bật **Public bucket** → Save
   - Sau đó vào bucket → tab **Policies** → **New policy** → chọn template *"Allow authenticated uploads"* (cho phép người đăng nhập upload)
6. Menu trái → ⚙️ **Project Settings** → **API** → copy 2 giá trị:
   - **Project URL**
   - **anon public** key

### Bước 3 — Tạo project Flutter và chép code
Mở terminal trong VS Code:

```bash
# Tạo project mới
flutter create greentrash
cd greentrash
```

Sau đó:
1. **Thay** file `pubspec.yaml` bằng file trong bộ code này → chạy `flutter pub get`
2. **Xóa** file `lib/main.dart` mặc định, **chép** toàn bộ thư mục `lib/` trong bộ code này vào
3. Mở `lib/config/supabase_config.dart` → dán **Project URL** và **anon key** đã copy ở Bước 2

### Bước 4 — Chạy app

```bash
# Chạy trên trình duyệt Chrome (web)
flutter run -d chrome

# Hoặc chạy trên máy ảo Android / điện thoại thật
flutter run
```

### Bước 5 — Tạo tài khoản Admin
1. Trong app, **đăng ký** một tài khoản bình thường (vd: admin@greentrash.vn)
2. Vào Supabase → **Table Editor** → bảng `nguoi_dung` → tìm dòng tài khoản vừa tạo → sửa cột `vai_tro` từ `khach_hang` thành `admin` → Save
3. Đăng xuất rồi đăng nhập lại trong app → sẽ vào giao diện Quản trị

> 💡 Mẹo test: đăng ký thêm 1 tài khoản khách, mở **2 cửa sổ trình duyệt** — 1 bên khách đặt lịch, 1 bên admin duyệt → thấy trạng thái bên khách **đổi ngay lập tức** (realtime).

> ⚠️ Nếu đăng ký báo lỗi phải xác nhận email: vào Supabase → **Authentication** → **Providers** → **Email** → tắt "Confirm email" (để test cho tiện).

## 4. Chức năng đã làm (đối chiếu báo cáo)

| Chức năng | Usecase / Biểu mẫu | File |
|---|---|---|
| Đăng ký tài khoản | UC01 | `auth/register_screen.dart` |
| Đăng nhập + phân quyền | UC02, UC22 | `auth/login_screen.dart`, `main.dart` |
| Quên mật khẩu | UC03 | `auth/forgot_password_screen.dart` |
| Đặt lịch thu gom (+ **upload ảnh rác**) | UC04, BM01 | `customer/dat_lich_screen.dart` |
| Theo dõi tiến độ **realtime** | UC08 | `customer/lich_cua_toi_screen.dart` |
| Sửa/Hủy lịch hẹn | UC10 | `customer/lich_cua_toi_screen.dart` |
| Tra cứu bảng giá loại rác | UC11 | `customer/customer_home_screen.dart` |
| Đánh giá dịch vụ | BM09 | `customer/lich_cua_toi_screen.dart` |
| Admin duyệt/từ chối/hoàn tất lịch | Yêu cầu 26, 27 | `admin/quan_ly_lich_screen.dart` |
| Quản lý loại rác (CRUD) | — | `admin/quan_ly_loai_rac_screen.dart` |
| Nhập/Xuất kho + cảnh báo sắp hết | UC12, UC13, BM02 | `admin/quan_ly_vat_tu_screen.dart` |
| Báo cáo doanh thu tháng | UC18, BM07 | `admin/bao_cao_screen.dart` |
| Thống kê loại rác thu gom | BM10 | `admin/bao_cao_screen.dart` |

## 5. Cách nâng cấp database SAU NÀY (không mất dữ liệu)

Ví dụ muốn thêm cột "số điện thoại phụ" cho khách:

```sql
-- Vào SQL Editor của Supabase, chạy 1 dòng:
ALTER TABLE nguoi_dung ADD COLUMN sdt_phu text;
```

Xong! Dữ liệu cũ giữ nguyên, cột mới có giá trị NULL cho các dòng cũ. Đây chính là ưu điểm "update liên tục không phải xóa database" mà bạn cần.

## 6. Lỗi thường gặp

| Lỗi | Cách sửa |
|---|---|
| `Invalid API key` | Kiểm tra lại URL + anon key trong `supabase_config.dart` |
| Đăng ký xong không đăng nhập được | Tắt "Confirm email" (xem Bước 5) |
| Upload ảnh báo lỗi 403 | Bucket chưa bật Public hoặc chưa thêm policy upload |
| `new row violates row-level security` | Chưa chạy đủ file `schema.sql` (thiếu policy) — chạy lại cả file |
| Ảnh không hiện | Bucket phải bật **Public bucket** |

## Cập nhật đợt 2 (chạy thêm trong SQL Editor theo thứ tự)
1. `supabase/update_01_bai_viet.sql` - bảng tin tức/bài viết
2. `supabase/update_02_hoa_don_nguoi_dung.sql` - khóa tài khoản, định mức vật tư, hóa đơn

Chức năng mới: admin quản lý người dùng (đổi vai trò, khóa/mở khóa), hóa đơn tự
lập khi hoàn tất lịch (kèm trừ kho vật tư theo định mức), khách xem hóa đơn.
