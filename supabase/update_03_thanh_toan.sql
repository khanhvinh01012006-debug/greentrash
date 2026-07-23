-- ============================================================================
-- update_03_thanh_toan.sql - BỔ SUNG THANH TOÁN (UC15 dạng demo, BM04)
-- ----------------------------------------------------------------------------
-- Mô hình thanh toán TƯỢNG TRƯNG cho đồ án (không tích hợp cổng thật):
--   - Khách chọn: 'tien_mat' (trả khi nhân viên đến) hoặc 'chuyen_khoan'
--   - Chuyển khoản: app hiện mã VietQR tĩnh -> khách quét bằng app ngân hàng
--     -> bấm "Tôi đã chuyển khoản" -> trạng thái 'khach_bao_da_chuyen'
--   - Admin thấy nhãn báo NGAY (nhờ realtime đã bật trên lich_thu_gom)
--     -> kiểm tra tài khoản -> bấm "Xác nhận đã nhận tiền" -> 'da_thanh_toan'
-- Cách chạy: copy toàn bộ -> SQL Editor -> Run. Dữ liệu cũ giữ nguyên,
-- các lịch cũ tự có trạng thái 'chua_thanh_toan' nhờ DEFAULT.
-- ============================================================================

-- Phương thức khách chọn (NULL = chưa chọn)
alter table public.lich_thu_gom
  add column if not exists phuong_thuc_tt text
  check (phuong_thuc_tt in ('tien_mat', 'chuyen_khoan'));

-- Trạng thái thanh toán, đi theo vòng đời:
-- chua_thanh_toan -> (khách bấm đã CK) khach_bao_da_chuyen -> (admin xác nhận) da_thanh_toan
-- riêng tiền mặt: chua_thanh_toan -> (admin thu tiền xong xác nhận) da_thanh_toan
alter table public.lich_thu_gom
  add column if not exists trang_thai_tt text not null default 'chua_thanh_toan'
  check (trang_thai_tt in ('chua_thanh_toan', 'khach_bao_da_chuyen', 'da_thanh_toan'));
