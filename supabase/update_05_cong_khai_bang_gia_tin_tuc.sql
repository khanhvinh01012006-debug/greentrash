-- ============================================================================
-- update_05_cong_khai_bang_gia_tin_tuc.sql
-- BỔ SUNG: Cho KHÁCH VÃNG LAI (chưa đăng nhập) cũng xem được Bảng giá +
-- Tin tức ở Trang chủ
-- ----------------------------------------------------------------------------
-- Trước đây app bắt đăng nhập ngay từ đầu nên 2 policy cũ chỉ cho phép
-- "auth.uid() IS NOT NULL" / "to authenticated" là đủ. Từ khi Trang chủ cho
-- khách xem trước (chưa đăng nhập) rồi mới bắt đăng nhập lúc đặt lịch, 2
-- bảng dưới đây cần mở SELECT cho cả vai trò "anon" (khách chưa đăng nhập),
-- nếu không Supabase sẽ âm thầm trả về 0 dòng (không báo lỗi) -> trang trông
-- như "mất dữ liệu" dù dữ liệu vẫn còn nguyên trong database.
-- Cách chạy: copy toàn bộ -> SQL Editor -> Run. Dữ liệu cũ giữ nguyên 100%.
-- ============================================================================

-- 1. loai_rac (bảng giá thu gom) - công khai, ai xem cũng được
drop policy if exists "ai dang nhap cung xem duoc loai rac" on public.loai_rac;
drop policy if exists "ai cung xem duoc loai rac" on public.loai_rac;
create policy "ai cung xem duoc loai rac"
  on public.loai_rac for select
  to anon, authenticated
  using (true);

-- 2. bai_viet (tin tức) - công khai, ai xem cũng được
drop policy if exists "ai cung doc duoc bai viet" on public.bai_viet;
create policy "ai cung doc duoc bai viet"
  on public.bai_viet for select
  to anon, authenticated
  using (true);
