-- ============================================================================
-- update_04_anh_dai_dien.sql
-- BỔ SUNG: Ảnh đại diện (avatar) cho người dùng
-- ----------------------------------------------------------------------------
-- Khách hàng bấm "Đổi ảnh đại diện" ở trang Tài khoản -> ảnh được upload lên
-- Supabase Storage (bucket có sẵn) -> link ảnh lưu vào cột mới này.
-- Cách chạy: copy toàn bộ -> SQL Editor -> Run. Dữ liệu cũ giữ nguyên 100%.
-- ============================================================================

alter table public.nguoi_dung
  add column if not exists anh_dai_dien_url text;
