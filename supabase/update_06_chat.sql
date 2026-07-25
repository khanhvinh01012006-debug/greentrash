-- ============================================================================
-- update_06_chat.sql - BỔ SUNG CHAT khách hàng <-> admin (gắn theo từng lịch)
-- ----------------------------------------------------------------------------
-- Mô hình đơn giản cho đồ án: KHÔNG có "phòng chat" riêng biệt, mỗi lịch thu
-- gom có 1 luồng tin nhắn của chính nó (giống bình luận dưới 1 đơn hàng).
-- Khách chỉ chat được về lịch CỦA MÌNH; Admin chat được với TẤT CẢ (vì admin
-- là phía duy nhất quản trị, đúng mô hình 2 vai trò hiện có của app).
-- Cách chạy: copy toàn bộ -> SQL Editor -> Run. Dữ liệu cũ giữ nguyên 100%.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. BẢNG tin_nhan: mỗi dòng là 1 tin nhắn, thuộc về 1 lịch thu gom cụ thể
-- ----------------------------------------------------------------------------
create table if not exists public.tin_nhan (
  id bigint generated always as identity primary key,

  -- Tin nhắn này thuộc lịch nào - CASCADE: xóa lịch thì xóa luôn hội thoại
  -- (đồ án không cần giữ lại tin nhắn của lịch đã bị xóa)
  ma_lich bigint not null
          references public.lich_thu_gom(id) on delete cascade,

  -- Ai gửi (khách hoặc admin) - CASCADE: xóa tài khoản thì xóa tin đã gửi,
  -- nhất quán với cách nguoi_dung -> auth.users đang làm trong schema.sql
  nguoi_gui uuid not null
            references public.nguoi_dung(id) on delete cascade,

  noi_dung  text not null,                          -- Nội dung tin nhắn
  ngay_gui  timestamptz not null default now()       -- Thời điểm gửi (tự điền)
);

-- ----------------------------------------------------------------------------
-- 2. BẬT REALTIME: khách/admin đang mở khung chat sẽ thấy tin mới NGAY, không
--    cần bấm refresh - dùng đúng cơ chế đã áp dụng cho lich_thu_gom.
-- ----------------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table tin_nhan;
exception
  when duplicate_object then null;  -- đã thêm rồi thì bỏ qua, không báo lỗi
end $$;

-- ----------------------------------------------------------------------------
-- 3. PHÂN QUYỀN (RLS) - tái dùng hàm la_admin() đã có sẵn trong schema.sql
-- ----------------------------------------------------------------------------
alter table public.tin_nhan enable row level security;

-- ĐỌC: admin xem được mọi tin nhắn (để hỗ trợ mọi khách); khách chỉ xem
-- được tin nhắn của LỊCH DO MÌNH ĐẶT (lần theo ma_lich -> lich_thu_gom ->
-- đúng ma_khach_hang = mình) - không xem được chat của lịch người khác.
drop policy if exists "xem tin nhan cua lich minh hoac admin" on public.tin_nhan;
create policy "xem tin nhan cua lich minh hoac admin"
  on public.tin_nhan for select
  using (
    la_admin()
    or exists (
      select 1 from public.lich_thu_gom l
      where l.id = ma_lich and l.ma_khach_hang = auth.uid()
    )
  );

-- GHI: nguoi_gui bắt buộc phải là chính người đang đăng nhập (không ai giả
-- danh gửi hộ người khác được) VÀ (là admin, HOẶC là chủ của lịch đó) -
-- cùng điều kiện xác định "liên quan" như policy đọc ở trên.
drop policy if exists "gui tin nhan cho lich minh hoac admin" on public.tin_nhan;
create policy "gui tin nhan cho lich minh hoac admin"
  on public.tin_nhan for insert
  with check (
    nguoi_gui = auth.uid()
    and (
      la_admin()
      or exists (
        select 1 from public.lich_thu_gom l
        where l.id = ma_lich and l.ma_khach_hang = auth.uid()
      )
    )
  );
