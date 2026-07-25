-- ============================================================================
-- update_08_lay_id_admin.sql - HÀM PHỤ TRỢ: lấy id của 1 admin
-- ----------------------------------------------------------------------------
-- VÌ SAO CẦN FILE NÀY: khi khách gửi tin nhắn (update_06_chat.sql), code
-- Flutter cần tạo 1 thông báo (update_07_thong_bao.sql) gửi cho ADMIN, tức
-- là cần biết id của 1 tài khoản admin. Nhưng RLS của bảng nguoi_dung
-- (schema.sql) chỉ cho phép mỗi người xem ĐÚNG hồ sơ của chính mình:
--   CREATE POLICY "xem ho so cua minh hoac admin xem het" ON nguoi_dung
--     FOR SELECT USING (id = auth.uid() OR la_admin());
-- -> khách hàng (không phải admin) KHÔNG đọc được hồ sơ admin để lấy id.
--
-- CÁCH GIẢI QUYẾT: hàm SECURITY DEFINER dưới đây chạy với quyền của người
-- TẠO hàm (bỏ qua RLS khi truy vấn bên trong hàm), nhưng CHỈ trả về đúng 1
-- giá trị (uuid của admin) - không làm lộ cả hồ sơ (họ tên, SĐT...) như
-- cách nới lỏng thẳng policy SELECT sẽ làm. Đây là kỹ thuật y hệt la_admin()
-- đã dùng trong schema.sql, chỉ khác là trả về uuid thay vì boolean.
--
-- Nếu có NHIỀU admin: hàm trả về admin được TẠO TÀI KHOẢN SỚM NHẤT (order by
-- ngay_tao asc limit 1) - tạm chấp nhận "admin đầu tiên" theo đúng yêu cầu.
-- Cách chạy: copy toàn bộ -> SQL Editor -> Run.
-- ============================================================================
create or replace function public.lay_id_admin()
returns uuid
language sql
security definer
set search_path = public
as $$
  select id from public.nguoi_dung
  where vai_tro = 'admin'
  order by ngay_tao asc
  limit 1;
$$;

-- Cho phép người dùng đã đăng nhập (authenticated) gọi hàm này qua .rpc()
-- trong Flutter - mặc định Supabase không tự cấp quyền, phải grant rõ ràng.
grant execute on function public.lay_id_admin() to authenticated;
