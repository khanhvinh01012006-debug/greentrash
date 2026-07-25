-- ============================================================================
-- update_07_thong_bao.sql - BỔ SUNG HỆ THỐNG THÔNG BÁO
-- ----------------------------------------------------------------------------
-- Mô hình đơn giản cho đồ án: thông báo được SINH RA TỪ CODE FLUTTER (không
-- dùng trigger database) - ví dụ admin bấm "Duyệt lịch" thì ngay sau khi
-- update lich_thu_gom, code Flutter insert thêm 1 dòng vào bảng này cho
-- đúng khách hàng đó.
--
-- Mỗi thông báo LUÔN thuộc về 1 người nhận cụ thể (ma_nguoi_nhan) - nhờ vậy
-- chỉ cần 1 cột da_doc (bool) là đủ, không cần bảng phụ kiểu "ai đã đọc dòng
-- nào" như group chat (vì đây không phải thông báo dùng chung nhiều người).
--
-- 4 loại thông báo: 'duyet' (đơn được duyệt), 'huy' (đơn bị hủy),
-- 'thanh_toan' (đã nhận thanh toán), 'tin_nhan' (có tin nhắn mới - từ
-- update_06_chat.sql).
-- Cách chạy: copy toàn bộ -> SQL Editor -> Run. Dữ liệu cũ giữ nguyên 100%.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. BẢNG thong_bao
-- ----------------------------------------------------------------------------
create table if not exists public.thong_bao (
  id bigint generated always as identity primary key,

  -- Ai nhận thông báo này - CASCADE: xóa tài khoản thì xóa thông báo của họ
  ma_nguoi_nhan uuid not null
                references public.nguoi_dung(id) on delete cascade,

  -- Loại thông báo - CHECK giới hạn đúng 4 giá trị đang dùng trong app
  loai text not null
       check (loai in ('duyet', 'huy', 'thanh_toan', 'tin_nhan')),

  -- Câu hiển thị sẵn, vd: "Đơn thu gom ngày 25/07 đã được duyệt" - soạn sẵn
  -- từ Flutter lúc insert, không phải ghép chuỗi lúc hiển thị
  noi_dung text not null,

  -- Bấm vào thông báo -> nhảy tới đúng lịch này. NULL cho phép vì phòng
  -- trường hợp sau này có thông báo không gắn với lịch cụ thể nào.
  -- CASCADE: xóa lịch thì xóa luôn thông báo liên quan (giống tin_nhan).
  ma_lich bigint
          references public.lich_thu_gom(id) on delete cascade,

  da_doc   boolean     not null default false,  -- đã đọc chưa
  ngay_tao timestamptz not null default now()   -- thời điểm sinh thông báo
);

-- ----------------------------------------------------------------------------
-- 2. BẬT REALTIME: có thông báo mới thì chuông/badge cập nhật NGAY, không
--    cần bấm refresh - cùng cơ chế đã dùng cho lich_thu_gom và tin_nhan.
-- ----------------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table thong_bao;
exception
  when duplicate_object then null;  -- đã thêm rồi thì bỏ qua, không báo lỗi
end $$;

-- ----------------------------------------------------------------------------
-- 3. PHÂN QUYỀN (RLS) - tái dùng hàm la_admin() đã có sẵn trong schema.sql
-- ----------------------------------------------------------------------------
alter table public.thong_bao enable row level security;

-- ĐỌC: chỉ xem được thông báo CỦA CHÍNH MÌNH. Admin không phải ngoại lệ ở
-- đây - admin cũng chỉ cần thấy thông báo gửi cho admin, không cần (và
-- không nên) thấy được thông báo riêng của từng khách hàng.
drop policy if exists "chi xem thong bao cua minh" on public.thong_bao;
create policy "chi xem thong bao cua minh"
  on public.thong_bao for select
  using (ma_nguoi_nhan = auth.uid());

-- GHI (TẠO MỚI): đây là policy TẾ NHỊ NHẤT của bảng này, vì người TẠO ra
-- thông báo (auth.uid()) khác với người NHẬN nó (ma_nguoi_nhan) trong cả
-- 2 chiều thực tế của app:
--   - Admin duyệt/hủy/xác nhận tiền -> tạo thông báo GỬI CHO KHÁCH
--   - Khách gửi tin nhắn (update_06_chat.sql) -> tạo thông báo GỬI CHO ADMIN
-- Vì vậy KHÔNG THỂ chỉ dùng "ma_nguoi_nhan = auth.uid()" như policy SELECT
-- ở trên (sẽ chặn luôn cả 2 luồng hợp lệ trên). Điều kiện dưới đây cho phép
-- ĐÚNG 3 trường hợp, không hơn:
--   a) Tự tạo thông báo cho chính mình (vô hại, hiếm khi dùng tới)
--   b) Admin tạo thông báo gửi cho BẤT KỲ ai (đúng luồng duyệt/hủy/thanh toán)
--   c) Người gửi KHÔNG PHẢI admin nhưng người NHẬN là admin, VÀ loại thông
--      báo phải đúng là 'tin_nhan' - tức khách chỉ được phép tạo thông báo
--      loại "có tin nhắn mới" gửi tới admin, KHÔNG được mạo danh tạo thông
--      báo loại 'duyet'/'huy'/'thanh_toan' gửi cho bất kỳ ai (kể cả cho
--      admin), vì 3 loại đó chỉ có ý nghĩa khi admin là người tạo ra.
drop policy if exists "tao thong bao cho minh hoac nguoi lien quan" on public.thong_bao;
create policy "tao thong bao cho minh hoac nguoi lien quan"
  on public.thong_bao for insert
  with check (
    ma_nguoi_nhan = auth.uid()
    or la_admin()
    or (
      loai = 'tin_nhan'
      and exists (
        select 1 from public.nguoi_dung nd
        where nd.id = ma_nguoi_nhan and nd.vai_tro = 'admin'
      )
    )
  );

-- SỬA: người nhận đánh dấu ĐÃ ĐỌC thông báo của chính mình (da_doc = true).
-- USING kiểm tra dòng đang sửa phải là của mình; WITH CHECK kiểm tra THÊM
-- sau khi sửa xong dòng đó vẫn phải là của mình - nếu chỉ có USING mà thiếu
-- WITH CHECK, về lý thuyết có thể lách bằng cách vừa đánh dấu đã đọc vừa
-- đổi luôn ma_nguoi_nhan sang người khác trong CÙNG 1 câu UPDATE.
drop policy if exists "tu danh dau da doc thong bao cua minh" on public.thong_bao;
create policy "tu danh dau da doc thong bao cua minh"
  on public.thong_bao for update
  using (ma_nguoi_nhan = auth.uid())
  with check (ma_nguoi_nhan = auth.uid());
